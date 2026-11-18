// 真实检测模型的加载与推理冒烟测试，需要预先下载三个模型和运行库；
// 未提供参数时自动跳过。运行库按路径加载，因此直接在宿主机上运行即可。
//
// flutter test test/services/translation/detection/real_model_smoke_test.dart \
//   --dart-define=HAZUKI_DETECTOR_MODEL_DIR=<目录> \
//   --dart-define=HAZUKI_ORT_LIBRARY=<onnxruntime.dll 或 libonnxruntime.so>
//
// 目录内放置 comic_text_detector.onnx、pp_ocrv5_mobile_det.onnx、
// pp_ocrv5_server_det.onnx（Paddle 为 tar 包内的 inference.onnx）。
// 可选 HAZUKI_DETECTOR_SAMPLE 指定一张真实漫画页图片。
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/onnx_model_pruner.dart';
import 'package:hazuki/services/translation/detection/onnx_translation_text_detector.dart';
import 'package:hazuki/services/translation/detection/translation_detector_models.dart';
import 'package:hazuki/services/translation/imaging/translation_image_processor.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _modelDirectory = String.fromEnvironment('HAZUKI_DETECTOR_MODEL_DIR');
const _sample = String.fromEnvironment('HAZUKI_DETECTOR_SAMPLE');
const _runtime = String.fromEnvironment('HAZUKI_ORT_LIBRARY');

Uint8List _syntheticPage() {
  final page = img.Image(width: 800, height: 1200);
  img.fill(page, color: img.ColorRgb8(255, 255, 255));
  for (var line = 0; line < 6; line++) {
    img.fillCircle(
      page,
      x: 400,
      y: 150 + line * 180,
      radius: 85,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.drawString(
      page,
      'HELLO WORLD $line',
      font: img.arial48,
      x: 180,
      y: 125 + line * 180,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
  return page.getBytes(order: img.ChannelOrder.rgba);
}

String _megabytes(int bytes) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

void main() {
  for (final spec in kTranslationDetectorModels) {
    test(
      'loads ${spec.id} and detects text',
      () async {
        final runtime = File(_runtime);
        expect(await runtime.exists(), isTrue, reason: runtime.path);
        final source = File(p.join(_modelDirectory, '${spec.id}.onnx'));
        expect(await source.exists(), isTrue, reason: source.path);
        // 与安装流程一致：需要裁剪的模型先只保留所用输出。
        var model = source;
        final keep = spec.keepOutputs;
        if (keep != null) {
          final directory = await Directory.systemTemp.createTemp('hazuki_');
          addTearDown(() => directory.delete(recursive: true));
          model = File(p.join(directory.path, '${spec.id}.onnx'));
          await model.writeAsBytes(
            pruneOnnxGraphOutputs(await source.readAsBytes(), keep),
          );
        }
        final Uint8List rgba;
        final int width, height;
        if (_sample.isEmpty) {
          rgba = _syntheticPage();
          width = 800;
          height = 1200;
        } else {
          final decoded = img.decodeImage(await File(_sample).readAsBytes())!;
          rgba = decoded
              .convert(numChannels: 4)
              .getBytes(order: img.ChannelOrder.rgba);
          width = decoded.width;
          height = decoded.height;
        }
        final prepared = await Isolate.run(
          () => TranslationImageProcessor.prepareRgba(
            rgba,
            width,
            height,
            detectionMaxSide: spec.detectionMaxSide,
          ),
        );
        final detector = OnnxTranslationTextDetector();
        final rssBefore = ProcessInfo.currentRss;
        final stopwatch = Stopwatch()..start();
        await OnnxTranslationTextDetector.verifyModel(model, runtime);
        final verifyMs = stopwatch.elapsedMilliseconds;

        stopwatch.reset();
        final first = await detector.detect(
          prepared.slices.first.detection!,
          spec,
          model,
          runtime,
        );
        final firstMs = stopwatch.elapsedMilliseconds;
        final peakRss = ProcessInfo.maxRss;
        final residentRss = ProcessInfo.currentRss;

        stopwatch.reset();
        for (final slice in prepared.slices) {
          await detector.detect(slice.detection!, spec, model, runtime);
        }
        final perSliceMs =
            stopwatch.elapsedMilliseconds / prepared.slices.length;
        await detector.release();

        debugPrint(
          '[detector-smoke] ${spec.id}: boxes=${first.length} '
          'verify=${verifyMs}ms firstDetect(load+run)=${firstMs}ms '
          'perSlice=${perSliceMs.toStringAsFixed(0)}ms '
          'slices=${prepared.slices.length} '
          'rssBefore=${_megabytes(rssBefore)} resident=${_megabytes(residentRss)} '
          'peak=${_megabytes(peakRss)}',
        );
        for (final box in first.take(8)) {
          debugPrint('[detector-smoke]   $box');
        }
        // CTD 针对漫画气泡训练，合成的纯文字页可能不出框；提供真实样张时才要求非空。
        if (_sample.isNotEmpty || spec.kind != TranslationDetectorKind.ctd) {
          expect(first, isNotEmpty);
        }
        for (final box in first) {
          expect(box.left, inInclusiveRange(0, 1));
          expect(box.bottom, inInclusiveRange(0, 1));
          expect(box.isEmpty, isFalse);
        }
      },
      skip: _modelDirectory.isEmpty || _runtime.isEmpty,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
