import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/translation_models.dart';

class BubbleSnapper {
  const BubbleSnapper();

  List<TranslationRegion> snap(
    Uint8List rgba,
    int width,
    int height,
    List<TranslationRegion> regions,
  ) => regions
      .map((region) => _snapRegion(rgba, width, height, region))
      .toList();

  TranslationRegion _snapRegion(
    Uint8List rgba,
    int width,
    int height,
    TranslationRegion region,
  ) {
    final left = (region.box.left * width).floor().clamp(0, width - 1);
    final top = (region.box.top * height).floor().clamp(0, height - 1);
    final right = (region.box.right * width).ceil().clamp(left + 1, width);
    final bottom = (region.box.bottom * height).ceil().clamp(top + 1, height);
    final histogram = <int, int>{};
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        final key =
            (rgba[offset] >> 4) << 8 |
            (rgba[offset + 1] >> 4) << 4 |
            (rgba[offset + 2] >> 4);
        histogram[key] = (histogram[key] ?? 0) + 1;
      }
    }
    final dominant = histogram.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    var red = 0, green = 0, blue = 0, count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final offset = (y * width + x) * 4;
        final key =
            (rgba[offset] >> 4) << 8 |
            (rgba[offset + 1] >> 4) << 4 |
            (rgba[offset + 2] >> 4);
        if (key != dominant) continue;
        red += rgba[offset];
        green += rgba[offset + 1];
        blue += rgba[offset + 2];
        count++;
      }
    }
    red = (red / count).round();
    green = (green / count).round();
    blue = (blue / count).round();
    final color = Color.fromARGB(255, red, green, blue);
    var box = region.box;
    if (region.kind == TranslationRegionKind.bubble ||
        region.kind == TranslationRegionKind.narration) {
      bool matches(int pixel) {
        final offset = pixel * 4;
        final dr = rgba[offset] - red,
            dg = rgba[offset + 1] - green,
            db = rgba[offset + 2] - blue;
        return dr * dr + dg * dg + db * db <= 40 * 40;
      }

      int? seed;
      var distance = double.infinity;
      final cx = (left + right - 1) / 2, cy = (top + bottom - 1) / 2;
      for (
        var y = top + (bottom - top) ~/ 4;
        y < bottom - (bottom - top) ~/ 4;
        y++
      ) {
        for (
          var x = left + (right - left) ~/ 4;
          x < right - (right - left) ~/ 4;
          x++
        ) {
          final d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
          if (d < distance && matches(y * width + x)) {
            seed = y * width + x;
            distance = d;
          }
        }
      }
      if (seed != null) {
        final visited = Uint8List(width * height);
        final queue = <int>[seed];
        visited[seed] = 1;
        var minX = width, minY = height, maxX = 0, maxY = 0;
        for (var cursor = 0; cursor < queue.length; cursor++) {
          final pixel = queue[cursor], x = pixel % width, y = pixel ~/ width;
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
          for (final next in [
            if (x > 0) pixel - 1,
            if (x + 1 < width) pixel + 1,
            if (y > 0) pixel - width,
            if (y + 1 < height) pixel + width,
          ]) {
            if (visited[next] != 0) continue;
            visited[next] = 1;
            if (matches(next)) queue.add(next);
          }
        }
        final candidate = Rect.fromLTRB(
          minX / width,
          minY / height,
          (maxX + 1) / width,
          (maxY + 1) / height,
        );
        final area = candidate.width * candidate.height;
        final originalArea = box.width * box.height;
        final intersection = candidate.intersect(box);
        final intersectionArea = intersection.isEmpty
            ? 0
            : intersection.width * intersection.height;
        final iou = intersectionArea / (area + originalArea - intersectionArea);
        final coversImage =
            minX == 0 && minY == 0 && maxX == width - 1 && maxY == height - 1;
        if (area >= originalArea * 0.6 &&
            area <= originalArea * 3 &&
            iou >= 0.3 &&
            !coversImage) {
          box = Rect.fromLTRB(
            candidate.left + candidate.width * 0.04,
            candidate.top + candidate.height * 0.04,
            candidate.right - candidate.width * 0.04,
            candidate.bottom - candidate.height * 0.04,
          );
        }
      }
    }
    return TranslationRegion(
      id: region.id,
      box: box,
      kind: region.kind,
      sourceText: region.sourceText,
      translatedText: region.translatedText,
      sourceVertical: region.sourceVertical,
      backgroundColor: color,
      boxSource: region.boxSource,
    );
  }
}
