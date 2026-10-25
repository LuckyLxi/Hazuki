import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'translation_detector_models.dart';
import 'translation_text_detector.dart';

/// PP-OCRv5 文字检测的前后处理，参数遵循 PaddleX 官方 `inference.yml`。
abstract final class PaddleDbDetectorPipeline {
  static const resizeLong = 960;
  static const _stride = 128;
  static const _minSize = 3;

  // 官方配置按 BGR 通道顺序归一化。
  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];

  /// 长边缩放到 960，宽高向上取整到 128 的倍数（DetResizeForTest.resize_long）。
  static PaddleDbInput preprocess(DetectionImage image) {
    final ratio = resizeLong / math.max(image.width, image.height);
    int align(int value) =>
        math.max(_stride, (value + _stride - 1) ~/ _stride * _stride);
    final width = align((image.width * ratio).toInt());
    final height = align((image.height * ratio).toInt());
    final source = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.rgba.buffer,
      bytesOffset: image.rgba.offsetInBytes,
      numChannels: 4,
    );
    final resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final pixels = resized.getBytes(order: img.ChannelOrder.bgr);
    final plane = width * height;
    final tensor = Float32List(3 * plane);
    for (var index = 0; index < plane; index++) {
      for (var channel = 0; channel < 3; channel++) {
        tensor[channel * plane + index] =
            (pixels[index * 3 + channel] / 255 - _mean[channel]) /
            _std[channel];
      }
    }
    return PaddleDbInput(tensor: tensor, width: width, height: height);
  }

  /// NPU 只能运行固定形状；长边缩放到 960 再按 128 取整后最大为 1024。
  static const fixedSize = 1024;

  /// PaddleX 导出模型的动态输入维度名（批次、高、宽），固定形状时按名覆盖。
  static const dynamicDimensions = {
    'DynamicDimension.0': 1,
    'DynamicDimension.1': fixedSize,
    'DynamicDimension.2': fixedSize,
  };

  /// 把输入补到 [fixedSize] 见方，右侧与底部填充归一化后的白色（漫画底色）。
  static PaddleDbInput padToFixedSize(PaddleDbInput input) {
    const size = fixedSize, plane = size * size;
    final tensor = Float32List(3 * plane);
    for (var channel = 0; channel < 3; channel++) {
      tensor.fillRange(
        channel * plane,
        (channel + 1) * plane,
        (1 - _mean[channel]) / _std[channel],
      );
      final source = channel * input.width * input.height;
      for (var y = 0; y < input.height; y++) {
        tensor.setRange(
          channel * plane + y * size,
          channel * plane + y * size + input.width,
          input.tensor,
          source + y * input.width,
        );
      }
    }
    return PaddleDbInput(tensor: tensor, width: size, height: size);
  }

  /// 从补边后的 [mapWidth] 宽概率图左上角裁出 [width]×[height] 的原尺寸区域。
  static Float32List cropProbability(
    Float32List probability,
    int mapWidth,
    int width,
    int height,
  ) {
    final output = Float32List(width * height);
    for (var y = 0; y < height; y++) {
      output.setRange(y * width, (y + 1) * width, probability, y * mapWidth);
    }
    return output;
  }

  /// DB 后处理：二值化、8 连通域、得分过滤与 unclip 外扩，结果为轴对齐矩形。
  static List<Rect> postprocess(
    Float32List probability,
    int width,
    int height,
    DbPostProcessParams params,
  ) {
    final labels = Int32List(width * height);
    final queue = Int32List(width * height);
    final output = <Rect>[];
    var components = 0;
    for (var start = 0; start < labels.length; start++) {
      if (labels[start] != 0 || probability[start] <= params.thresh) continue;
      if (components >= params.maxCandidates) break;
      components++;
      var head = 0, tail = 0;
      queue[tail++] = start;
      labels[start] = components;
      var minX = width, minY = height, maxX = -1, maxY = -1;
      while (head < tail) {
        final pixel = queue[head++];
        final x = pixel % width, y = pixel ~/ width;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if ((dx == 0 && dy == 0) || nx < 0 || nx >= width) continue;
            final next = ny * width + nx;
            if (labels[next] != 0 || probability[next] <= params.thresh) {
              continue;
            }
            labels[next] = components;
            queue[tail++] = next;
          }
        }
      }
      final boxWidth = maxX - minX + 1, boxHeight = maxY - minY + 1;
      if (math.min(boxWidth, boxHeight) < _minSize) continue;
      // 与官方 box_score_fast 相同，取框内概率均值作为得分。
      var sum = 0.0;
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          sum += probability[y * width + x];
        }
      }
      if (sum / (boxWidth * boxHeight) < params.boxThresh) continue;
      final distance =
          boxWidth *
          boxHeight *
          params.unclipRatio /
          (2 * (boxWidth + boxHeight));
      final expandedWidth = boxWidth + distance * 2;
      final expandedHeight = boxHeight + distance * 2;
      if (math.min(expandedWidth, expandedHeight) < _minSize + 2) continue;
      final rect = Rect.fromLTRB(
        ((minX - distance) / width).clamp(0.0, 1.0),
        ((minY - distance) / height).clamp(0.0, 1.0),
        ((maxX + 1 + distance) / width).clamp(0.0, 1.0),
        ((maxY + 1 + distance) / height).clamp(0.0, 1.0),
      );
      if (!rect.isEmpty) output.add(rect);
    }
    return output;
  }
}

class PaddleDbInput {
  const PaddleDbInput({
    required this.tensor,
    required this.width,
    required this.height,
  });

  final Float32List tensor;
  final int width;
  final int height;

  List<int> get shape => [1, 3, height, width];
}
