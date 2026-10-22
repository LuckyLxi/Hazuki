import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class HazukiLoadMoreFooter extends StatefulWidget {
  const HazukiLoadMoreFooter({super.key, this.verticalPadding = 6});

  final double verticalPadding;

  @override
  State<HazukiLoadMoreFooter> createState() => _HazukiLoadMoreFooterState();
}

class _HazukiLoadMoreFooterState extends State<HazukiLoadMoreFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withAlpha(232),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(148),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  final iconLift = math.sin(progress * math.pi * 2) * 1.4;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(0, -iconLift),
                        child: Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      for (var index = 0; index < 3; index++) ...[
                        _AnimatedLoadDot(
                          progress: progress,
                          index: index,
                          color: index == 1
                              ? colorScheme.primary
                              : colorScheme.secondary,
                        ),
                        if (index < 2) const SizedBox(width: 6),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLoadDot extends StatelessWidget {
  const _AnimatedLoadDot({
    required this.progress,
    required this.index,
    required this.color,
  });

  final double progress;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final phase = (progress - index * 0.14) % 1;
    final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
    final scale = 0.72 + wave * 0.48;
    final opacity = 0.3 + wave * 0.7;
    final lift = 1.5 + wave * 2.2;

    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.scale(
        scale: scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha((opacity * 255).round()),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((opacity * 90).round()),
                blurRadius: 6,
              ),
            ],
          ),
          child: const SizedBox(width: 7, height: 7),
        ),
      ),
    );
  }
}

class HazukiSearchingAnimationIndicator extends StatelessWidget {
  const HazukiSearchingAnimationIndicator({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/stickers/loading/searching_animation.json',
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}

/// 全页加载指示器：一本漫画书逐页向左翻动，颜色跟随当前 [ColorScheme]。
class HazukiSandyLoadingIndicator extends StatelessWidget {
  const HazukiSandyLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _LoopingPaintIndicator(
      size: size,
      period: _BookFlipPainter.period,
      painterBuilder: (animation, colorScheme) =>
          _BookFlipPainter(animation: animation, colorScheme: colorScheme),
    );
  }
}

/// 阅读器首次加载指示器：漫画分镜格按阅读顺序依次描边、上色后淡出。
class HazukiMangaPanelsLoadingIndicator extends StatelessWidget {
  const HazukiMangaPanelsLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _LoopingPaintIndicator(
      size: size,
      period: _MangaPanelsPainter.period,
      painterBuilder: (animation, colorScheme) =>
          _MangaPanelsPainter(animation: animation, colorScheme: colorScheme),
    );
  }
}

class _LoopingPaintIndicator extends StatefulWidget {
  const _LoopingPaintIndicator({
    required this.size,
    required this.period,
    required this.painterBuilder,
  });

  final double size;
  final Duration period;
  final CustomPainter Function(
    Animation<double> animation,
    ColorScheme colorScheme,
  )
  painterBuilder;

  @override
  State<_LoopingPaintIndicator> createState() => _LoopingPaintIndicatorState();
}

class _LoopingPaintIndicatorState extends State<_LoopingPaintIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: widget.painterBuilder(_controller, colorScheme),
        ),
      ),
    );
  }
}

class _BookFlipPainter extends CustomPainter {
  _BookFlipPainter({required this.animation, required this.colorScheme})
    : super(repaint: animation);

  static const period = Duration(milliseconds: 1400);
  // 一个周期内翻页动作所占比例，剩余时间停顿
  static const _flipFraction = 950 / 1400;

  final Animation<double> animation;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final bw = s * .33;
    final bh = s * .46;
    final cx = size.width / 2;
    final top = (size.height - s) / 2 + s * .29;
    final bottom = top + bh;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cx - bw - s * .03,
          top - s * .025,
          bw * 2 + s * .06,
          bh + s * .055,
        ),
        Radius.circular(s * .03),
      ),
      Paint()..color = colorScheme.primary,
    );

    final pageFill = Paint()..color = colorScheme.surfaceContainerHigh;
    final pageEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .008
      ..color = colorScheme.outlineVariant;
    for (final left in [cx - bw, cx]) {
      final rect = Rect.fromLTWH(left, top, bw, bh);
      canvas
        ..drawRect(rect, pageFill)
        ..drawRect(rect, pageEdge);
      _paintPageMarks(canvas, Offset(left, top), bw, bh, s);
    }

    final q = animation.value;
    final angle = q < _flipFraction
        ? Curves.easeInOutCubic.transform(q / _flipFraction) * math.pi
        : math.pi;
    if (angle > 0 && angle < math.pi) {
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final x = cx + bw * cosA;
      final lift = sinA * s * .06;
      final page = Path()
        ..moveTo(cx, top)
        ..lineTo(x, top - lift)
        ..lineTo(x, bottom + lift * .35)
        ..lineTo(cx, bottom)
        ..close();
      canvas.drawPath(page, pageFill);
      // 以书脊为原点做仿射变换，让翻起的页面上的分镜格随角度收窄、倾斜
      canvas
        ..save()
        ..clipPath(page)
        ..transform(
          Float64List.fromList([
            cosA, -lift / bw, 0, 0, //
            0, 1, 0, 0, //
            0, 0, 1, 0, //
            cx, top, 0, 1,
          ]),
        );
      _paintPageMarks(canvas, Offset.zero, bw, bh, s);
      canvas.restore();
      canvas
        ..drawPath(
          page,
          Paint()..color = Colors.black.withValues(alpha: .2 * sinA),
        )
        ..drawPath(page, pageEdge);
    }

    canvas.drawLine(
      Offset(cx, top),
      Offset(cx, bottom),
      Paint()
        ..strokeWidth = s * .01
        ..color = colorScheme.onSurfaceVariant.withValues(alpha: .5),
    );
  }

  void _paintPageMarks(
    Canvas canvas,
    Offset origin,
    double bw,
    double bh,
    double s,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .008
      ..color = colorScheme.onSurfaceVariant.withValues(alpha: .35);
    final inset = s * .035;
    final w = bw - inset * 2;
    final x = origin.dx + inset;
    final y = origin.dy + inset;
    canvas
      ..drawRect(Rect.fromLTWH(x, y, w, bh * .3), paint)
      ..drawRect(Rect.fromLTWH(x, y + bh * .34, w * .48, bh * .26), paint)
      ..drawRect(
        Rect.fromLTWH(x + w * .54, y + bh * .34, w * .46, bh * .26),
        paint,
      )
      ..drawRect(
        Rect.fromLTWH(x, y + bh * .64, w, bh * .36 - inset * 2),
        paint,
      );
  }

  @override
  bool shouldRepaint(_BookFlipPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.colorScheme != colorScheme;
}

class _MangaPanelsPainter extends CustomPainter {
  _MangaPanelsPainter({required this.animation, required this.colorScheme})
    : super(repaint: animation);

  static const period = Duration(milliseconds: 2600);

  // 分镜格顶点，坐标为页面宽高的比例，按阅读顺序排列
  static const _panels = <List<Offset>>[
    [Offset(0, 0), Offset(1, 0), Offset(1, .30), Offset(0, .34)],
    [Offset(0, .38), Offset(.46, .375), Offset(.40, .64), Offset(0, .64)],
    [Offset(.50, .37), Offset(1, .345), Offset(1, .64), Offset(.44, .64)],
    [Offset(0, .68), Offset(.58, .68), Offset(.58, 1), Offset(0, 1)],
    [Offset(.62, .68), Offset(1, .68), Offset(1, 1), Offset(.62, 1)],
  ];

  final Animation<double> animation;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final pw = s * .54;
    final ph = s * .72;
    final ox = (size.width - pw) / 2;
    final oy = (size.height - ph) / 2;

    final sheet = RRect.fromRectAndRadius(
      Rect.fromLTWH(ox - s * .05, oy - s * .05, pw + s * .1, ph + s * .1),
      Radius.circular(s * .03),
    );
    canvas
      ..drawRRect(sheet, Paint()..color = colorScheme.surfaceContainerHigh)
      ..drawRRect(
        sheet,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .01
          ..color = colorScheme.outlineVariant,
      );

    final q = animation.value;
    // 周期末尾整体淡出，再从第一格重新开始
    final opacity = q > .84 ? 1 - (q - .84) / .16 : 1.0;
    final ease = Curves.easeInOutCubic;

    for (var i = 0; i < _panels.length; i++) {
      final start = i * .11;
      final drawProgress = ((q - start) / .2).clamp(0.0, 1.0);
      if (drawProgress <= 0) continue;

      final points = [
        for (final p in _panels[i]) Offset(ox + p.dx * pw, oy + p.dy * ph),
      ];
      final path = Path()..addPolygon(points, true);

      final fillProgress = ease.transform(
        ((q - start - .18) / .12).clamp(0.0, 1.0),
      );
      if (fillProgress > 0) {
        final tint = i.isOdd ? colorScheme.primary : colorScheme.tertiary;
        final alpha = (i.isOdd ? .3 : .24) * fillProgress * opacity;
        canvas.drawPath(path, Paint()..color = tint.withValues(alpha: alpha));
      }

      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .022
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colorScheme.onSurface.withValues(alpha: opacity);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * ease.transform(drawProgress)),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_MangaPanelsPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.colorScheme != colorScheme;
}
