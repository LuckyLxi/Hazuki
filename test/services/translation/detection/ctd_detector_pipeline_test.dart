import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/ctd_detector_pipeline.dart';
import 'package:hazuki/services/translation/detection/translation_text_detector.dart';

void main() {
  test('letterboxes into the top-left corner with black padding', () {
    final rgba = Uint8List(512 * 256 * 4)..fillRange(0, 512 * 256 * 4, 255);
    final input = CtdDetectorPipeline.preprocess(
      DetectionImage(rgba: rgba, width: 512, height: 256),
    );
    expect(input.shape, [1, 3, 1024, 1024]);
    expect(input.contentWidth, 1024);
    expect(input.contentHeight, 512);
    const plane = 1024 * 1024;
    expect(input.tensor[0], closeTo(1, 1e-6));
    expect(input.tensor[2 * plane + 511 * 1024 + 1023], closeTo(1, 1e-6));
    expect(input.tensor[600 * 1024 + 10], 0);
  });

  test('decodes YOLO blocks, applies NMS and normalizes to content', () {
    final blocks = Float32List.fromList([
      // 保留：置信度 0.9 × 0.9。
      100, 100, 50, 20, 0.9, 0.9, 0.1,
      // 与上一个框高度重叠且得分更低，被 NMS 抑制。
      105, 100, 50, 20, 0.8, 0.9, 0.1,
      // objectness 低于阈值。
      500, 300, 40, 40, 0.3, 0.9, 0.9,
      // 类别得分拉低后的置信度低于阈值。
      700, 200, 40, 40, 0.9, 0.3, 0.2,
      // 不重叠的第二个文字块。
      300, 400, 60, 100, 0.7, 0.2, 0.95,
    ]);
    final boxes = CtdDetectorPipeline.postprocess(blocks, [1, 5, 7], 1024, 512);
    expect(boxes, hasLength(2));
    expect(boxes[0].left, closeTo(75 / 1024, 1e-6));
    expect(boxes[0].top, closeTo(90 / 512, 1e-6));
    expect(boxes[0].right, closeTo(125 / 1024, 1e-6));
    expect(boxes[0].bottom, closeTo(110 / 512, 1e-6));
    expect(boxes[1].top, closeTo(350 / 512, 1e-6));
    expect(boxes[1].bottom, closeTo(450 / 512, 1e-6));
  });

  test('clamps boxes that extend past the content area', () {
    final boxes = CtdDetectorPipeline.postprocess(
      Float32List.fromList([1000, 10, 100, 40, 0.9, 1, 0]),
      [1, 1, 7],
      1024,
      512,
    );
    expect(boxes.single.right, 1);
    expect(boxes.single.top, 0);
  });
}
