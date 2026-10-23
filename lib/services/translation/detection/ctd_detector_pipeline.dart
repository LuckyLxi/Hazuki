import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'translation_text_detector.dart';

/// Comic Text Detector 的前后处理，与上游 manga-image-translator 保持一致。
abstract final class CtdDetectorPipeline {
  static const inputName = 'images';
  static const outputName = 'blk';
  static const inputSize = 1024;
  static const confThreshold = 0.4;
  static const nmsThreshold = 0.35;
  static const maxDetections = 300;

  /// 等比缩放后贴到 1024×1024 画布左上角，右侧和底部以黑色填充。
  static CtdInput preprocess(DetectionImage image) {
    final ratio = math.min(inputSize / image.width, inputSize / image.height);
    final width = math.max(
      1,
      math.min(inputSize, (image.width * ratio).round()),
    );
    final height = math.max(
      1,
      math.min(inputSize, (image.height * ratio).round()),
    );
    final source = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.rgba.buffer,
      bytesOffset: image.rgba.offsetInBytes,
      numChannels: 4,
    );
    final resized = width == image.width && height == image.height
        ? source
        : img.copyResize(
            source,
            width: width,
            height: height,
            interpolation: img.Interpolation.linear,
          );
    final pixels = resized.getBytes(order: img.ChannelOrder.rgb);
    const plane = inputSize * inputSize;
    final tensor = Float32List(3 * plane);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 3;
        final target = y * inputSize + x;
        tensor[target] = pixels[offset] / 255;
        tensor[plane + target] = pixels[offset + 1] / 255;
        tensor[2 * plane + target] = pixels[offset + 2] / 255;
      }
    }
    return CtdInput(tensor: tensor, contentWidth: width, contentHeight: height);
  }

  /// 解码 YOLO 文字块输出 `[1, N, 5 + 类别数]` 并做 NMS，坐标归一化到原切片。
  static List<Rect> postprocess(
    Float32List blocks,
    List<int> shape,
    int contentWidth,
    int contentHeight,
  ) {
    final stride = shape.last;
    final count = blocks.length ~/ stride;
    final candidates = <(Rect, double)>[];
    for (var index = 0; index < count; index++) {
      final offset = index * stride;
      final objectness = blocks[offset + 4];
      if (objectness <= confThreshold) continue;
      var classScore = 0.0;
      for (var cls = 5; cls < stride; cls++) {
        classScore = math.max(classScore, blocks[offset + cls]);
      }
      final confidence = stride > 5 ? objectness * classScore : objectness;
      if (confidence <= confThreshold) continue;
      final cx = blocks[offset], cy = blocks[offset + 1];
      final w = blocks[offset + 2], h = blocks[offset + 3];
      candidates.add((
        Rect.fromLTRB(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2),
        confidence,
      ));
    }
    // 文字块不区分类别做 NMS，避免同一区域因类别不同重复出框。
    candidates.sort((a, b) => b.$2.compareTo(a.$2));
    final kept = <Rect>[];
    for (final (box, _) in candidates) {
      if (kept.length >= maxDetections) break;
      if (kept.every((other) => _iou(box, other) <= nmsThreshold)) {
        kept.add(box);
      }
    }
    final output = <Rect>[];
    for (final box in kept) {
      final rect = Rect.fromLTRB(
        (box.left / contentWidth).clamp(0.0, 1.0),
        (box.top / contentHeight).clamp(0.0, 1.0),
        (box.right / contentWidth).clamp(0.0, 1.0),
        (box.bottom / contentHeight).clamp(0.0, 1.0),
      );
      if (!rect.isEmpty) output.add(rect);
    }
    return output;
  }

  static double _iou(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.isEmpty) return 0;
    final overlap = intersection.width * intersection.height;
    return overlap / (a.width * a.height + b.width * b.height - overlap);
  }
}

class CtdInput {
  const CtdInput({
    required this.tensor,
    required this.contentWidth,
    required this.contentHeight,
  });

  final Float32List tensor;
  final int contentWidth;
  final int contentHeight;

  List<int> get shape => const [
    1,
    3,
    CtdDetectorPipeline.inputSize,
    CtdDetectorPipeline.inputSize,
  ];
}
