import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/translation_models.dart';
import 'caption_bar_detector.dart';

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
    // 长竖列的字间留白不应被识别成横幅；模型偶尔也会漏报竖排方向。
    final narrowVertical =
        source.height > source.width * 2 &&
        RegExp(
              r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',
            ).allMatches(region.sourceText).length >=
            2;
    final sourceVertical = region.sourceVertical || narrowVertical;
    final caption =
        narrowVertical ||
            region.kind == TranslationRegionKind.sfx ||
            region.kind == TranslationRegionKind.other
        ? null
        : const CaptionBarDetector().find(
            rgba,
            width,
            height,
            source,
            requireSourceCoverage:
                region.boxSource == TranslationBoxSource.detector,
          );
    final sampleMargin = math.max(
      2.0,
      math.min(24.0, source.shortestSide * 0.3),
    );
    final sample =
        caption ??
        source
            .inflate(sampleMargin)
            .intersect(
              Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            );
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
    _BubbleInterior? interior = caption == null
        ? null
        : _BubbleInterior.caption(caption);
    final horizontalBar =
        caption != null ||
        region.kind == TranslationRegionKind.caption &&
            !narrowVertical &&
            (region.boxSource != TranslationBoxSource.detector ||
                source.height <= width * .07) ||
        region.kind == TranslationRegionKind.narration &&
            source.width > source.height * 4;
    if (caption == null &&
        (region.kind == TranslationRegionKind.bubble ||
            region.kind == TranslationRegionKind.narration ||
            region.kind == TranslationRegionKind.caption ||
            horizontalBar)) {
      final margin = math.max(
        12.0,
        source.longestSide * (horizontalBar ? 3 : 2),
      );
      var limits = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      if (!horizontalBar) {
        for (final text in texts) {
          if (text.overlaps(region.box)) continue;
          final other = Rect.fromLTRB(
            text.left * width,
            text.top * height,
            text.right * width,
            text.bottom * height,
          );
          if (other.left < source.right && other.right > source.left) {
            if (other.top >= source.bottom) {
              limits = Rect.fromLTRB(
                limits.left,
                limits.top,
                limits.right,
                math.min(
                  limits.bottom,
                  ((source.bottom + other.top) / 2).floorToDouble(),
                ),
              );
            } else if (other.bottom <= source.top) {
              limits = Rect.fromLTRB(
                limits.left,
                math.max(
                  limits.top,
                  ((source.top + other.bottom) / 2).ceilToDouble(),
                ),
                limits.right,
                limits.bottom,
              );
            }
          } else if (other.top < source.bottom && other.bottom > source.top) {
            if (other.left >= source.right) {
              limits = Rect.fromLTRB(
                limits.left,
                limits.top,
                math.min(
                  limits.right,
                  ((source.right + other.left) / 2).floorToDouble(),
                ),
                limits.bottom,
              );
            } else if (other.right <= source.left) {
              limits = Rect.fromLTRB(
                math.max(
                  limits.left,
                  ((source.left + other.right) / 2).ceilToDouble(),
                ),
                limits.top,
                limits.right,
                limits.bottom,
              );
            }
          }
        }
      }
      final crop = Rect.fromLTRB(
        horizontalBar ? 0 : math.max(0, (source.left - margin).floorToDouble()),
        math.max(
          0,
          (source.top - (horizontalBar ? source.height * 0.3 : margin))
              .floorToDouble(),
        ),
        horizontalBar
            ? width.toDouble()
            : math.min(
                width.toDouble(),
                (source.right + margin).ceilToDouble(),
              ),
        math.min(
          height.toDouble(),
          (source.bottom + (horizontalBar ? source.height * 0.3 : margin))
              .ceilToDouble(),
        ),
      ).intersect(limits);
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
          horizontalBar ? null : limits,
        );
        if (candidate == null) continue;
        if (horizontalBar && candidate.captionBox(source) == null) {
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
    final layout =
        caption ??
        (horizontalBar ? interior?.captionBox(source) : interior?.layoutBox());
    Rect normalize(Rect rect) => Rect.fromLTRB(
      rect.left / width,
      rect.top / height,
      rect.right / width,
      rect.bottom / height,
    );
    final eraseAreas = <Rect>[];
    if (caption != null) {
      eraseAreas.add(caption);
    } else if (layout != null) {
      for (final box
          in region.sourceBoxes.isEmpty ? [region.box] : region.sourceBoxes) {
        var area = Rect.fromLTRB(
          box.left * width,
          box.top * height,
          box.right * width,
          box.bottom * height,
        );
        // 竖排原文的其他列也在同一段的高度范围内；相邻段已在搜索范围中隔开。
        if (sourceVertical && !horizontalBar) {
          area = Rect.fromLTRB(
            interior!.bounds.left,
            area.top,
            interior.bounds.right,
            area.bottom,
          );
        }
        final overlap = eraseAreas.indexWhere((other) => other.overlaps(area));
        if (overlap < 0) {
          eraseAreas.add(area);
        } else {
          eraseAreas[overlap] = eraseAreas[overlap].expandToInclude(area);
        }
      }
    }
    return TranslationRegion(
      id: region.id,
      box: region.box,
      kind: horizontalBar
          ? TranslationRegionKind.caption
          : region.kind == TranslationRegionKind.caption
          ? TranslationRegionKind.narration
          : region.kind,
      sourceText: region.sourceText,
      translatedText: region.translatedText,
      sourceVertical: !horizontalBar && sourceVertical,
      backgroundColor: background,
      boxSource: region.boxSource,
      sourceBoxes: region.sourceBoxes,
      sourceIds: region.sourceIds,
      layoutBox: layout == null ? null : normalize(layout),
      textPatches: layout == null
          ? null
          : eraseAreas
                .expand(
                  (area) => interior!.erase(
                    rgba,
                    width,
                    area,
                    background,
                    lightCaption: caption != null,
                  ),
                )
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

  factory _BubbleInterior.caption(Rect rect) {
    final crop = Rect.fromLTRB(
      rect.left.ceilToDouble(),
      rect.top.ceilToDouble(),
      rect.right.floorToDouble(),
      rect.bottom.floorToDouble(),
    );
    final w = crop.width.toInt(), h = crop.height.toInt();
    return _BubbleInterior(
      crop,
      Int32List(h),
      Int32List(h)..fillRange(0, h, w - 1),
      w * h,
      crop,
    );
  }

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
    Rect? passageLimits,
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

    final w = crop.width.toInt(), h = crop.height.toInt();
    final ox = crop.left.toInt(), oy = crop.top.toInt();
    final seedArea = sample.intersect(crop);
    final seeds = <(double, int)>[];
    for (var y = seedArea.top.toInt(); y < seedArea.bottom; y++) {
      for (var x = seedArea.left.toInt(); x < seedArea.right; x++) {
        if (!matches(x, y)) continue;
        final d = (Offset(x.toDouble(), y.toDouble()) - source.center)
            .distanceSquared;
        final score =
            d +
            (source.contains(Offset(x.toDouble(), y.toDouble()))
                ? source.longestSide * source.longestSide * 4
                : 0);
        seeds.add((score, (y - oy) * w + x - ox));
      }
    }
    seeds.sort((a, b) => a.$1.compareTo(b.$1));
    final visited = Uint8List(w * h);
    final queue = Int32List(w * h);
    // 框可能紧贴粗体笔画，允许底色在笔画边缘，不能要求框内有固定比例的底色。
    final nearSource = source.inflate(
      math.max(4.0, math.min(8.0, source.shortestSide * .1)),
    );
    // 最近的同色像素可能是字形孔洞，逐个检查不同连通区域。
    for (final (_, seed) in seeds) {
      if (visited[seed] != 0) continue;
      queue[0] = seed;
      visited[seed] = 1;
      var head = 0, tail = 1, outside = 0, near = 0;
      final lefts = Int32List(h)..fillRange(0, h, w);
      final rights = Int32List(h)..fillRange(0, h, -1);
      var minX = w, maxX = -1, minY = h, maxY = -1;
      var open = false;
      while (head < tail) {
        final pixel = queue[head++], x = pixel % w, y = pixel ~/ w;
        // 到达局部裁剪边缘说明尚未找到闭合边界；实际页边可截断气泡。
        if ((x == 0 && ox > 0 && crop.left != passageLimits?.left) ||
            (y == 0 &&
                oy > 0 &&
                !horizontalBar &&
                crop.top != passageLimits?.top) ||
            (x == w - 1 &&
                crop.right < width &&
                crop.right != passageLimits?.right) ||
            (y == h - 1 &&
                crop.bottom < height &&
                !horizontalBar &&
                crop.bottom != passageLimits?.bottom)) {
          open = true;
        }
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        lefts[y] = math.min(lefts[y], x);
        rights[y] = math.max(rights[y], x);
        if (nearSource.contains(
          Offset((x + ox).toDouble(), (y + oy).toDouble()),
        )) {
          near++;
        }
        if (!source.contains(
          Offset((x + ox).toDouble(), (y + oy).toDouble()),
        )) {
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
      final naturalEdges =
          (minX > 0 ? 1 : 0) +
          (minY > 0 ? 1 : 0) +
          (maxX < w - 1 ? 1 : 0) +
          (maxY < h - 1 ? 1 : 0);
      final bounds = Rect.fromLTRB(
        (minX + ox).toDouble(),
        (minY + oy).toDouble(),
        (maxX + ox + 1).toDouble(),
        (maxY + oy + 1).toDouble(),
      );
      final intersection = bounds.intersect(source);
      // 黑字或白色描边也会连通，但它们不会形成包围原文的大块背景。
      // 包围气泡的街道也可能有同样大的外接框，必须实际覆盖原文框内部。
      if (open ||
          naturalEdges < (horizontalBar ? 1 : 2) ||
          intersection.isEmpty ||
          intersection.width * intersection.height < sourceArea * 0.6 ||
          tail < sourceArea * 0.5 ||
          near < math.max(4, sourceArea * .01) ||
          tail < (maxX - minX + 1) * (maxY - minY + 1) * 0.35 ||
          outside < math.max(4, sourceArea * 0.08) ||
          (horizontalBar && minX + ox == 0 && maxX + ox == width - 1) ||
          (minX + ox == 0 &&
              minY + oy == 0 &&
              maxX + ox == width - 1 &&
              maxY + oy == height - 1)) {
        continue;
      }
      if (!horizontalBar) {
        // 粗体字和描边会隔开底色。只补齐原文框内、上下均有同一连通底色的孔洞。
        final tops = Int32List(w)..fillRange(0, w, h);
        final bottoms = Int32List(w)..fillRange(0, w, -1);
        for (var index = 0; index < tail; index++) {
          final x = queue[index] % w, y = queue[index] ~/ w;
          tops[x] = math.min(tops[x], y);
          bottoms[x] = math.max(bottoms[x], y);
        }
        for (
          var x = math.max(0, source.left.toInt() - ox);
          x < math.min(w, source.right.toInt() - ox);
          x++
        ) {
          final top = math.max(tops[x], source.top.toInt() - oy);
          final bottom = math.min(bottoms[x], source.bottom.toInt() - oy - 1);
          for (var y = top; y <= bottom; y++) {
            lefts[y] = math.min(lefts[y], x);
            rights[y] = math.max(rights[y], x);
          }
        }
      }
      return _BubbleInterior(crop, lefts, rights, tail, bounds);
    }
    return null;
  }

  bool contains(Offset point) {
    final y = (point.dy - crop.top).floor();
    return y >= 0 &&
        y < lefts.length &&
        point.dx >= crop.left + lefts[y] &&
        point.dx < crop.left + rights[y] + 1;
  }

  /// 取原文所在的连续长条行，利用横向边界的变化排除上下相连的白色画面。
  Rect? captionBox(Rect source) {
    final row = (source.center.dy - crop.top).floor().clamp(
      0,
      lefts.length - 1,
    );
    final referenceWidth = rights[row] - lefts[row] + 1;
    if (referenceWidth < source.width || referenceWidth < source.height * 4) {
      return null;
    }
    bool sameBar(int y) =>
        rights[y] - lefts[y] + 1 >= referenceWidth * 0.85 &&
        (lefts[y] - lefts[row]).abs() < referenceWidth * 0.15 &&
        (rights[y] - rights[row]).abs() < referenceWidth * 0.15;
    var top = row, bottom = row;
    while (top > 0 && sameBar(top - 1)) {
      top--;
    }
    while (bottom + 1 < lefts.length && sameBar(bottom + 1)) {
      bottom++;
    }
    var left = lefts[row], right = rights[row];
    for (var y = top; y <= bottom; y++) {
      left = math.max(left, lefts[y]);
      right = math.min(right, rights[y]);
    }
    final h = bottom - top + 1;
    if (h < math.min(source.height * .8, crop.width * .018)) return null;
    if (right - left + 1 < h * 4) return null;
    final margin = math.max(1.0, h * 0.06);
    final box = Rect.fromLTRB(
      crop.left + left + margin,
      crop.top + top + margin,
      crop.left + right + 1 - margin,
      crop.top + bottom + 1 - margin,
    );
    return box.isEmpty ? null : box;
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
    Color color, {
    bool lightCaption = false,
  }) {
    final area = source
        .inflate(math.max(3.0, math.min(16.0, source.shortestSide * 0.12)))
        .intersect(crop);
    if (area.isEmpty) return const [];
    final left = area.left.floor(), top = area.top.floor();
    final w = area.right.ceil() - left, h = area.bottom.ceil() - top;
    final mask = Uint8List(w * h);
    final r = (color.r * 255).round(), g = (color.g * 255).round();
    final b = (color.b * 255).round();
    bool cleanBackground(int red, int green, int blue) {
      if (lightCaption) return red >= 180 && green >= 180 && blue >= 180;
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
