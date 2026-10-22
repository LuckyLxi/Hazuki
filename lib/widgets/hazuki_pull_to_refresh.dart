import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HazukiPullToRefresh extends StatefulWidget {
  const HazukiPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.refreshTriggerPullDistance = 104,
    this.maxContentOffset = 54,
    this.refreshHoldOffset = 50,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double refreshTriggerPullDistance;
  final double maxContentOffset;
  final double refreshHoldOffset;

  @override
  State<HazukiPullToRefresh> createState() => _HazukiPullToRefreshState();
}

class _HazukiPullToRefreshState extends State<HazukiPullToRefresh>
    with SingleTickerProviderStateMixin {
  double _pullDistance = 0;
  double _lastDragDeltaY = 0;
  bool _armed = false;
  bool _refreshing = false;
  bool _didHaptic = false;
  late final AnimationController _settleController;
  double _settleStartOffset = 0;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  double get _targetContentOffset {
    if (_refreshing) {
      return widget.refreshHoldOffset;
    }
    final eased = 1 - math.pow(0.68, _pullDistance / 22).toDouble();
    return (widget.maxContentOffset * eased).clamp(
      0.0,
      widget.maxContentOffset,
    );
  }

  double get _progress {
    return (_pullDistance / widget.refreshTriggerPullDistance).clamp(0.0, 1.0);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final metrics = notification.metrics;
    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        !_refreshing) {
      _lastDragDeltaY = 0;
      if (_settling) {
        setState(() => _settling = false);
      }
      _settleController.stop();
    }

    if (_refreshing) {
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        atTop) {
      _lastDragDeltaY = notification.dragDetails!.delta.dy;
      final overscroll = notification.overscroll;
      if (overscroll < 0) {
        _updatePullDistance(_pullDistance + overscroll.abs());
      } else if (overscroll > 0 && _pullDistance > 0) {
        _updatePullDistance(_pullDistance - overscroll.abs());
      }
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      if (_pullDistance > 0) {
        _lastDragDeltaY = notification.dragDetails!.delta.dy;
        _keepScrollAtTop(notification);
        if (_lastDragDeltaY < 0) {
          _updatePullDistance(_pullDistance - _lastDragDeltaY.abs());
        }
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final shouldRefresh = _armed && _lastDragDeltaY >= 0;
      _lastDragDeltaY = 0;
      if (shouldRefresh) {
        _startRefresh();
      } else if (_pullDistance > 0) {
        _resetPull();
      }
      return false;
    }

    return false;
  }

  void _keepScrollAtTop(ScrollNotification notification) {
    final notificationContext = notification.context;
    if (notificationContext == null) {
      return;
    }
    final position = Scrollable.maybeOf(notificationContext)?.position;
    if (position == null ||
        (position.pixels - position.minScrollExtent).abs() < 0.1) {
      return;
    }

    // Unlike jumpTo, correcting the pixels does not emit a scroll-end
    // notification. This keeps the active drag intact while the upward motion
    // is used to reduce the pull distance.
    position.correctPixels(position.minScrollExtent);
  }

  void _updatePullDistance(double next) {
    final clamped = next.clamp(0.0, widget.refreshTriggerPullDistance * 1.35);
    final wasArmed = _armed;
    final nextArmed = clamped >= widget.refreshTriggerPullDistance;

    if (nextArmed && !wasArmed && !_didHaptic) {
      _didHaptic = true;
      HapticFeedback.selectionClick();
    } else if (!nextArmed &&
        clamped < widget.refreshTriggerPullDistance * 0.72) {
      _didHaptic = false;
    }

    if ((_pullDistance - clamped).abs() < 0.1 && _armed == nextArmed) {
      return;
    }

    setState(() {
      _pullDistance = clamped;
      _armed = nextArmed;
    });
  }

  void _resetPull() {
    if (!mounted) {
      return;
    }
    final settleStartOffset = _targetContentOffset;
    setState(() {
      _pullDistance = 0;
      _armed = false;
      _didHaptic = false;
      _settling = true;
      _settleStartOffset = settleStartOffset;
    });
    _runSettleAnimation();
  }

  Future<void> _startRefresh() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
      _armed = false;
    });

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullDistance = 0;
          _didHaptic = false;
          _settling = true;
          _settleStartOffset = widget.refreshHoldOffset;
        });
        _runSettleAnimation();
      }
    }
  }

  void _runSettleAnimation() {
    _settleController.forward(from: 0).whenComplete(() {
      if (mounted && _settling) {
        setState(() => _settling = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settleController,
      child: widget.child,
      builder: (context, child) {
        final animatedOffset = _settling
            ? _settleStartOffset *
                  (1 - Curves.easeOutCubic.transform(_settleController.value))
            : _targetContentOffset;
        final indicatorExtent = math
            .max(animatedOffset, _refreshing ? widget.refreshHoldOffset : 0.0)
            .toDouble();
        final indicatorProgress = _progress > 0
            ? _progress
            : (widget.refreshHoldOffset > 0
                      ? (animatedOffset / widget.refreshHoldOffset).clamp(
                          0.0,
                          1.0,
                        )
                      : 0.0)
                  .toDouble();

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(0, animatedOffset),
                child: child,
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: indicatorExtent,
                child: IgnorePointer(
                  child: _HazukiPullToRefreshIndicator(
                    progress: indicatorProgress,
                    isArmed: _armed,
                    isRefreshing: _refreshing,
                    extent: indicatorExtent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 墨滴指示器：下拉时从顶部垂下一滴墨，颈部随拉动逐渐收细；越过触发点后
/// 颈部掐断、墨滴脱离；刷新中墨滴弹跳落地并荡开涟漪。
class _HazukiPullToRefreshIndicator extends StatefulWidget {
  const _HazukiPullToRefreshIndicator({
    required this.progress,
    required this.isArmed,
    required this.isRefreshing,
    required this.extent,
  });

  final double progress;
  final bool isArmed;
  final bool isRefreshing;
  final double extent;

  @override
  State<_HazukiPullToRefreshIndicator> createState() =>
      _HazukiPullToRefreshIndicatorState();
}

class _HazukiPullToRefreshIndicatorState
    extends State<_HazukiPullToRefreshIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _refreshController = AnimationController(
    vsync: this,
    duration: _InkDropPainter.refreshPeriod,
  );
  // 脱离动画按时间推进而非跟随手指，跨过触发点时形状不会瞬间跳变
  late final AnimationController _detachController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.isArmed ? 1 : 0,
  );
  late final Animation<double> _detach = CurvedAnimation(
    parent: _detachController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _syncRefreshAnimation();
  }

  @override
  void didUpdateWidget(_HazukiPullToRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing != widget.isRefreshing) {
      _syncRefreshAnimation();
    }
    if (oldWidget.isArmed != widget.isArmed && !widget.isRefreshing) {
      if (widget.isArmed) {
        _detachController.forward();
      } else {
        _detachController.reverse();
      }
    }
  }

  // 仅在刷新中驱动循环动画，下拉阶段完全由 progress 决定画面
  void _syncRefreshAnimation() {
    if (widget.isRefreshing) {
      _refreshController.repeat();
    } else {
      _refreshController
        ..stop()
        ..value = 0;
      _detachController.value = 0;
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _detachController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRefreshing && widget.progress <= 0 && widget.extent <= 0) {
      return const SizedBox.shrink();
    }

    // 墨滴从指示区域顶边垂下，不再预留顶部内边距，否则拉满时上半截会被裁掉
    return SizedBox.expand(
      child: ClipRect(
        child: Opacity(
          opacity: (widget.extent / 26).clamp(0.0, 1.0),
          child: CustomPaint(
            size: Size.infinite,
            painter: _InkDropPainter(
              progress: widget.progress,
              isRefreshing: widget.isRefreshing,
              refresh: _refreshController,
              detach: _detach,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InkDropPainter extends CustomPainter {
  _InkDropPainter({
    required this.progress,
    required this.isRefreshing,
    required this.refresh,
    required this.detach,
    required this.color,
  }) : super(repaint: Listenable.merge([refresh, detach]));

  static const refreshPeriod = Duration(milliseconds: 1200);
  // 墨滴中心距指示区域底边的距离
  static const _centerFromBottom = 27.0;

  final double progress;
  final bool isRefreshing;
  final Animation<double> refresh;
  final Animation<double> detach;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - _centerFromBottom;
    final fill = Paint()..color = color;

    if (isRefreshing) {
      _paintRefreshing(canvas, cx, cy, fill);
    } else {
      _paintPulling(canvas, cx, cy, fill);
    }
  }

  void _paintPulling(Canvas canvas, double cx, double cy, Paint fill) {
    final e = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final d = detach.value;
    final top = cy - 26;
    final r = 3 + 7 * e;
    final dropY = top + 6 + (cy - top - 2) * e;
    // 顶部附着处的半宽，脱离后即残墨的大小
    final base = 12 - 5 * e;
    // 颈部最细处：随下拉持续收细，脱离时收到 0 并断开成上下两段
    final neck = (5 - 3.8 * e) * (1 - d);
    final waistY = top + (dropY - r - top) * .55;
    final upperTip = waistY + (top + 3 - waistY) * d;
    final lowerTip = waistY + (dropY - r * 1.5 - waistY) * d;

    canvas.drawPath(
      Path()
        ..moveTo(cx - base, top - 2)
        ..quadraticBezierTo(cx - neck - 1, top + 2, cx - neck, upperTip)
        ..lineTo(cx + neck, upperTip)
        ..quadraticBezierTo(cx + neck + 1, top + 2, cx + base, top - 2)
        ..close(),
      fill,
    );

    // 下半段侧边控制点从内凹的颈部过渡到外凸的水滴形
    final ctrlDx = neck + (r * 1.1 - neck) * d;
    final ctrlY = dropY - r * (.9 - .3 * d);
    canvas.drawPath(
      Path()
        ..moveTo(cx - neck, lowerTip)
        ..quadraticBezierTo(cx - ctrlDx, ctrlY, cx - r, dropY)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, dropY), radius: r),
          math.pi,
          -math.pi,
          false,
        )
        ..quadraticBezierTo(cx + ctrlDx, ctrlY, cx + neck, lowerTip)
        ..close(),
      fill,
    );
  }

  void _paintRefreshing(Canvas canvas, double cx, double cy, Paint fill) {
    final seconds = refresh.value * refreshPeriod.inMilliseconds / 1000;
    final ground = cy + 9;

    // 两圈相位错开半个周期的涟漪
    for (var k = 0; k < 2; k++) {
      final f = (refresh.value + k * .5) % 1;
      final rx = 8 + f * 18;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, ground),
          width: rx * 2,
          height: rx * .64,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: color.a * (1 - f) * .55),
      );
    }

    // 弹跳：落地瞬间压扁，离地后恢复圆形
    const r = 8.0;
    final bounce = math.sin(seconds * math.pi / .6).abs();
    final squash = 1 - math.pow(1 - bounce, 6) * .35;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, ground - r * (2 - squash) * .5 - bounce * 10),
        width: r / squash * .95 * 2,
        height: r * squash * 2,
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(_InkDropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isRefreshing != isRefreshing ||
      oldDelegate.refresh != refresh ||
      oldDelegate.detach != detach ||
      oldDelegate.color != color;
}
