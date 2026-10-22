import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';

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

/// 搜索状态指示器：搜索中放大镜在书架上来回巡查；切到 [empty] 时
/// 放大镜从当前位置滑到中央、长出眼睛并左右张望，两段动画无缝衔接。
///
/// 衔接依赖同一个 State 跨状态存活，调用方需保持该组件的 key 不变。
class HazukiSearchLensIndicator extends StatefulWidget {
  const HazukiSearchLensIndicator({
    super.key,
    required this.empty,
    this.size = 200,
  });

  final bool empty;
  final double size;

  @override
  State<HazukiSearchLensIndicator> createState() =>
      _HazukiSearchLensIndicatorState();
}

class _HazukiSearchLensIndicatorState extends State<HazukiSearchLensIndicator>
    with SingleTickerProviderStateMixin {
  // 单帧最多推进的秒数：主线程卡顿或 ticker 被静音后，动画从停下处继续，而不是跳到按真实时间推算的位置
  static const _maxFrameStep = 1 / 30;

  // 动画时间轴（秒），逐帧累加；各阶段的时间点都以此为基准换算
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastElapsed = Duration.zero;

  double _searchStart = 0;
  bool _searchFadeIn = false;
  double? _emptyStart;
  bool _emptyFromSearch = false;

  @override
  void initState() {
    super.initState();
    if (widget.empty) _emptyStart = 0;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final step =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    _time.value += step.clamp(0.0, _maxFrameStep);
  }

  @override
  void didUpdateWidget(HazukiSearchLensIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.empty == widget.empty) return;
    if (widget.empty) {
      _emptyStart = _time.value;
      _emptyFromSearch = true;
    } else {
      // 从空结果重新搜索：书架场景淡入重来，不做反向过渡
      _emptyStart = null;
      _searchStart = _time.value;
      _searchFadeIn = true;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 转场期间保持实时渲染，否则快照路由会把放大镜冻结在第一帧
    return RouteTransitionLiveContent(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _SearchLensPainter(
              time: _time,
              colorScheme: theme.colorScheme,
              textStyle: theme.textTheme.bodyMedium,
              searchStart: _searchStart,
              searchFadeIn: _searchFadeIn,
              emptyStart: _emptyStart,
              emptyFromSearch: _emptyFromSearch,
            ),
          ),
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
    // 从详情页进入阅读器时保持实时渲染，否则快照路由会把分镜动画冻结在第一帧
    return RouteTransitionLiveContent(
      child: _LoopingPaintIndicator(
        size: size,
        period: _MangaPanelsPainter.period,
        painterBuilder: (animation, colorScheme) =>
            _MangaPanelsPainter(animation: animation, colorScheme: colorScheme),
      ),
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

class _SearchLensPainter extends CustomPainter {
  _SearchLensPainter({
    required this.time,
    required this.colorScheme,
    required this.textStyle,
    required this.searchStart,
    required this.searchFadeIn,
    required this.emptyStart,
    required this.emptyFromSearch,
  }) : super(repaint: time);

  // 所有坐标在 100×100 的逻辑画布内计算，绘制前统一缩放到实际尺寸
  static const _center = Offset(50, 50);
  // 搜索阶段整体缩小，视觉尺寸与旧版 156 的加载动画一致
  static const _searchScale = .78;
  static const _sweepPeriod = 2.6;
  static const _transition = .7;
  // 衔接时从空结果时间轴的该时刻接入，跳过下落入场
  static const _emptyJoinAt = .6;
  static const _emptyLensCenter = Offset(46, 50);
  static const _searchLensRadius = 14.0;
  static const _emptyLensRadius = 17.0;
  static const _shelfBase = 80.0;
  // 书脊 (x, 宽, 高)
  static const _books = <(double, double, double)>[
    (14, 11, 44),
    (26, 9, 52),
    (36, 13, 40),
    (50, 10, 48),
    (61, 12, 56),
    (74, 11, 42),
  ];

  final ValueNotifier<double> time;
  final ColorScheme colorScheme;
  final TextStyle? textStyle;
  final double searchStart;
  final bool searchFadeIn;
  final double? emptyStart;
  final bool emptyFromSearch;

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  static double _lerp(double a, double b, double q) => a + (b - a) * q;

  static double _ease(double q) => Curves.easeInOutCubic.transform(q);

  static double _back(double q) => Curves.easeOutBack.transform(q);

  /// 搜索阶段放大镜在时刻 [ts] 的位置（未缩放的书架坐标）。
  static Offset _sweepAt(double ts) => Offset(
    50 + 24 * math.sin(ts * math.pi * 2 / _sweepPeriod),
    42 + 2 * math.sin(ts * math.pi * 4 / _sweepPeriod),
  );

  static void _scaleAbout(Canvas canvas, Offset origin, double k) {
    canvas
      ..translate(origin.dx, origin.dy)
      ..scale(k)
      ..translate(-origin.dx, -origin.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = time.value;

    canvas
      ..save()
      ..translate((size.width - s) / 2, (size.height - s) / 2)
      ..scale(s / 100);

    final emptyAt = emptyStart;
    if (emptyAt == null) {
      final ts = t - searchStart;
      final opacity = searchFadeIn ? _seg(ts, 0, .3) : 1.0;
      if (opacity < 1) {
        canvas.saveLayer(
          null,
          Paint()..color = Colors.black.withValues(alpha: opacity),
        );
      }
      _paintSearching(canvas, ts);
      if (opacity < 1) canvas.restore();
    } else {
      final te = t - emptyAt;
      if (!emptyFromSearch) {
        _paintEmpty(canvas, te);
      } else if (te < _transition) {
        _paintTransition(
          canvas,
          _ease(_seg(te, 0, _transition)),
          _sweepAt(emptyAt - searchStart),
        );
      } else {
        _paintEmpty(canvas, _emptyJoinAt + te - _transition);
      }
    }

    canvas.restore();
  }

  void _paintSearching(Canvas canvas, double ts) {
    final lens = _sweepAt(ts);
    canvas.save();
    _scaleAbout(canvas, _center, _searchScale);
    _paintShelf(canvas, lens.dx, magnified: false);
    _paintLens(
      canvas,
      lens,
      _searchLensRadius,
      inner: () {
        _scaleAbout(canvas, lens, 1.45);
        _paintShelf(canvas, lens.dx, magnified: true);
      },
    );
    canvas.restore();
  }

  /// 书架淡出下沉，放大镜从 [from] 滑到中央并放大，镜片内书脊淡出、眼睛长出。
  void _paintTransition(Canvas canvas, double q, Offset from) {
    canvas.save();
    _scaleAbout(canvas, _center, _searchScale);
    canvas.translate(0, 8 * q);
    _paintShelf(canvas, from.dx, magnified: false, opacity: 1 - q);
    canvas.restore();

    final start = _center + (from - _center) * _searchScale;
    final lens = Offset.lerp(start, _emptyLensCenter, q)!;
    final r = _lerp(_searchLensRadius * _searchScale, _emptyLensRadius, q);
    final eyes = _seg(q, .45, 1);
    _paintLens(
      canvas,
      lens,
      r,
      inner: () {
        // 镜片内容的放大中心随镜片一起移动，保证 q=0 时与搜索阶段完全重合
        canvas
          ..save()
          ..translate(lens.dx, lens.dy)
          ..scale(r / _searchLensRadius * 1.45)
          ..translate(-from.dx, -from.dy);
        _paintShelf(canvas, from.dx, magnified: true, opacity: 1 - q);
        canvas.restore();
        if (eyes > 0) {
          _paintEyes(canvas, lens, r / _emptyLensRadius, 0, 3 * _back(eyes));
        }
      },
    );
  }

  void _paintEmpty(Canvas canvas, double t) {
    var y = _lerp(-30, 50, _back(_seg(t, 0, .55)));
    final double look;
    if (t < .65) {
      look = 0;
    } else if (t < 1.0) {
      look = -_ease(_seg(t, .65, 1.0));
    } else if (t < 1.15) {
      look = -1;
    } else if (t < 1.55) {
      look = _lerp(-1, 1, _ease(_seg(t, 1.15, 1.55)));
    } else if (t < 1.75) {
      look = 1;
    } else {
      look = _lerp(1, 0, _ease(_seg(t, 1.75, 2.05)));
    }
    if (t > 3) y += 1.4 * math.sin((t - 3) * math.pi * 2 / 2.4);
    final x = _emptyLensCenter.dx + look * 7;
    final lens = Offset(x, y);
    final blinkPhase = t > 2.3 ? (t - 2.3) % 3.6 : double.infinity;
    final eyeHeight = blinkPhase < .14 ? .35 : 3.0;

    canvas
      ..save()
      ..translate(x, y)
      ..rotate(look * .18)
      ..translate(-x, -y);
    _paintLens(
      canvas,
      lens,
      _emptyLensRadius,
      inner: () {
        _paintEyes(canvas, lens, 1, look, eyeHeight);
        final mouth = _seg(t, 2.0, 2.3);
        if (mouth > 0) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 4, y + 6.5)
              ..quadraticBezierTo(x - 2, y + 4.8, x, y + 6.5)
              ..quadraticBezierTo(x + 2, y + 8.2, x + 4, y + 6.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..strokeCap = StrokeCap.round
              ..color = colorScheme.onSurfaceVariant.withValues(alpha: mouth),
          );
        }
      },
    );
    canvas.restore();

    final question = _back(_seg(t, 2.2, 2.6));
    if (question > 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: '?',
          style: (textStyle ?? const TextStyle()).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1,
            color: colorScheme.tertiary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final sway = t > 2.6 ? .12 * math.sin((t - 2.6) * math.pi) : 0.0;
      canvas
        ..save()
        ..translate(74, 22)
        ..rotate(sway)
        ..scale(question);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
      painter.dispose();
    }

    // 漫画式汗滴
    final sweat = _seg(t, 2.5, 2.9);
    if (sweat > 0) {
      final drop = Path()
        ..moveTo(-3, 1.8)
        ..lineTo(0, -5)
        ..lineTo(3, 1.8)
        ..arcTo(
          Rect.fromCircle(center: const Offset(0, 1.8), radius: 3),
          0,
          math.pi,
          false,
        )
        ..close();
      canvas
        ..save()
        ..translate(x - 22, y - 16 + Curves.easeOutCubic.transform(sweat) * 3)
        ..drawPath(
          drop,
          Paint()
            ..color = colorScheme.primaryContainer.withValues(alpha: sweat),
        )
        ..drawPath(
          drop,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .9
            ..color = colorScheme.primary.withValues(alpha: sweat),
        )
        ..restore();
    }
  }

  void _paintShelf(
    Canvas canvas,
    double lensX, {
    required bool magnified,
    double opacity = 1,
  }) {
    Color fade(Color color) => color.withValues(alpha: color.a * opacity);

    canvas.drawRRect(
      RRect.fromLTRBR(
        8,
        _shelfBase,
        92,
        _shelfBase + 4,
        const Radius.circular(2),
      ),
      Paint()
        ..color = fade(
          magnified ? colorScheme.outline : colorScheme.outlineVariant,
        ),
    );
    for (var i = 0; i < _books.length; i++) {
      final (x, w, h) = _books[i];
      // 放大镜经过的书脊微微抬起
      final distance = (lensX - (x + w / 2)).abs();
      final lift = math.max(0.0, 1 - distance / 13) * 4;
      final top = _shelfBase - h - lift;
      final body = magnified
          ? (i.isOdd
                ? colorScheme.tertiaryContainer
                : colorScheme.primaryContainer)
          : colorScheme.surfaceContainerHighest;
      final band = Paint()
        ..color = fade(
          magnified
              ? (i.isOdd ? colorScheme.tertiary : colorScheme.primary)
              : colorScheme.outlineVariant,
        );
      canvas
        ..drawRRect(
          RRect.fromLTRBR(
            x,
            top,
            x + w - 1.4,
            top + h,
            const Radius.circular(1.6),
          ),
          Paint()..color = fade(body),
        )
        ..drawRRect(
          RRect.fromLTRBR(
            x + 1.6,
            top + 6,
            x + w - 3,
            top + 9,
            const Radius.circular(1),
          ),
          band,
        )
        ..drawRRect(
          RRect.fromLTRBR(
            x + 1.6,
            top + h - 8,
            x + w - 3,
            top + h - 6,
            const Radius.circular(1),
          ),
          band,
        );
    }
  }

  void _paintLens(
    Canvas canvas,
    Offset center,
    double r, {
    required VoidCallback inner,
  }) {
    const handleAngle = math.pi / 4;
    final direction = Offset(math.cos(handleAngle), math.sin(handleAngle));
    canvas
      ..drawLine(
        center + direction * (r + 1),
        center + direction * (r * 2),
        Paint()
          ..strokeWidth = r * .36
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.primary,
      )
      ..drawCircle(center, r, Paint()..color = colorScheme.surfaceContainer)
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    inner();
    canvas
      ..restore()
      ..drawArc(
        Rect.fromCircle(center: center, radius: r * .72),
        math.pi * 1.1,
        math.pi * .35,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .1
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.primary.withValues(alpha: .35),
      )
      ..drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .22
          ..color = colorScheme.primary,
      );
  }

  void _paintEyes(
    Canvas canvas,
    Offset lens,
    double k,
    double look,
    double eyeHeight,
  ) {
    final paint = Paint()..color = colorScheme.onSurface;
    for (final dx in const [-5.2, 5.2]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(lens.dx + (dx + look * 3) * k, lens.dy - 1.5 * k),
          width: 4.4 * k,
          height: 2 * eyeHeight * k,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SearchLensPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.textStyle != textStyle ||
      oldDelegate.searchStart != searchStart ||
      oldDelegate.searchFadeIn != searchFadeIn ||
      oldDelegate.emptyStart != emptyStart ||
      oldDelegate.emptyFromSearch != emptyFromSearch;
}
