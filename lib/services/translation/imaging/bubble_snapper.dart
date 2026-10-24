import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/translation_models.dart';

// 有色底允许明暗渐变，但白色描边不能把背景连到气泡外面。
bool _matchesBackground(int r, int g, int b, int red, int green, int blue) {
  final chroma =
      math.max(red, math.max(green, blue)) -
      math.min(red, math.min(green, blue));
  final dr = r - red, dg = g - green, db = b - blue;
  if (chroma > 30) {
    final pixelChroma =
        math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
    return pixelChroma >= math.max(20, chroma * 0.35) &&
        dr * dr + dg * dg + db * db <= 85 * 85;
  }
  final pixelChroma = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
  return pixelChroma <= math.max(18, chroma + 12) &&
      dr * dr + dg * dg + db * db <= 40 * 40;
}

class BubbleSnapper {
  const BubbleSnapper();

  /// 保留原文框，另找气泡内部的排版范围和需要擦除的笔画。
  List<TranslationRegion> snap(
    Uint8List rgba,
    int width,
    int height,
    List<TranslationRegion> regions, {
    List<Rect> textBoxes = const [],
  }) {
    final texts = [for (final region in regions) region.box, ...textBoxes];
    return [
      for (final region in regions)
        _snapRegion(rgba, width, height, region, texts),
    ];
  }

  TranslationRegion _snapRegion(
    Uint8List rgba,
    int width,
    int height,
    TranslationRegion region,
    List<Rect> texts,
  ) {
    final source = Rect.fromLTRB(
      (region.box.left * width).floorToDouble().clamp(0, width - 1),
      (region.box.top * height).floorToDouble().clamp(0, height - 1),
      (region.box.right * width).ceilToDouble().clamp(1.0, width.toDouble()),
      (region.box.bottom * height).ceilToDouble().clamp(1.0, height.toDouble()),
    );
    final sampleMargin = math.max(
      2.0,
      math.min(24.0, source.shortestSide * 0.3),
    );
    final sample = source
        .inflate(sampleMargin)
        .intersect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final histogram = <int, (int, int, int, int)>{};
    for (var y = sample.top.toInt(); y < sample.bottom; y++) {
      for (var x = sample.left.toInt(); x < sample.right; x++) {
        final offset = (y * width + x) * 4;
        final r = rgba[offset], g = rgba[offset + 1], b = rgba[offset + 2];
        final key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
        // 文字周围的底色比框内笔画更可靠，同时保留黑底白字的候选色。
        final weight = source.contains(Offset(x.toDouble(), y.toDouble()))
            ? 1
            : 2;
        final previous = histogram[key] ?? (0, 0, 0, 0);
        histogram[key] = (
          previous.$1 + weight,
          previous.$2 + r * weight,
          previous.$3 + g * weight,
          previous.$4 + b * weight,
        );
      }
    }
    final colors = histogram.values.toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    Color colorOf((int, int, int, int) entry) => Color.fromARGB(
      255,
      (entry.$2 / entry.$1).round(),
      (entry.$3 / entry.$1).round(),
      (entry.$4 / entry.$1).round(),
    );
    var background = colorOf(colors.first);
    _BubbleInterior? interior;
    if (region.kind == TranslationRegionKind.bubble ||
        region.kind == TranslationRegionKind.narration) {
      final horizontalBar =
          region.kind == TranslationRegionKind.narration &&
          source.width > source.height * 4;
      final margin = math.max(
        12.0,
        source.longestSide * (horizontalBar ? 3 : 1.5),
      );
      final crop = Rect.fromLTRB(
        math.max(0, (source.left - margin).floorToDouble()),
        math.max(
          0,
          (source.top - (horizontalBar ? source.height * 0.3 : margin))
              .floorToDouble(),
        ),
        math.min(width.toDouble(), (source.right + margin).ceilToDouble()),
        math.min(
          height.toDouble(),
          (source.bottom + (horizontalBar ? source.height * 0.3 : margin))
              .ceilToDouble(),
        ),
      );
      final tried = <Color>[];
      for (final entry in colors) {
        final color = colorOf(entry);
        if (tried.any((other) {
          final dr = (other.r - color.r) * 255;
          final dg = (other.g - color.g) * 255;
          final db = (other.b - color.b) * 255;
          return dr * dr + dg * dg + db * db < 18 * 18;
        })) {
          continue;
        }
        if (tried.length == 4) break;
        tried.add(color);
        final candidate = _BubbleInterior.find(
          rgba,
          width,
          height,
          source,
          sample,
          crop,
          color,
          horizontalBar,
        );
        if (candidate == null) continue;
        final bounds = candidate.bounds;
        final intersection = bounds.intersect(source);
        if (intersection.isEmpty ||
            intersection.width * intersection.height <
                source.width * source.height * 0.6) {
          continue;
        }
        // 连到别的文字区域时不把两个气泡当成一个；检测框与本框重叠的除外。
        if (texts.any(
          (text) =>
              !text.overlaps(region.box) &&
              candidate.contains(
                Offset(text.center.dx * width, text.center.dy * height),
              ),
        )) {
          continue;
        }
        if (interior == null || candidate.pixels > interior.pixels) {
          interior = candidate;
          background = color;
        }
      }
    }
    final layout = interior?.layoutBox();
    Rect normalize(Rect rect) => Rect.fromLTRB(
      rect.left / width,
      rect.top / height,
      rect.right / width,
      rect.bottom / height,
    );
    return TranslationRegion(
      id: region.id,
      box: region.box,
      kind: region.kind,
      sourceText: region.sourceText,
      translatedText: region.translatedText,
      sourceVertical: region.sourceVertical,
      backgroundColor: background,
      boxSource: region.boxSource,
      layoutBox: layout == null ? null : normalize(layout),
      textPatches: layout == null
          ? null
          : interior!
                .erase(rgba, width, source, background)
                .map(
                  (patch) =>
                      TranslationTextPatch(normalize(patch.box), patch.color),
                )
                .toList(),
    );
  }
}

/// 局部连通背景的逐行内边界。行内文字留下的孔洞属于气泡内部。
class _BubbleInterior {
  _BubbleInterior(this.crop, this.lefts, this.rights, this.pixels, this.bounds);

  final Rect crop;
  final Int32List lefts;
  final Int32List rights;
  final int pixels;
  final Rect bounds;

  static _BubbleInterior? find(
    Uint8List rgba,
    int width,
    int height,
    Rect source,
    Rect sample,
    Rect crop,
    Color color,
    bool horizontalBar,
  ) {
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    bool matches(int x, int y) {
      final offset = (y * width + x) * 4;
      return _matchesBackground(
        rgba[offset],
        rgba[offset + 1],
        rgba[offset + 2],
        red,
        green,
        blue,
      );
    }

    int? seedX, seedY;
    var distance = double.infinity;
    final seeds = sample.intersect(crop);
    for (var y = seeds.top.toInt(); y < seeds.bottom; y++) {
      for (var x = seeds.left.toInt(); x < seeds.right; x++) {
        final d = (Offset(x.toDouble(), y.toDouble()) - source.center)
            .distanceSquared;
        final score =
            d +
            (source.contains(Offset(x.toDouble(), y.toDouble()))
                ? source.longestSide * source.longestSide * 4
                : 0);
        if (score < distance && matches(x, y)) {
          seedX = x;
          seedY = y;
          distance = score;
        }
      }
    }
    if (seedX == null || seedY == null) return null;
    final w = crop.width.toInt(), h = crop.height.toInt();
    final ox = crop.left.toInt(), oy = crop.top.toInt();
    final visited = Uint8List(w * h);
    final queue = Int32List(w * h);
    final seed = (seedY - oy) * w + seedX - ox;
    queue[0] = seed;
    visited[seed] = 1;
    var head = 0, tail = 1, outside = 0;
    final lefts = Int32List(h)..fillRange(0, h, w);
    final rights = Int32List(h)..fillRange(0, h, -1);
    var minX = w, maxX = -1, minY = h, maxY = -1;
    while (head < tail) {
      final pixel = queue[head++], x = pixel % w, y = pixel ~/ w;
      // 到达局部裁剪边缘说明尚未找到闭合边界；实际页边可截断气泡。
      if ((x == 0 && ox > 0) ||
          (y == 0 && oy > 0 && !horizontalBar) ||
          (x == w - 1 && crop.right < width) ||
          (y == h - 1 && crop.bottom < height && !horizontalBar)) {
        return null;
      }
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      lefts[y] = math.min(lefts[y], x);
      rights[y] = math.max(rights[y], x);
      if (!source.contains(Offset((x + ox).toDouble(), (y + oy).toDouble()))) {
        outside++;
      }
      for (final next in [
        if (x > 0) pixel - 1,
        if (x + 1 < w) pixel + 1,
        if (y > 0) pixel - w,
        if (y + 1 < h) pixel + w,
      ]) {
        if (visited[next] != 0) continue;
        visited[next] = 1;
        if (matches(next % w + ox, next ~/ w + oy)) queue[tail++] = next;
      }
    }
    final sourceArea = source.width * source.height;
    // 黑字或白色描边也会连通，但它们不会形成包围原文的大块背景。
    if (tail < sourceArea * 0.5 ||
        tail < (maxX - minX + 1) * (maxY - minY + 1) * 0.35 ||
        outside < math.max(4, sourceArea * 0.08) ||
        (minX + ox == 0 &&
            minY + oy == 0 &&
            maxX + ox == width - 1 &&
            maxY + oy == height - 1)) {
      return null;
    }
    return _BubbleInterior(
      crop,
      lefts,
      rights,
      tail,
      Rect.fromLTRB(
        (minX + ox).toDouble(),
        (minY + oy).toDouble(),
        (maxX + ox + 1).toDouble(),
        (maxY + oy + 1).toDouble(),
      ),
    );
  }

  bool contains(Offset point) {
    final y = (point.dy - crop.top).floor();
    return y >= 0 &&
        y < lefts.length &&
        point.dx >= crop.left + lefts[y] &&
        point.dx < crop.left + rights[y] + 1;
  }

  /// 在轮廓内取面积最大的居中矩形，给气泡尖角、圆边及尾巴留出空间。
  Rect? layoutBox() {
    final inset = math.max(2.0, bounds.shortestSide * 0.04);
    Rect? best;
    var bestScore = 0.0;
    for (final fraction in [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]) {
      final top = (bounds.center.dy - bounds.height * fraction / 2).ceil();
      final bottom = (bounds.center.dy + bounds.height * fraction / 2).floor();
      var left = bounds.left, right = bounds.right;
      for (var y = top; y < bottom; y++) {
        final row = y - crop.top.toInt();
        left = math.max(left, crop.left + lefts[row]);
        right = math.min(right, crop.left + rights[row] + 1);
      }
      final rect = Rect.fromLTRB(
        left + inset,
        top + inset,
        right - inset,
        bottom - inset,
      );
      final score =
          rect.width *
          rect.height *
          math.sqrt(math.min(1, rect.width / rect.height));
      if (!rect.isEmpty && score > bestScore) {
        best = rect;
        bestScore = score;
      }
    }
    return best;
  }

  /// 只覆盖原文及描边的像素，不填充整个排版矩形。
  List<TranslationTextPatch> erase(
    Uint8List rgba,
    int width,
    Rect source,
    Color color,
  ) {
    final area = source
        .inflate(math.max(3.0, math.min(16.0, source.shortestSide * 0.12)))
        .intersect(crop);
    final left = area.left.floor(), top = area.top.floor();
    final w = area.right.ceil() - left, h = area.bottom.ceil() - top;
    final mask = Uint8List(w * h);
    final r = (color.r * 255).round(), g = (color.g * 255).round();
    final b = (color.b * 255).round();
    bool cleanBackground(int red, int green, int blue) {
      final chroma = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
      final pixelChroma =
          math.max(red, math.max(green, blue)) -
          math.min(red, math.min(green, blue));
      return (chroma <= 30 || pixelChroma >= chroma * 0.7) &&
          _matchesBackground(red, green, blue, r, g, b);
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = x + left, py = y + top;
        if (!contains(Offset(px.toDouble(), py.toDouble()))) continue;
        final offset = (py * width + px) * 4;
        if (cleanBackground(rgba[offset], rgba[offset + 1], rgba[offset + 2])) {
          continue;
        }
        // 多覆盖一圈抗锯齿像素，保持在气泡轮廓内。
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx >= 0 &&
                nx < w &&
                ny >= 0 &&
                ny < h &&
                contains(
                  Offset((left + nx).toDouble(), (top + ny).toDouble()),
                )) {
              mask[ny * w + nx] = 1;
            }
          }
        }
      }
    }
    // 从笔画边缘向内补色，再平滑内部接缝；只读取轮廓内的干净背景。
    final repaired = Uint32List(w * h);
    int? knownColor(int x, int y) {
      if (x >= 0 && x < w && y >= 0 && y < h) {
        final index = y * w + x;
        if (mask[index] == 2) return repaired[index];
        if (mask[index] != 0) return null;
      }
      final px = left + x, py = top + y;
      if (!contains(Offset(px.toDouble(), py.toDouble()))) return null;
      final offset = (py * width + px) * 4;
      final red = rgba[offset],
          green = rgba[offset + 1],
          blue = rgba[offset + 2];
      if (!cleanBackground(red, green, blue)) return null;
      return 0xff000000 | red << 16 | green << 8 | blue;
    }

    int? averageNeighbours(int x, int y) {
      var red = 0, green = 0, blue = 0, count = 0;
      for (final (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]) {
        final value = knownColor(nx, ny);
        if (value == null) continue;
        red += value >> 16 & 255;
        green += value >> 8 & 255;
        blue += value & 255;
        count++;
      }
      return count == 0
          ? null
          : 0xff000000 |
                (red / count).round() << 16 |
                (green / count).round() << 8 |
                (blue / count).round();
    }

    final queue = Int32List(w * h);
    var head = 0, tail = 0;
    for (var pixel = 0; pixel < mask.length; pixel++) {
      if (mask[pixel] == 0) continue;
      repaired[pixel] = color.toARGB32();
      if (averageNeighbours(pixel % w, pixel ~/ w) != null) {
        mask[pixel] = 3;
        queue[tail++] = pixel;
      }
    }
    while (head < tail) {
      final pixel = queue[head++], x = pixel % w, y = pixel ~/ w;
      repaired[pixel] = averageNeighbours(x, y)!;
      mask[pixel] = 2;
      for (final next in [
        if (x > 0) pixel - 1,
        if (x + 1 < w) pixel + 1,
        if (y > 0) pixel - w,
        if (y + 1 < h) pixel + w,
      ]) {
        if (mask[next] == 1) {
          mask[next] = 3;
          queue[tail++] = next;
        }
      }
    }
    for (var iteration = 0; iteration < 12; iteration++) {
      for (var step = 0; step < tail; step++) {
        final pixel = queue[iteration.isEven ? step : tail - step - 1];
        repaired[pixel] = averageNeighbours(pixel % w, pixel ~/ w)!;
      }
    }
    // 小于四级的色差合并，控制修补数据和绘制批次的大小。
    int patchColor(int pixel) {
      final value = repaired[pixel];
      int quantize(int channel) => math.min(255, ((channel + 2) ~/ 4) * 4);
      return 0xff000000 |
          quantize(value >> 16 & 255) << 16 |
          quantize(value >> 8 & 255) << 8 |
          quantize(value & 255);
    }

    final patches = <TranslationTextPatch>[];
    var previous = <(int, int, int), int>{};
    for (var y = 0; y < h; y++) {
      final current = <(int, int, int), int>{};
      var x = 0;
      while (x < w) {
        if (mask[y * w + x] == 0) {
          x++;
          continue;
        }
        final start = x;
        final value = patchColor(y * w + x);
        while (x < w &&
            mask[y * w + x] != 0 &&
            patchColor(y * w + x) == value) {
          x++;
        }
        final repairColor = Color(value);
        final key = (start, x, value);
        final index = previous[key];
        if (index == null) {
          current[key] = patches.length;
          patches.add(
            TranslationTextPatch(
              Rect.fromLTRB(
                (left + start).toDouble(),
                (top + y).toDouble(),
                (left + x).toDouble(),
                (top + y + 1).toDouble(),
              ),
              repairColor,
            ),
          );
        } else {
          final rect = patches[index].box;
          patches[index] = TranslationTextPatch(
            Rect.fromLTRB(
              rect.left,
              rect.top,
              rect.right,
              (top + y + 1).toDouble(),
            ),
            repairColor,
          );
          current[key] = index;
        }
      }
      previous = current;
    }
    return patches;
  }
}
