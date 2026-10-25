import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'translation_text_detector.dart';

/// ogkalu comic-text-and-bubble-detector（RT-DETR-v2）的前后处理，
/// 参数取自模型仓库的 `preprocessor_config.json`。
abstract final class RtDetrDetectorPipeline {
  static const inputName = 'images';
  static const sizesName = 'orig_target_sizes';
  static const labelsName = 'labels';
  static const boxesName = 'boxes';
  static const scoresName = 'scores';
  static const inputSize = 640;
  static const scoreThreshold = 0.5;

  /// 类别 0 为气泡本身，1 为气泡内文字，2 为气泡外文字；翻译只取文字类别。
  static const textLabels = {1, 2};

  /// 导出模型的动态输入维度名，NPU 固定形状时按名覆盖。
  static const dynamicDimensions = {'N': 1, 'H': inputSize, 'W': inputSize};

  /// 直接拉伸到 640×640，只做 /255 缩放，不做均值方差归一化，RGB 顺序。
  static Float32List preprocess(DetectionImage image) {
    final source = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.rgba.buffer,
      bytesOffset: image.rgba.offsetInBytes,
      numChannels: 4,
    );
    final resized = img.copyResize(
      source,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
    final pixels = resized.getBytes(order: img.ChannelOrder.rgb);
    const plane = inputSize * inputSize;
    final tensor = Float32List(3 * plane);
    for (var index = 0; index < plane; index++) {
      tensor[index] = pixels[index * 3] / 255;
      tensor[plane + index] = pixels[index * 3 + 1] / 255;
      tensor[2 * plane + index] = pixels[index * 3 + 2] / 255;
    }
    return tensor;
  }

  /// 模型输出已按 [width]×[height] 还原为像素坐标且无需 NMS，
  /// 这里只按得分与类别过滤并归一化到切片。
  static List<Rect> postprocess(
    Int64List labels,
    Float32List boxes,
    Float32List scores,
    int width,
    int height,
  ) {
    final output = <Rect>[];
    for (var index = 0; index < scores.length; index++) {
      if (scores[index] <= scoreThreshold) continue;
      if (!textLabels.contains(labels[index])) continue;
      final offset = index * 4;
      final rect = Rect.fromLTRB(
        (boxes[offset] / width).clamp(0.0, 1.0),
        (boxes[offset + 1] / height).clamp(0.0, 1.0),
        (boxes[offset + 2] / width).clamp(0.0, 1.0),
        (boxes[offset + 3] / height).clamp(0.0, 1.0),
      );
      if (!rect.isEmpty) output.add(rect);
    }
    return output;
  }
}
