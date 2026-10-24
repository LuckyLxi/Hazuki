import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// 从原图中的平行上下边界确认浅色横幅，不依赖模型返回的区域类型。
class CaptionBarDetector {
  const CaptionBarDetector();

  Rect? find(Uint8List rgba, int width, int height, Rect source) {
    final minimumHeight = math.max(8, (width * .012).round());
    final maximumHeight = math.max(minimumHeight, (width * .07).round());
    final padding = math.max(4, math.min(source.height / 2, width * .03));
    final firstRow = math.max(0, (source.top - padding).floor());
    final lastRow = math.min(height, (source.bottom + padding).ceil());
    final rowStep = math.max(1, minimumHeight ~/ 3);
    final gapLimit = math.max(3, (width * .03).round());
    bool light(int x, int y) {
      final offset = (y * width + x) * 4;
      final r = rgba[offset], g = rgba[offset + 1], b = rgba[offset + 2];
      return math.min(r, math.min(g, b)) >= 200 &&
          math.max(r, math.max(g, b)) - math.min(r, math.min(g, b)) < 40;
    }

    (int, int)? span(int x, int y) {
      // 按列检查上下色差，白色衣服或页边不能无限延伸横幅高度。
      if (!light(x, y)) return null;
      final offset = (y * width + x) * 4;
      bool same(int row) {
        if (!light(x, row)) return false;
        final next = (row * width + x) * 4;
        var distance = 0;
        for (var channel = 0; channel < 3; channel++) {
          final delta = rgba[next + channel] - rgba[offset + channel];
          distance += delta * delta;
        }
        return distance <= 28 * 28;
      }

      var top = y, bottom = y + 1;
      while (top > 0 && y - top < maximumHeight && same(top - 1)) {
        top--;
      }
      while (bottom < height && bottom - y < maximumHeight && same(bottom)) {
        bottom++;
      }
      if (top == 0 ||
          bottom == height ||
          y - top == maximumHeight ||
          bottom - y == maximumHeight ||
          bottom - top < minimumHeight ||
          bottom - top > maximumHeight) {
        return null;
      }
      return (top, bottom);
    }

    Rect? best;
    var bestScore = double.negativeInfinity;
    for (var y = firstRow; y < lastRow; y += rowStep) {
      var start = -1, last = -1;
      void checkRun() {
        if (start < 0 ||
            last - start < width * .2 ||
            source.center.dx < start ||
            source.center.dx > last) {
          return;
        }
        final spans = <(int, int)>[];
        for (var index = 1; index < 24; index++) {
          final x = start + ((last - start) * index / 24).round();
          final candidate = span(x, y);
          if (candidate != null) spans.add(candidate);
        }
        var consistent = <(int, int)>[];
        // 字形孔洞也会形成短段，使用多个取样列共同确认的上下边界。
        for (final reference in spans) {
          final tolerance = (reference.$2 - reference.$1) * .15;
          final group = spans
              .where(
                (item) =>
                    (item.$1 - reference.$1).abs() <= tolerance &&
                    (item.$2 - reference.$2).abs() <= tolerance,
              )
              .toList();
          if (group.length > consistent.length) consistent = group;
        }
        if (consistent.length < 5) return;
        final tops = consistent.map((item) => item.$1).toList()..sort();
        final bottoms = consistent.map((item) => item.$2).toList()..sort();
        final top = tops[tops.length ~/ 2];
        final bottom = bottoms[bottoms.length ~/ 2];
        final barHeight = bottom - top;
        if (barHeight < minimumHeight || last - start < barHeight * 5) return;
        var left = -1, right = -1, runStart = -1, previous = -1;
        void closeRun() {
          if (runStart >= 0 &&
              source.center.dx >= runStart &&
              source.center.dx <= previous) {
            left = runStart;
            right = previous + 1;
          }
        }

        for (var x = start; x <= last; x++) {
          final candidate = span(x, y);
          if (candidate == null ||
              (candidate.$1 - top).abs() > barHeight * .15 ||
              (candidate.$2 - bottom).abs() > barHeight * .15) {
            continue;
          }
          final crossesSource =
              previous < source.right &&
              x > source.left &&
              x - previous <= source.width + barHeight * 2;
          // 原文遮住底色时，只跨过文字区，接上两侧一致的边界。
          if (previous >= 0 &&
              !crossesSource &&
              x - previous > math.max(gapLimit, barHeight)) {
            closeRun();
            runStart = -1;
          }
          if (runStart < 0) runStart = x;
          previous = x;
        }
        closeRun();
        if (left < 0 || right - left < math.max(width * .2, barHeight * 5)) {
          return;
        }
        // 横幅中应有原文笔画，空白的画面分界线不作为排版区域。
        var ink = 0;
        for (var row = top; row < bottom; row++) {
          for (
            var x = math.max(left, source.left.floor());
            x < math.min(right, source.right.ceil());
            x++
          ) {
            final offset = (row * width + x) * 4;
            if (rgba[offset] < 150 &&
                rgba[offset + 1] < 150 &&
                rgba[offset + 2] < 150) {
              ink++;
            }
          }
        }
        if (ink < 4) return;
        final inset = math.max(1.0, barHeight * .08);
        final rect = Rect.fromLTRB(
          left + inset,
          top + inset,
          right - inset,
          bottom - inset,
        );
        final score =
            rect.width *
            rect.height /
            (1 + (rect.center.dy - source.center.dy).abs() / maximumHeight);
        if (score > bestScore) {
          best = rect;
          bestScore = score;
        }
      }

      for (var x = 0; x < width; x++) {
        if (light(x, y)) {
          if (start < 0) start = x;
          last = x;
        } else if (start >= 0 && x - last > gapLimit) {
          checkRun();
          start = -1;
        }
      }
      checkRun();
    }
    return best;
  }
}
