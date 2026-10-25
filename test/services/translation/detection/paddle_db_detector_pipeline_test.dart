import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/paddle_db_detector_pipeline.dart';
import 'package:hazuki/services/translation/detection/translation_detector_models.dart';
import 'package:hazuki/services/translation/detection/translation_text_detector.dart';

void main() {
  test('resizes the long side to 960, aligns to 128 and normalizes BGR', () {
    final rgba = Uint8List(300 * 150 * 4);
    for (var index = 0; index < 300 * 150; index++) {
      rgba[index * 4] = 255;
      rgba[index * 4 + 3] = 255;
    }
    final input = PaddleDbDetectorPipeline.preprocess(
      DetectionImage(rgba: rgba, width: 300, height: 150),
    );
    expect(input.width, 1024);
    expect(input.height, 512);
    expect(input.shape, [1, 3, 512, 1024]);
    final plane = input.width * input.height;
    expect(input.tensor[0], closeTo((0 - 0.485) / 0.229, 1e-5));
    expect(input.tensor[plane], closeTo((0 - 0.456) / 0.224, 1e-5));
    expect(input.tensor[2 * plane], closeTo((1 - 0.406) / 0.225, 1e-5));
  });

  test('extracts scored components and unclips them', () {
    const width = 20, height = 20;
    final probability = Float32List(width * height);
    void fill(int left, int top, int right, int bottom, double value) {
      for (var y = top; y <= bottom; y++) {
        for (var x = left; x <= right; x++) {
          probability[y * width + x] = value;
        }
      }
    }

    // 6×3 的高分区域，外加一个斜向相邻像素（8 连通应合并）。
    fill(4, 5, 9, 7, 0.9);
    probability[8 * width + 10] = 0.9;
    // 过小的区域。
    fill(15, 1, 16, 2, 0.9);
    // 超过二值化阈值但平均得分不足。
    fill(13, 12, 17, 16, 0.35);

    final boxes = PaddleDbDetectorPipeline.postprocess(
      probability,
      width,
      height,
      const DbPostProcessParams(),
    );
    expect(boxes, hasLength(1));
    // 合并后外接矩形为 x 4..10、y 5..8，宽 7 高 4，unclip 距离 7×4×1.5/22。
    const distance = 7 * 4 * 1.5 / 22;
    expect(boxes.single.left, closeTo((4 - distance) / width, 1e-6));
    expect(boxes.single.top, closeTo((5 - distance) / height, 1e-6));
    expect(boxes.single.right, closeTo((11 + distance) / width, 1e-6));
    expect(boxes.single.bottom, closeTo((9 + distance) / height, 1e-6));
  });

  test('pads to the fixed NPU size and crops the map back', () {
    const width = 4, height = 2, plane = width * height;
    final input = PaddleDbInput(
      tensor: Float32List.fromList(List.generate(3 * plane, (i) => i + 1.0)),
      width: width,
      height: height,
    );
    final padded = PaddleDbDetectorPipeline.padToFixedSize(input);
    const size = PaddleDbDetectorPipeline.fixedSize;
    expect(padded.shape, [1, 3, size, size]);
    // 原数据位于每个通道的左上角。
    for (var channel = 0; channel < 3; channel++) {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          expect(
            padded.tensor[channel * size * size + y * size + x],
            input.tensor[channel * plane + y * width + x],
          );
        }
      }
    }
    // 补边为归一化后的白色。
    expect(padded.tensor[width], closeTo((1 - 0.485) / 0.229, 1e-5));
    expect(
      padded.tensor[2 * size * size + size * size - 1],
      closeTo((1 - 0.406) / 0.225, 1e-5),
    );

    final map = Float32List(size * size);
    map[size + 3] = 0.5;
    map[size + width] = 0.9;
    final cropped = PaddleDbDetectorPipeline.cropProbability(
      map,
      size,
      width,
      height,
    );
    expect(cropped, hasLength(plane));
    expect(cropped[width + 3], 0.5);
    expect(cropped.where((value) => value == 0.9), isEmpty);
  });

  test('stops after the maximum number of candidates', () {
    const width = 40, height = 4;
    final probability = Float32List(width * height);
    for (var x = 0; x < width; x += 5) {
      for (var y = 0; y < 4; y++) {
        for (var dx = 0; dx < 4; dx++) {
          probability[y * width + x + dx] = 0.9;
        }
      }
    }
    final boxes = PaddleDbDetectorPipeline.postprocess(
      probability,
      width,
      height,
      const DbPostProcessParams(maxCandidates: 3),
    );
    expect(boxes, hasLength(3));
  });
}
