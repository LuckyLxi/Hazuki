import 'dart:async';
import 'dart:collection';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import '../translation_failure.dart';
import 'ctd_detector_pipeline.dart';
import 'onnx_runtime_library.dart';
import 'onnx_tensor_io.dart';
import 'paddle_db_detector_pipeline.dart';
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
  static Future<void> verifyModel(File model, File runtime) {
    final path = model.path, library = runtime.path;
    return Isolate.run(() async {
      setOnnxRuntimeLibraryPath(library);
      _initEnv();
      try {
        await _loadSession(path).release();
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

/// 按完整路径预加载运行库同目录的 DirectML.dll，返回能否启用 DirectML。
///
/// DirectML 版运行库延迟加载 DirectML.dll，系统只在应用目录和 System32 中查找，
/// 找不到时进程直接崩溃；预加载后延迟加载会复用已载入的同名模块。
/// 预加载失败时不得追加 DirectML，否则会触发上述崩溃。
bool _preloadDirectMl(String runtimePath) {
  if (!Platform.isWindows) return false;
  final library = File(
    '${File(runtimePath).parent.path}${Platform.pathSeparator}'
    '$directMlLibraryName',
  );
  if (!library.existsSync()) return false;
  try {
    DynamicLibrary.open(library.path);
    return true;
  } on ArgumentError {
    return false;
  }
}

OrtSession _loadSession(String path, {bool directMl = false}) {
  // 插件的 fromFile 按 UTF-8 传路径，Windows 需要 UTF-16；统一读字节加载。
  final bytes = File(path).readAsBytesSync();
  if (directMl) {
    try {
      return _createSession(bytes, directMl: true);
    } catch (_) {
      // 没有支持 DirectX 12 的显卡或驱动异常时退回 CPU。
    }
  }
  return _createSession(bytes, directMl: false);
}

OrtSession _createSession(Uint8List bytes, {required bool directMl}) {
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
    return OrtSession.fromBuffer(bytes, options);
  } finally {
    options.release();
  }
}

void _detectorWorkerMain((SendPort, String) arguments) {
  final (replies, runtimePath) = arguments;
  setOnnxRuntimeLibraryPath(runtimePath);
  var directMl = _preloadDirectMl(runtimePath);
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  OrtSession? session;
  String? sessionPath;
  var envReady = false;
  var chain = Future<void>.value();

  Future<void> releaseSession() async {
    final current = session;
    session = null;
    sessionPath = null;
    await current?.release();
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
    try {
      if (!envReady) {
        _initEnv();
        envReady = true;
      }
      if (sessionPath != path) {
        await releaseSession();
        session = _loadSession(path, directMl: directMl);
        sessionPath = path;
      }
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
      List<Rect> detect(OrtSession active) =>
          message['kind'] == TranslationDetectorKind.ctd.name
          ? _runCtd(active, image)
          : _runPaddleDb(
              active,
              image,
              DbPostProcessParams(
                thresh: message['thresh']! as double,
                boxThresh: message['boxThresh']! as double,
                unclipRatio: message['unclipRatio']! as double,
                maxCandidates: message['maxCandidates']! as int,
              ),
            );
      List<Rect> boxes;
      try {
        boxes = detect(session!);
      } catch (_) {
        if (!directMl) rethrow;
        // GPU 推理失败（如驱动重置）后，本工作 isolate 改用 CPU 并重试一次。
        directMl = false;
        await releaseSession();
        session = _loadSession(path);
        sessionPath = path;
        boxes = detect(session!);
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
  DbPostProcessParams params,
) {
  final input = PaddleDbDetectorPipeline.preprocess(image);
  final (data, shape) = _run(
    session,
    session.inputNames.first,
    [session.outputNames.first],
    input.tensor,
    input.shape,
  ).first;
  return PaddleDbDetectorPipeline.postprocess(
    data,
    shape.last,
    shape[shape.length - 2],
    params,
  );
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
