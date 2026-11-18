import 'dart:async';
import 'dart:collection';
import 'dart:ffi' show DynamicLibrary, DynamicLibraryExtension, Int32, Pointer;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path/path.dart' as p;

import '../translation_failure.dart';
import 'ctd_detector_pipeline.dart';
import 'onnx_runtime_library.dart';
import 'onnx_tensor_io.dart';
import 'paddle_db_detector_pipeline.dart';
import 'rt_detr_detector_pipeline.dart';
import 'translation_detector_models.dart';
import 'translation_text_detector.dart';

/// 基于 ONNX Runtime 的文字检测器，推理在常驻工作 isolate 中串行执行。
class OnnxTranslationTextDetector implements TranslationTextDetector {
  final _queue = Queue<_DetectJob>();
  _DetectJob? _running;
  Future<_DetectorWorker>? _worker;
  String? _workerRuntime;
  var _pumping = false;
  var _nextId = 0;

  /// 在临时 isolate 中试加载模型，用于下载完成后、发布前的校验。
  ///
  /// 骁龙 NPU 版运行库会在此时完成 NPU 编译并按 [spec] 写入缓存，
  /// 首次检测时不必再等待编译。
  static Future<void> verifyModel(
    File model,
    File runtime, {
    TranslationDetectorModelSpec? spec,
  }) {
    final path = model.path, library = runtime.path;
    final cacheKey = spec == null ? null : _cacheKey(spec);
    return Isolate.run(() async {
      final accelerator = _useRuntime(library);
      _initEnv();
      try {
        final (session, _) = _loadSession(
          path,
          // DirectML 无需预热，校验只用 CPU。
          accelerator: accelerator == _Accelerator.qnn
              ? accelerator
              : _Accelerator.none,
          runtimePath: library,
          cacheKey: cacheKey,
        );
        await session.release();
      } finally {
        OrtEnv.instance.release();
      }
    });
  }

  /// 在临时 isolate 中加载下载的运行库并核对版本。
  static Future<void> verifyRuntime(File library, String version) {
    final path = library.path;
    return Isolate.run(() {
      setOnnxRuntimeLibraryPath(path);
      _initEnv();
      try {
        if (OrtEnv.version != version) {
          throw StateError('Unexpected ONNX Runtime ${OrtEnv.version}');
        }
      } finally {
        OrtEnv.instance.release();
      }
    });
  }

  @override
  Future<List<Rect>> detect(
    DetectionImage image,
    TranslationDetectorModelSpec spec,
    File model,
    File runtime, {
    CancelToken? cancelToken,
  }) {
    if (cancelToken?.isCancelled ?? false) {
      return Future.error(
        const TranslationFailure(TranslationFailureKind.cancelled),
      );
    }
    final job = _DetectJob(_nextId++, image, spec, model.path, runtime.path);
    _queue.add(job);
    cancelToken?.whenCancel.then((_) => _cancel(job));
    unawaited(_pump());
    return job.completer.future;
  }

  @override
  Future<void> release() async {
    for (final job in [..._queue, ?_running]) {
      _cancel(job);
    }
    _queue.clear();
    await _closeWorker();
  }

  Future<void> _closeWorker() async {
    final worker = _worker;
    _worker = null;
    _workerRuntime = null;
    if (worker == null) return;
    try {
      (await worker).close();
    } on TranslationFailure {
      // 启动失败的工作 isolate 无需关闭。
    }
  }

  // 排队中的任务在开始前移除；运行中的任务立即以取消结束，稍后到达的结果被丢弃。
  void _cancel(_DetectJob job) {
    _queue.remove(job);
    job.fail(const TranslationFailure(TranslationFailureKind.cancelled));
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        if (job.completer.isCompleted) continue;
        _running = job;
        try {
          // 运行库在 isolate 内只能加载一次，路径变化时换一个工作 isolate。
          if (_workerRuntime != job.runtimePath) await _closeWorker();
          _workerRuntime = job.runtimePath;
          final worker = await (_worker ??= _DetectorWorker.spawn(
            job.runtimePath,
            onExit: _workerExited,
          ));
          if (job.completer.isCompleted) continue;
          final boxes = await worker.request(job);
          if (!job.completer.isCompleted) job.completer.complete(boxes);
        } catch (error) {
          job.fail(
            error is TranslationFailure
                ? error
                : const TranslationFailure(
                    TranslationFailureKind.detectorUnavailable,
                  ),
          );
        } finally {
          _running = null;
        }
      }
    } finally {
      _pumping = false;
    }
  }

  void _workerExited(_DetectorWorker worker) {
    final current = _worker;
    if (current == null) return;
    unawaited(
      current.then((value) {
        if (identical(value, worker)) _worker = null;
      }, onError: (_) => _worker = null),
    );
  }
}

class _DetectJob {
  _DetectJob(this.id, this.image, this.spec, this.modelPath, this.runtimePath);

  final int id;
  final DetectionImage image;
  final TranslationDetectorModelSpec spec;
  final String modelPath;
  final String runtimePath;
  final completer = Completer<List<Rect>>();

  void fail(TranslationFailure failure) {
    if (!completer.isCompleted) completer.completeError(failure);
  }

  Map<String, Object?> toMessage() => {
    'id': id,
    'model': modelPath,
    'cacheKey': _cacheKey(spec),
    'kind': spec.kind.name,
    'thresh': spec.db.thresh,
    'boxThresh': spec.db.boxThresh,
    'unclipRatio': spec.db.unclipRatio,
    'maxCandidates': spec.db.maxCandidates,
    'rgba': TransferableTypedData.fromList([image.rgba]),
    'width': image.width,
    'height': image.height,
  };
}

class _DetectorWorker {
  final _ready = Completer<SendPort>();
  final _pending = <int, Completer<List<Rect>>>{};
  SendPort? _requests;
  bool _exited = false;

  static Future<_DetectorWorker> spawn(
    String runtimePath, {
    required void Function(_DetectorWorker worker) onExit,
  }) async {
    final responses = ReceivePort();
    final exits = ReceivePort();
    try {
      await Isolate.spawn(
        _detectorWorkerMain,
        (responses.sendPort, runtimePath),
        onExit: exits.sendPort,
        debugName: 'translation-detector',
      );
    } catch (_) {
      responses.close();
      exits.close();
      throw const TranslationFailure(
        TranslationFailureKind.detectorUnavailable,
      );
    }
    final worker = _DetectorWorker();
    responses.listen(worker._handle);
    exits.listen((_) {
      worker._exited = true;
      if (!worker._ready.isCompleted) {
        worker._ready.completeError(
          const TranslationFailure(TranslationFailureKind.detectorUnavailable),
        );
      }
      for (final completer in worker._pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            const TranslationFailure(TranslationFailureKind.detectorFailed),
          );
        }
      }
      worker._pending.clear();
      responses.close();
      exits.close();
      onExit(worker);
    });
    worker._requests = await worker._ready.future;
    return worker;
  }

  void _handle(Object? message) {
    if (message is SendPort) {
      _ready.complete(message);
      return;
    }
    final map = message! as Map<Object?, Object?>;
    final completer = _pending.remove(map['id']);
    if (completer == null || completer.isCompleted) return;
    final error = map['error'];
    if (error != null) {
      completer.completeError(
        TranslationFailure(
          error == 'unavailable'
              ? TranslationFailureKind.detectorUnavailable
              : TranslationFailureKind.detectorFailed,
        ),
      );
      return;
    }
    final values = map['boxes']! as Float64List;
    completer.complete([
      for (var index = 0; index + 3 < values.length; index += 4)
        Rect.fromLTRB(
          values[index],
          values[index + 1],
          values[index + 2],
          values[index + 3],
        ),
    ]);
  }

  Future<List<Rect>> request(_DetectJob job) {
    if (_exited) {
      return Future.error(
        const TranslationFailure(TranslationFailureKind.detectorFailed),
      );
    }
    final completer = Completer<List<Rect>>();
    _pending[job.id] = completer;
    _requests!.send(job.toMessage());
    return completer.future;
  }

  /// 通知工作 isolate 释放会话与运行环境后退出；正在执行的推理会先完成。
  void close() {
    if (_exited) return;
    _requests?.send(const {'close': true});
  }
}

/// 运行库所带的硬件加速方式，由运行库目录中的依赖库判断。
enum _Accelerator { none, directMl, qnn }

/// NPU 编译缓存的键，模型版本变化时自然失效。
String _cacheKey(TranslationDetectorModelSpec spec) =>
    '${spec.id}_v${spec.version}';

/// 设置本 isolate 的运行库并准备硬件加速；必须在首次调用 ORT 之前执行。
_Accelerator _useRuntime(String runtimePath) {
  setOnnxRuntimeLibraryPath(runtimePath);
  final directory = File(runtimePath).parent.path;
  if (Platform.isWindows && _preloadDirectMl(directory)) {
    return _Accelerator.directMl;
  }
  if (Platform.isAndroid && _prepareQnn(directory)) return _Accelerator.qnn;
  return _Accelerator.none;
}

/// 按完整路径预加载运行库同目录的 DirectML.dll，返回能否启用 DirectML。
///
/// DirectML 版运行库延迟加载 DirectML.dll，系统只在应用目录和 System32 中查找，
/// 找不到时进程直接崩溃；预加载后延迟加载会复用已载入的同名模块。
/// 预加载失败时不得追加 DirectML，否则会触发上述崩溃。
bool _preloadDirectMl(String directory) {
  final library = File(p.join(directory, directMlLibraryName));
  if (!library.existsSync()) return false;
  try {
    DynamicLibrary.open(library.path);
    return true;
  } on ArgumentError {
    return false;
  }
}

/// 准备骁龙 NPU 推理所需的 QNN 库，返回能否启用 QNN。
///
/// QNN 库按文件名互相加载，只会在应用安装目录中查找，而这些库下载在数据目录；
/// 按完整路径预加载后，同名加载会复用已载入的库。NPU 侧的 Skel 库由 FastRPC
/// 按 ADSP_LIBRARY_PATH 查找，需在 QNN 初始化前设置。
bool _prepareQnn(String directory) {
  final backend = File(p.join(directory, qnnHtpLibraryName));
  if (!backend.existsSync()) return false;
  final stub = Directory(directory)
      .listSync()
      .map((entry) => p.basename(entry.path))
      .where((name) => RegExp(r'^libQnnHtpV\d+Stub\.so$').hasMatch(name))
      .firstOrNull;
  if (stub == null) return false;
  try {
    final setenv = DynamicLibrary.process()
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, Pointer<Utf8>, int)
        >('setenv');
    final name = 'ADSP_LIBRARY_PATH'.toNativeUtf8();
    final value =
        '$directory;/vendor/lib/rfsa/adsp;/vendor/dsp/cdsp;'
                '/system/lib/rfsa/adsp;/dsp'
            .toNativeUtf8();
    try {
      if (setenv(name, value, 1) != 0) return false;
    } finally {
      calloc.free(name);
      calloc.free(value);
    }
    for (final library in [
      'libQnnSystem.so',
      'libQnnHtpPrepare.so',
      stub,
      qnnHtpLibraryName,
    ]) {
      DynamicLibrary.open(p.join(directory, library));
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// 加载检测会话；返回值的第二项表示会话是否使用了硬件加速。
///
/// 硬件加速创建失败（没有可用的 GPU / NPU、驱动异常、缓存损坏等）时退回 CPU。
(OrtSession, bool) _loadSession(
  String path, {
  _Accelerator accelerator = _Accelerator.none,
  String? runtimePath,
  String? cacheKey,
}) {
  if (accelerator == _Accelerator.qnn) {
    try {
      return (_loadQnnSession(path, runtimePath!, cacheKey), true);
    } catch (_) {
      // NPU 不可用时退回 CPU。
    }
  }
  // 插件的 fromFile 按 UTF-8 传路径，Windows 需要 UTF-16；统一读字节加载。
  final bytes = File(path).readAsBytesSync();
  if (accelerator == _Accelerator.directMl) {
    try {
      return (_createSession(bytes, directMl: true), true);
    } catch (_) {
      // 没有支持 DirectX 12 的显卡或驱动异常时退回 CPU。
    }
  }
  return (_createSession(bytes), false);
}

/// 加载 NPU 会话：优先读取编译缓存，没有缓存时在设备上编译并写入缓存。
///
/// 缓存放在运行库目录的 qnn_cache 下，运行库更换或删除时一并失效。
OrtSession _loadQnnSession(String path, String runtimePath, String? cacheKey) {
  final directory = File(runtimePath).parent.path;
  final backend = p.join(directory, qnnHtpLibraryName);
  final cache = cacheKey == null
      ? null
      : File(p.join(directory, 'qnn_cache', '$cacheKey.onnx'));
  if (cache != null && cache.existsSync()) {
    try {
      return _createSession(cache.readAsBytesSync(), qnnBackend: backend);
    } catch (_) {
      // 缓存损坏或与当前驱动不兼容时删除后重新编译。
      cache.deleteSync();
    }
  }
  final temporary = cache == null ? null : File('${cache.path}.tmp');
  if (temporary != null) {
    temporary.parent.createSync(recursive: true);
    if (temporary.existsSync()) temporary.deleteSync();
  }
  final session = _createSession(
    File(path).readAsBytesSync(),
    qnnBackend: backend,
    qnnContextOutput: temporary?.path,
  );
  // 编译结果完整写出后再改名，进程中途被杀不会留下半个缓存。
  if (temporary != null && temporary.existsSync()) {
    temporary.renameSync(cache!.path);
  }
  return session;
}

OrtSession _createSession(
  Uint8List bytes, {
  bool directMl = false,
  String? qnnBackend,
  String? qnnContextOutput,
}) {
  final options = OrtSessionOptions();
  try {
    // CTD 分割解码器的激活中有大量非规格化浮点数，x86 上会慢一个数量级以上；
    // 置零的误差远小于检测阈值，不影响结果。
    options.addConfigEntry('session.set_denormal_as_zero', '1');
    if (directMl) {
      // DirectML 不支持内存复用与并行执行，必须关闭；不支持的算子自动回落到 CPU。
      options.disableMemPattern();
      options.setSessionExecutionMode(OrtSessionExecutionMode.ortSequential);
      options.appendDirectMLProvider();
    }
    if (qnnBackend != null) {
      // NPU 只支持静态形状；CTD 本身是固定输入，覆盖不存在的维度名不受影响。
      for (final MapEntry(:key, :value) in {
        ...PaddleDbDetectorPipeline.dynamicDimensions,
        ...RtDetrDetectorPipeline.dynamicDimensions,
      }.entries) {
        options.addFreeDimensionOverrideByName(key, value);
      }
      if (qnnContextOutput != null) {
        // 编译结果嵌入单个文件，便于按字节读取缓存。
        options.addConfigEntry('ep.context_enable', '1');
        options.addConfigEntry('ep.context_embed_mode', '1');
        options.addConfigEntry('ep.context_file_path', qnnContextOutput);
      }
      options.appendQnnProvider({
        'backend_path': qnnBackend,
        'htp_performance_mode': 'high_performance',
        // 模型为 FP32，在 NPU 上以 FP16 精度运行，检测框与 CPU 结果一致。
        'enable_htp_fp16_precision': '1',
      });
    }
    return OrtSession.fromBuffer(bytes, options);
  } finally {
    options.release();
  }
}

void _detectorWorkerMain((SendPort, String) arguments) {
  final (replies, runtimePath) = arguments;
  var accelerator = _useRuntime(runtimePath);
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  OrtSession? session;
  String? sessionPath;
  var accelerated = false;
  var envReady = false;
  var chain = Future<void>.value();

  Future<void> releaseSession() async {
    final current = session;
    session = null;
    sessionPath = null;
    accelerated = false;
    await current?.release();
  }

  Future<void> loadSession(String path, String? cacheKey) async {
    await releaseSession();
    final (loaded, usesAccelerator) = _loadSession(
      path,
      accelerator: accelerator,
      runtimePath: runtimePath,
      cacheKey: cacheKey,
    );
    session = loaded;
    sessionPath = path;
    accelerated = usesAccelerator;
  }

  Future<void> handle(Map<Object?, Object?> message) async {
    if (message['close'] == true) {
      await releaseSession();
      if (envReady) OrtEnv.instance.release();
      requests.close();
      Isolate.exit();
    }
    final id = message['id'];
    final path = message['model']! as String;
    final cacheKey = message['cacheKey'] as String?;
    try {
      if (!envReady) {
        _initEnv();
        envReady = true;
      }
      if (sessionPath != path) await loadSession(path, cacheKey);
    } catch (_) {
      replies.send({'id': id, 'error': 'unavailable'});
      return;
    }
    try {
      final image = DetectionImage(
        rgba: (message['rgba']! as TransferableTypedData)
            .materialize()
            .asUint8List(),
        width: message['width']! as int,
        height: message['height']! as int,
      );
      List<Rect> detect() => switch (message['kind']) {
        'ctd' => _runCtd(session!, image),
        'rtDetr' => _runRtDetr(session!, image),
        _ => _runPaddleDb(
          session!,
          image,
          DbPostProcessParams(
            thresh: message['thresh']! as double,
            boxThresh: message['boxThresh']! as double,
            unclipRatio: message['unclipRatio']! as double,
            maxCandidates: message['maxCandidates']! as int,
          ),
          fixedShape: accelerated && accelerator == _Accelerator.qnn,
        ),
      };
      List<Rect> boxes;
      try {
        boxes = detect();
      } catch (_) {
        if (!accelerated) rethrow;
        // GPU / NPU 推理失败（如驱动重置）后，本工作 isolate 改用 CPU 并重试一次。
        accelerator = _Accelerator.none;
        await loadSession(path, cacheKey);
        boxes = detect();
      }
      replies.send({
        'id': id,
        'boxes': Float64List.fromList([
          for (final box in boxes) ...[
            box.left,
            box.top,
            box.right,
            box.bottom,
          ],
        ]),
      });
    } catch (_) {
      replies.send({'id': id, 'error': 'failed'});
    }
  }

  requests.listen((message) {
    chain = chain.then((_) => handle(message! as Map<Object?, Object?>));
  });
}

List<Rect> _runCtd(OrtSession session, DetectionImage image) {
  final input = CtdDetectorPipeline.preprocess(image);
  // 旧版只保留文字块输出的模型没有分割图，此时只用文字块。
  final hasSegmentation = session.outputNames.contains(
    CtdDetectorPipeline.segmentationName,
  );
  final outputs = _run(
    session,
    session.inputNames.contains(CtdDetectorPipeline.inputName)
        ? CtdDetectorPipeline.inputName
        : session.inputNames.first,
    [
      session.outputNames.contains(CtdDetectorPipeline.outputName)
          ? CtdDetectorPipeline.outputName
          : session.outputNames.first,
      if (hasSegmentation) CtdDetectorPipeline.segmentationName,
    ],
    input.tensor,
    input.shape,
  );
  final (data, shape) = outputs.first;
  final blocks = CtdDetectorPipeline.postprocess(
    data,
    shape,
    input.contentWidth,
    input.contentHeight,
  );
  if (!hasSegmentation) return blocks;
  final (mask, maskShape) = outputs.last;
  return [
    ...blocks,
    ...CtdDetectorPipeline.recoverFromSegmentation(
      mask,
      maskShape,
      input.contentWidth,
      input.contentHeight,
      blocks,
    ),
  ];
}

List<Rect> _runPaddleDb(
  OrtSession session,
  DetectionImage image,
  DbPostProcessParams params, {
  bool fixedShape = false,
}) {
  final input = PaddleDbDetectorPipeline.preprocess(image);
  // NPU 会话按固定形状编译：补边推理后裁回原尺寸，后处理与 CPU 一致。
  final padded = fixedShape
      ? PaddleDbDetectorPipeline.padToFixedSize(input)
      : input;
  final (data, shape) = _run(
    session,
    session.inputNames.first,
    [session.outputNames.first],
    padded.tensor,
    padded.shape,
  ).first;
  if (!fixedShape) {
    return PaddleDbDetectorPipeline.postprocess(
      data,
      shape.last,
      shape[shape.length - 2],
      params,
    );
  }
  return PaddleDbDetectorPipeline.postprocess(
    PaddleDbDetectorPipeline.cropProbability(
      data,
      shape.last,
      input.width,
      input.height,
    ),
    input.width,
    input.height,
    params,
  );
}

List<Rect> _runRtDetr(OrtSession session, DetectionImage image) {
  final input = createFloatTensor(RtDetrDetectorPipeline.preprocess(image), [
    1,
    3,
    RtDetrDetectorPipeline.inputSize,
    RtDetrDetectorPipeline.inputSize,
  ]);
  // 传入切片尺寸，输出框即为切片像素坐标。
  final sizes = createInt64Tensor(
    Int64List.fromList([image.width, image.height]),
    const [1, 2],
  );
  final runOptions = OrtRunOptions();
  try {
    final outputs = session.run(
      runOptions,
      {
        RtDetrDetectorPipeline.inputName: input,
        RtDetrDetectorPipeline.sizesName: sizes,
      },
      const [
        RtDetrDetectorPipeline.labelsName,
        RtDetrDetectorPipeline.boxesName,
        RtDetrDetectorPipeline.scoresName,
      ],
    );
    try {
      final (labels, _) = readInt64Tensor(outputs[0]!);
      final (boxes, _) = readFloatTensor(outputs[1]!);
      final (scores, _) = readFloatTensor(outputs[2]!);
      return RtDetrDetectorPipeline.postprocess(
        labels,
        boxes,
        scores,
        image.width,
        image.height,
      );
    } finally {
      for (final output in outputs) {
        output?.release();
      }
    }
  } finally {
    input.release();
    sizes.release();
    runOptions.release();
  }
}

List<(Float32List, List<int>)> _run(
  OrtSession session,
  String inputName,
  List<String> outputNames,
  Float32List tensor,
  List<int> shape,
) {
  final input = createFloatTensor(tensor, shape);
  final runOptions = OrtRunOptions();
  try {
    final outputs = session.run(runOptions, {inputName: input}, outputNames);
    try {
      return [for (final output in outputs) readFloatTensor(output!)];
    } finally {
      for (final output in outputs) {
        output?.release();
      }
    }
  } finally {
    input.release();
    runOptions.release();
  }
}

// 裁剪后的 CTD 加载时会对每个未用权重打印警告，只保留错误级日志。
void _initEnv() => OrtEnv.instance.init(level: OrtLoggingLevel.error);
