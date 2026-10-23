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
    Future<void> Function(TranslationDetectorModelSpec spec, File model);

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
    this.specs = kTranslationDetectorModels,
  }) : _settings = settings,
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
  final List<TranslationDetectorModelSpec> specs;
  final _states = <String, DetectorModelState>{};
  final _tokens = <String, CancelToken>{};
  final _tasks = <String, Future<void>>{};
  Future<void>? _loadFuture;
  Directory? _root;

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
    for (final spec in specs) {
      if (_tasks.containsKey(spec.id)) continue;
      final installed = await _modelFile(root, spec).exists();
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
      final stopwatch = Stopwatch()..start();
      var lastTick = 0, lastBytes = 0;
      var speed = 0.0;
      await _dio.download(
        spec.url,
        downloaded.path,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed - lastTick < 250 && (total <= 0 || received < total)) {
            return;
          }
          speed =
              math.max(received - lastBytes, 0) *
              1000 /
              math.max(elapsed - lastTick, 1);
          lastTick = elapsed;
          lastBytes = received;
          final expected = total > 0 ? total : spec.downloadBytes;
          _states[spec.id] = DetectorModelState(
            status: DetectorModelStatus.downloading,
            progress: (received / expected).clamp(0.0, 1.0),
            indeterminate: expected <= 0,
            speedBytesPerSecond: speed,
          );
          notifyListeners();
        },
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
      final verify = verifyLoadable;
      if (verify != null) {
        try {
          await verify(spec, model);
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
      _states[spec.id] = switch (error) {
        _ when token.isCancelled => const DetectorModelState(),
        _ModelDownloadFailure(:final kind) => DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: kind,
        ),
        DioException() => const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.network,
        ),
        ArchiveException() => const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.invalidArchive,
        ),
        _ => const DetectorModelState(
          status: DetectorModelStatus.failed,
          failure: DetectorModelFailure.storage,
        ),
      };
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
