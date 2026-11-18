import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/rt_detr_detector_pipeline.dart';
import 'package:hazuki/services/translation/detection/translation_text_detector.dart';

void main() {
  test('stretches to 640 and only rescales RGB by 1/255', () {
    const width = 20, height = 10;
    final rgba = Uint8List(width * height * 4);
    for (var index = 0; index < width * height; index++) {
      rgba[index * 4] = 255;
      rgba[index * 4 + 1] = 51;
      rgba[index * 4 + 3] = 255;
    }
    final tensor = RtDetrDetectorPipeline.preprocess(
      DetectionImage(rgba: rgba, width: width, height: height),
    );
    const plane = 640 * 640;
    expect(tensor, hasLength(3 * plane));
    expect(tensor[0], closeTo(1, 1e-6));
    expect(tensor[plane], closeTo(0.2, 1e-6));
    expect(tensor[2 * plane + plane - 1], 0);
  });

  test('keeps confident text boxes and drops bubbles', () {
    final labels = Int64List.fromList([0, 1, 2, 1]);
    final boxes = Float32List.fromList([
      0, 0, 50, 50, // 气泡
      10, 20, 30, 40, // 气泡内文字
      -5, 90, 40, 120, // 气泡外文字，越界部分截断
      0, 0, 10, 10, // 得分不足
    ]);
    final scores = Float32List.fromList([0.9, 0.8, 0.7, 0.4]);
    final rects = RtDetrDetectorPipeline.postprocess(
      labels,
      boxes,
      scores,
      100,
      100,
    );
    expect(rects, hasLength(2));
    expect(rects[0].left, closeTo(0.1, 1e-6));
    expect(rects[0].top, closeTo(0.2, 1e-6));
    expect(rects[0].right, closeTo(0.3, 1e-6));
    expect(rects[0].bottom, closeTo(0.4, 1e-6));
    expect(rects[1].left, 0);
    expect(rects[1].bottom, 1);
  });
}
