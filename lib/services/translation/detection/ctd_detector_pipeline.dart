import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'translation_text_detector.dart';

/// Comic Text Detector 的前后处理，与上游 manga-image-translator 保持一致。
abstract final class CtdDetectorPipeline {
  static const inputName = 'images';
  static const outputName = 'blk';
  static const segmentationName = 'seg';
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

  /// 分割图二值化阈值。
  static const _segmentationThreshold = 0.3;

  /// 膨胀半径（输入像素），把同一列、同一行内分开的字连成一块。
  static const _segmentationDilation = 4;

  /// 补框所需的最少文字像素，过滤网点、杂点等零星响应。
  static const _segmentationMinPixels = 150;

  /// 文字块外扩多少像素后视为已覆盖。
  static const _segmentationCoverMargin = 4;

  /// 用分割图补回文字块漏掉的文字区域，返回新增框（归一化到原切片）。
  ///
  /// 文字块头对贴着画面的长竖排单列、拟声词召回不稳，分割图则能完整覆盖。
  /// 分割连通块中被已有文字块覆盖的像素不足一半时，才作为新框补上。
  static List<Rect> recoverFromSegmentation(
    Float32List mask,
    List<int> shape,
    int contentWidth,
    int contentHeight,
    List<Rect> blocks,
  ) {
    final maskWidth = shape.last, maskHeight = shape[shape.length - 2];
    final width = math.min(contentWidth, maskWidth);
    final height = math.min(contentHeight, maskHeight);
    if (width <= 0 || height <= 0) return const [];
    final positive = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (mask[y * maskWidth + x] > _segmentationThreshold) {
          positive[y * width + x] = 1;
        }
      }
    }
    final covered = Uint8List(width * height);
    for (final block in blocks) {
      final left = math.max(
        0,
        (block.left * contentWidth).floor() - _segmentationCoverMargin,
      );
      final top = math.max(
        0,
        (block.top * contentHeight).floor() - _segmentationCoverMargin,
      );
      final right = math.min(
        width,
        (block.right * contentWidth).ceil() + _segmentationCoverMargin,
      );
      final bottom = math.min(
        height,
        (block.bottom * contentHeight).ceil() + _segmentationCoverMargin,
      );
      for (var y = top; y < bottom; y++) {
        covered.fillRange(
          y * width + left,
          y * width + math.max(left, right),
          1,
        );
      }
    }
    final dilated = _dilate(positive, width, height, _segmentationDilation);
    final visited = Uint8List(width * height);
    final queue = Int32List(width * height);
    final output = <Rect>[];
    for (var start = 0; start < dilated.length; start++) {
      if (dilated[start] == 0 || visited[start] != 0) continue;
      visited[start] = 1;
      queue[0] = start;
      var head = 0, tail = 1;
      var minX = width, minY = height, maxX = -1, maxY = -1;
      var pixels = 0, coveredPixels = 0;
      while (head < tail) {
        final pixel = queue[head++];
        final x = pixel % width, y = pixel ~/ width;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        if (positive[pixel] != 0) {
          pixels++;
          if (covered[pixel] != 0) coveredPixels++;
        }
        for (final next in [
          if (x > 0) pixel - 1,
          if (x + 1 < width) pixel + 1,
          if (y > 0) pixel - width,
          if (y + 1 < height) pixel + width,
        ]) {
          if (dilated[next] == 0 || visited[next] != 0) continue;
          visited[next] = 1;
          queue[tail++] = next;
        }
      }
      if (pixels < _segmentationMinPixels || coveredPixels * 2 >= pixels) {
        continue;
      }
      output.add(
        Rect.fromLTRB(
          minX / contentWidth,
          minY / contentHeight,
          (maxX + 1) / contentWidth,
          (maxY + 1) / contentHeight,
        ),
      );
    }
    return output;
  }

  /// 方形窗口的二值膨胀，按行、按列两遍滑动计数完成。
  static Uint8List _dilate(Uint8List mask, int width, int height, int radius) {
    final rows = Uint8List(mask.length);
    for (var y = 0; y < height; y++) {
      final row = y * width;
      var count = 0;
      for (var x = 0; x < math.min(radius, width); x++) {
        count += mask[row + x];
      }
      for (var x = 0; x < width; x++) {
        if (x + radius < width) count += mask[row + x + radius];
        if (x - radius - 1 >= 0) count -= mask[row + x - radius - 1];
        if (count > 0) rows[row + x] = 1;
      }
    }
    final output = Uint8List(mask.length);
    for (var x = 0; x < width; x++) {
      var count = 0;
      for (var y = 0; y < math.min(radius, height); y++) {
        count += rows[y * width + x];
      }
      for (var y = 0; y < height; y++) {
        if (y + radius < height) count += rows[(y + radius) * width + x];
        if (y - radius - 1 >= 0) count -= rows[(y - radius - 1) * width + x];
        if (count > 0) output[y * width + x] = 1;
      }
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
