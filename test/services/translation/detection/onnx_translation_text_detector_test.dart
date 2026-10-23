import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/onnx_translation_text_detector.dart';
import 'package:hazuki/services/translation/detection/translation_detector_models.dart';
import 'package:hazuki/services/translation/detection/translation_text_detector.dart';
import 'package:hazuki/services/translation/translation_failure.dart';

Matcher _failure(TranslationFailureKind kind) => throwsA(
  isA<TranslationFailure>().having((error) => error.kind, 'kind', kind),
);

void main() {
  final image = DetectionImage(rgba: Uint8List(16), width: 2, height: 2);
  final spec = kTranslationDetectorModels.first;
  final missing = File('missing-detector-model.onnx');

  test('removes cancelled jobs from the queue before they start', () async {
    final detector = OnnxTranslationTextDetector();
    final first = detector.detect(image, spec, missing);
    final token = CancelToken();
    final second = detector.detect(image, spec, missing, cancelToken: token);
    token.cancel();
    await expectLater(second, _failure(TranslationFailureKind.cancelled));
    // 宿主测试环境没有可加载的模型，排在前面的任务以模型不可用结束。
    await expectLater(
      first,
      _failure(TranslationFailureKind.detectorUnavailable),
    );
    await detector.release();
  });

  test('rejects already cancelled requests without queueing', () async {
    final detector = OnnxTranslationTextDetector();
    final token = CancelToken()..cancel();
    await expectLater(
      detector.detect(image, spec, missing, cancelToken: token),
      _failure(TranslationFailureKind.cancelled),
    );
    await detector.release();
  });

  test('release cancels running and queued work', () async {
    final detector = OnnxTranslationTextDetector();
    final first = expectLater(
      detector.detect(image, spec, missing),
      _failure(TranslationFailureKind.cancelled),
    );
    final second = expectLater(
      detector.detect(image, spec, missing),
      _failure(TranslationFailureKind.cancelled),
    );
    await detector.release();
    await first;
    await second;
    // 释放后仍可重新启动工作 isolate。
    await expectLater(
      detector.detect(image, spec, missing),
      _failure(TranslationFailureKind.detectorUnavailable),
    );
    await detector.release();
  });
}
