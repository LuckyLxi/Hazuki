import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../network/hazuki_network_factory.dart';
import '../manga_translation_settings_store.dart';
import 'onnx_model_pruner.dart';
import 'onnx_runtime_library.dart';
import 'remote_zip_entry.dart';
import 'translation_detector_models.dart';

enum DetectorModelStatus { notInstalled, downloading, failed, installed }

enum DetectorModelFailure {
  network,
  checksumMismatch,
  invalidArchive,
  loadFailed,
  storage,
}

class DetectorModelState {
  const DetectorModelState({
    this.status = DetectorModelStatus.notInstalled,
    this.progress = 0,
    this.indeterminate = true,
    this.speedBytesPerSecond = 0,
    this.failure,
  });

  final DetectorModelStatus status;
  final double progress;
  final bool indeterminate;
  final double speedBytesPerSecond;
  final DetectorModelFailure? failure;
}

/// 发布前校验模型能被推理运行时加载；抛出异常即视为加载失败。
typedef DetectorModelVerifier =
    Future<void> Function(
      TranslationDetectorModelSpec spec,
      File model,
      File runtime,
    );

/// 发布前校验运行库可以加载且版本正确；抛出异常即视为加载失败。
typedef OnnxRuntimeVerifier =
    Future<void> Function(OnnxRuntimeLibrarySpec spec, File library);

class _ModelDownloadFailure implements Exception {
  const _ModelDownloadFailure(this.kind);
  final DetectorModelFailure kind;
}

class TranslationDetectorModelStore extends ChangeNotifier {
  TranslationDetectorModelStore({
    required MangaTranslationSettingsStore settings,
    Future<Directory> Function()? supportDirectory,
    Dio? dio,
    this.verifyLoadable,
    this.verifyRuntime,
    this.releaseRuntime,
    this.specs = kTranslationDetectorModels,
    OnnxRuntimeLibrarySpec? Function() runtimeSpec =
        onnxRuntimeLibraryForCurrentPlatform,
  }) : _settings = settings,
       runtime = runtimeSpec(),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _dio =
           dio ??
           createHazukiDio(
             baseOptions: BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(minutes: 20),
               sendTimeout: const Duration(seconds: 15),
               followRedirects: true,
               maxRedirects: 5,
               validateStatus: (status) =>
                   status != null && status >= 200 && status < 300,
             ),
           );

  final MangaTranslationSettingsStore _settings;
  final Future<Directory> Function() _supportDirectory;
  final Dio _dio;
  final DetectorModelVerifier? verifyLoadable;
  final OnnxRuntimeVerifier? verifyRuntime;

  /// 删除运行库前释放检测器会话与工作 isolate。
  final Future<void> Function()? releaseRuntime;
  final List<TranslationDetectorModelSpec> specs;

  /// 当前平台的运行库；为 null 表示不支持本地检测。
  final OnnxRuntimeLibrarySpec? runtime;
  final _states = <String, DetectorModelState>{};
  final _tokens = <String, CancelToken>{};
  final _tasks = <String, Future<void>>{};
  Future<void>? _loadFuture;
  Directory? _root;
  DetectorModelState _runtimeState = const DetectorModelState();
  CancelToken? _runtimeToken;
  Future<void>? _runtimeTask;
  bool _runtimeDeletePending = false;

  DetectorModelState get runtimeState => _runtimeState;
  bool get isRuntimeInstalled =>
      _runtimeState.status == DetectorModelStatus.installed;

  /// Windows 上已加载的运行库无法删除，需要重启应用后才能完成删除。
  bool get runtimeDeletePending => _runtimeDeletePending;

  /// 已安装运行库的文件；未加载或未安装时返回 null。
  File? get runtimeFile {
    final root = _root;
    final spec = runtime;
    if (root == null || spec == null || !isRuntimeInstalled) return null;
    return _runtimeFile(root, spec);
  }

  DetectorModelState stateOf(String id) =>
      _states[id] ?? const DetectorModelState();

  bool isInstalled(String? id) =>
      id != null && stateOf(id).status == DetectorModelStatus.installed;

  /// 已安装模型的文件；未加载或未安装时返回 null。
  File? modelFile(String id) {
    final root = _root;
    final spec = _spec(id);
    if (root == null || spec == null || !isInstalled(id)) return null;
    return _modelFile(root, spec);
  }

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final root = Directory(
      p.join((await _supportDirectory()).path, 'manga_translation', 'models'),
    );
    // 应用重启前未完成的下载不再续传，统一清理。
    final partial = Directory(p.join(root.path, '.partial'));
    if (await partial.exists()) await partial.delete(recursive: true);
    final runtimeDirectory = _runtimeDirectory(root);
    final pending = File(p.join(runtimeDirectory.path, '.delete-pending'));
    if (await pending.exists()) {
      // 上次运行时运行库已被加载而无法删除，在本次加载前完成删除。
      await runtimeDirectory.delete(recursive: true);
    }
    final runtimeSpec = runtime;
    if (runtimeSpec != null && _runtimeTask == null) {
      await _deleteStaleRuntimes(runtimeDirectory, runtimeSpec);
      _runtimeState = DetectorModelState(
        status: await _runtimeInstalled(root, runtimeSpec)
            ? DetectorModelStatus.installed
            : DetectorModelStatus.notInstalled,
      );
    }
    for (final spec in specs) {
      if (_tasks.containsKey(spec.id)) continue;
      final current = _modelFile(root, spec);
      // 模型版本升级后旧文件不再使用，加载时一并删除以免长期占用空间。
      final directory = current.parent;
      if (await directory.exists()) {
        await for (final entry in directory.list()) {
          if (entry is File && entry.path != current.path) {
            try {
              await entry.delete();
            } on FileSystemException {
              // 删除失败不影响当前版本的状态判断，下次加载时再试。
            }
          }
        }
      }
      final installed = await current.exists();
      _states[spec.id] = DetectorModelState(
        status: installed
            ? DetectorModelStatus.installed
            : DetectorModelStatus.notInstalled,
      );
    }
    _root = root;
    notifyListeners();
  }

  Future<void> download(String id) {
    final running = _tasks[id];
    if (running != null) return running;
    final spec = _spec(id);
    if (spec == null) throw ArgumentError.value(id, 'id');
    final task = _download(spec);
    _tasks[id] = task;
    return task.whenComplete(() => _tasks.remove(id));
  }

  void cancel(String id) => _tokens[id]?.cancel();

  Future<void> downloadRuntime() {
    final spec = runtime;
    if (spec == null) throw UnsupportedError('No ONNX Runtime for platform');
    if (_runtimeDeletePending) {
      throw StateError('ONNX Runtime deletion is pending a restart');
    }
    final running = _runtimeTask;
    if (running != null) return running;
    final task = _downloadRuntime(spec);
    _runtimeTask = task;
    return task.whenComplete(() => _runtimeTask = null);
  }

  void cancelRuntime() => _runtimeToken?.cancel();

  Future<void> deleteRuntime() async {
    await load();
    final spec = runtime;
    if (spec == null) return;
    cancelRuntime();
    await _runtimeTask?.catchError((_) {});
    await releaseRuntime?.call();
    final directory = _runtimeDirectory(_root!);
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Windows 上已加载的 dll 被进程占用，记下标记，下次启动加载前删除。
      await File(
        p.join(directory.path, '.delete-pending'),
      ).writeAsString('', flush: true);
      _runtimeDeletePending = true;
    }
    _runtimeState = const DetectorModelState();
    notifyListeners();
  }

  Future<void> _downloadRuntime(OnnxRuntimeLibrarySpec spec) async {
    await load();
    final root = _root!;
    final token = CancelToken();
    _runtimeToken = token;
    _runtimeState = const DetectorModelState(
      status: DetectorModelStatus.downloading,
    );
    notifyListeners();
    final partial = Directory(p.join(_runtimeDirectory(root).path, '.partial'));
    final scratch = File(p.join(partial.path, 'archive.download'));
    // 依赖库先于主库下载与发布；主库存在即视为安装完成。
    final files = [...spec.companions, spec];
    try {
      await partial.create(recursive: true);
      final report = _progressReporter(
        spec.downloadBytes,
        (state) => _runtimeState = state,
      );
      var offset = 0;
      for (final file in files) {
        final extracted = File(p.join(partial.path, file.fileName));
        final base = offset;
        Object? lastError;
        for (final source in file.sources) {
          try {
            await downloadZipEntry(
              dio: _dio,
              url: source,
              archiveBytes: file.archiveBytes,
              entry: file.archiveEntry,
              output: extracted,
              scratch: scratch,
              cancelToken: token,
              onProgress: (received, _) =>
                  report(base + received, spec.downloadBytes),
            );
            lastError = null;
            break;
          } on DioException catch (error) {
            // 只有网络错误才换下一个下载源。
            if (token.isCancelled) rethrow;
            lastError = error;
          }
        }
        if (lastError != null) throw lastError;
        offset += file.entryCompressedBytes;
        _checkCancelled(token);
        if (await _digestInIsolate(extracted.path) != file.sha256) {
          throw const _ModelDownloadFailure(
            DetectorModelFailure.checksumMismatch,
          );
        }
        _checkCancelled(token);
      }
      final verify = verifyRuntime;
      if (verify != null) {
        try {
          // 依赖库与主库同在临时目录，校验时的加载方式与正式使用一致。
          await verify(spec, File(p.join(partial.path, spec.fileName)));
        } catch (_) {
          throw const _ModelDownloadFailure(DetectorModelFailure.loadFailed);
        }
      }
      _checkCancelled(token);
      for (final file in files) {
        final target = _runtimeFile(root, spec, file);
        await target.parent.create(recursive: true);
        if (await target.exists()) await target.delete();
        await File(p.join(partial.path, file.fileName)).rename(target.path);
      }
      _runtimeState = const DetectorModelState(
        status: DetectorModelStatus.installed,
      );
    } catch (error) {
      _runtimeState = _failureState(error, token);
    } finally {
      if (identical(_runtimeToken, token)) _runtimeToken = null;
      try {
        if (await partial.exists()) await partial.delete(recursive: true);
      } on FileSystemException {
        // 清理失败不影响结果；下次下载会覆盖临时文件。
      }
      notifyListeners();
    }
  }

  /// 节流后的下载进度回调，按 [expectedBytes] 兜底未知总长度。
  void Function(int received, int total) _progressReporter(
    int expectedBytes,
    void Function(DetectorModelState state) update,
  ) {
    final stopwatch = Stopwatch()..start();
    var lastTick = 0, lastBytes = 0;
    return (received, total) {
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed - lastTick < 250 && (total <= 0 || received < total)) {
        return;
      }
      final speed =
          math.max(received - lastBytes, 0) *
          1000 /
          math.max(elapsed - lastTick, 1);
      lastTick = elapsed;
      lastBytes = received;
      final expected = total > 0 ? total : expectedBytes;
      update(
        DetectorModelState(
          status: DetectorModelStatus.downloading,
          progress: (received / expected).clamp(0.0, 1.0),
          indeterminate: expected <= 0,
          speedBytesPerSecond: speed,
        ),
      );
      notifyListeners();
    };
  }

  static DetectorModelState _failureState(Object error, CancelToken token) =>
      switch (error) {
        _ when token.isCancelled => const DetectorModelState(),
        _ModelDownloadFailure(:final kind) => DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: kind,
        ),
        DioException() => const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.network,
        ),
        ArchiveException() || FormatException() => const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.invalidArchive,
        ),
        _ => const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.storage,
        ),
      };

  Future<void> delete(String id) async {
    await load();
    final spec = _spec(id);
    if (spec == null) return;
    cancel(id);
    await _tasks[id]?.catchError((_) {});
    final directory = Directory(p.join(_root!.path, spec.id));
    if (await directory.exists()) await directory.delete(recursive: true);
    _states[id] = const DetectorModelState();
    notifyListeners();
    // 删除当前选用的模型时同步清空选择，阅读器据此统一取消与重置。
    if (_settings.detectorModelId == id) {
      await _settings.setDetectorModelId(null);
    }
  }

  Future<void> _download(TranslationDetectorModelSpec spec) async {
    await load();
    final root = _root!;
    final token = CancelToken();
    _tokens[spec.id] = token;
    _states[spec.id] = const DetectorModelState(
      status: DetectorModelStatus.downloading,
    );
    notifyListeners();
    final partial = Directory(p.join(root.path, '.partial'));
    final downloaded = File(p.join(partial.path, '${spec.id}.download'));
    final extracted = File(p.join(partial.path, '${spec.id}.onnx'));
    final pruned = File(p.join(partial.path, '${spec.id}.pruned.onnx'));
    try {
      await partial.create(recursive: true);
      await _dio.download(
        spec.url,
        downloaded.path,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: _progressReporter(
          spec.downloadBytes,
          (state) => _states[spec.id] = state,
        ),
      );
      _checkCancelled(token);
      final path = downloaded.path;
      final digest = await _digestInIsolate(path);
      // bcebos 地址不带版本号，官方原地替换文件时只能靠摘要识别。
      if (digest != spec.sha256) {
        throw const _ModelDownloadFailure(
          DetectorModelFailure.checksumMismatch,
        );
      }
      _checkCancelled(token);
      var model = downloaded;
      final entry = spec.archiveEntry;
      if (entry != null) {
        final found = await _extractInIsolate(path, entry, extracted.path);
        if (!found) {
          throw const _ModelDownloadFailure(
            DetectorModelFailure.invalidArchive,
          );
        }
        model = extracted;
      }
      _checkCancelled(token);
      final keep = spec.keepOutputs;
      if (keep != null) {
        try {
          await _pruneInIsolate(model.path, pruned.path, keep);
        } on FormatException {
          throw const _ModelDownloadFailure(
            DetectorModelFailure.invalidArchive,
          );
        }
        model = pruned;
      }
      _checkCancelled(token);
      // 运行库尚未安装时跳过加载校验，首次检测时再暴露加载失败。
      final verify = verifyLoadable;
      final runtimeLibrary = runtimeFile;
      if (verify != null && runtimeLibrary != null) {
        try {
          await verify(spec, model, runtimeLibrary);
        } catch (_) {
          throw const _ModelDownloadFailure(DetectorModelFailure.loadFailed);
        }
      }
      _checkCancelled(token);
      final target = _modelFile(root, spec);
      await target.parent.create(recursive: true);
      if (await target.exists()) await target.delete();
      await model.rename(target.path);
      _states[spec.id] = const DetectorModelState(
        status: DetectorModelStatus.installed,
      );
    } catch (error) {
      _states[spec.id] = _failureState(error, token);
    } finally {
      if (identical(_tokens[spec.id], token)) _tokens.remove(spec.id);
      for (final file in [downloaded, extracted, pruned]) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // 清理失败不影响结果；下次启动时 load 会整体删除临时目录。
        }
      }
      notifyListeners();
    }
  }

  TranslationDetectorModelSpec? _spec(String id) {
    for (final spec in specs) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  static File _modelFile(Directory root, TranslationDetectorModelSpec spec) =>
      File(p.join(root.path, spec.id, 'v${spec.version}.onnx'));

  // 运行库与模型分目录存放：manga_translation/runtime/<版本>/<文件名>。
  static Directory _runtimeDirectory(Directory modelsRoot) =>
      Directory(p.join(p.dirname(modelsRoot.path), 'runtime'));

  static File _runtimeFile(
    Directory modelsRoot,
    OnnxRuntimeLibrarySpec spec, [
    OnnxRuntimeLibraryFile? file,
  ]) => File(
    p.join(
      _runtimeDirectory(modelsRoot).path,
      spec.directoryName,
      (file ?? spec).fileName,
    ),
  );

  static Future<bool> _runtimeInstalled(
    Directory modelsRoot,
    OnnxRuntimeLibrarySpec spec,
  ) async {
    for (final file in [spec, ...spec.companions]) {
      if (!await _runtimeFile(modelsRoot, spec, file).exists()) return false;
    }
    return true;
  }

  /// 运行库换版本或构建（如改用 DirectML 版、骁龙 NPU 版）后删除旧目录。
  static Future<void> _deleteStaleRuntimes(
    Directory runtimeDirectory,
    OnnxRuntimeLibrarySpec spec,
  ) async {
    if (!await runtimeDirectory.exists()) return;
    await for (final entry in runtimeDirectory.list()) {
      final name = p.basename(entry.path);
      if (entry is! Directory ||
          name == spec.directoryName ||
          name == '.partial') {
        continue;
      }
      try {
        await entry.delete(recursive: true);
      } on FileSystemException {
        // 删除失败不影响当前版本，下次加载时再试。
      }
    }
  }

  static void _checkCancelled(CancelToken token) {
    if (token.isCancelled) throw StateError('cancelled');
  }

  // 闭包在静态方法中创建，避免捕获实例上下文导致无法发送到工作 isolate。
  static Future<String> _digestInIsolate(String path) => Isolate.run(
    () async => (await sha256.bind(File(path).openRead()).first).toString(),
  );

  static Future<bool> _extractInIsolate(
    String archive,
    String entry,
    String output,
  ) => Isolate.run(() => _extractTarEntry(archive, entry, output));

  static Future<void> _pruneInIsolate(
    String source,
    String output,
    Set<String> keep,
  ) => Isolate.run(
    () => File(output).writeAsBytesSync(
      pruneOnnxGraphOutputs(File(source).readAsBytesSync(), keep),
      flush: true,
    ),
  );

  /// 从 tar 包中只提取指定文件名的条目，忽略包内 `.cache` 等杂项。
  static bool _extractTarEntry(String archive, String entry, String output) {
    final input = InputFileStream(archive);
    try {
      final decoded = TarDecoder().decodeStream(input, verify: true);
      for (final file in decoded.files) {
        if (!file.isFile || p.posix.basename(file.name) != entry) continue;
        if (p.posix.split(file.name).contains('.cache')) continue;
        final stream = OutputFileStream(output);
        try {
          file.writeContent(stream);
        } finally {
          stream.closeSync();
        }
        return true;
      }
      return false;
    } finally {
      input.closeSync();
    }
  }
}
