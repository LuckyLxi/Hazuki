import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HazukiPullToRefresh extends StatefulWidget {
  const HazukiPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
    this.refreshTriggerPullDistance = 104,
    this.maxContentOffset = 54,
    this.refreshHoldOffset = 50,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;
  final double refreshTriggerPullDistance;
  final double maxContentOffset;
  final double refreshHoldOffset;

  @override
  State<HazukiPullToRefresh> createState() => _HazukiPullToRefreshState();
}

class _HazukiPullToRefreshState extends State<HazukiPullToRefresh> {
  double _pullDistance = 0;
  double _lastDragDeltaY = 0;
  bool _dragging = false;
  bool _armed = false;
  bool _refreshing = false;
  bool _didHaptic = false;

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
      _dragging = true;
      _lastDragDeltaY = 0;
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
        _pinScrollToTop(notification);
        if (_lastDragDeltaY < 0) {
          _updatePullDistance(_pullDistance - _lastDragDeltaY.abs());
        }
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      _dragging = false;
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

  void _pinScrollToTop(ScrollNotification notification) {
    final notificationContext = notification.context;
    if (notificationContext == null) {
      return;
    }
    final scrollable = Scrollable.maybeOf(notificationContext);
    final position = scrollable?.position;
    if (position == null) {
      return;
    }
    if ((position.pixels - position.minScrollExtent).abs() < 0.1) {
      return;
    }
    position.jumpTo(position.minScrollExtent);
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
    setState(() {
      _pullDistance = 0;
      _armed = false;
      _didHaptic = false;
    });
  }

  Future<void> _startRefresh() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
      _dragging = false;
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _targetContentOffset),
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedOffset, child) {
        final indicatorExtent = math
            .max(animatedOffset, _refreshing ? widget.refreshHoldOffset : 0.0)
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
                    progress: _progress,
                    isRefreshing: _refreshing,
                    extent: indicatorExtent,
                    topInset: widget.edgeOffset,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _HazukiPullToRefreshIndicator extends StatelessWidget {
  const _HazukiPullToRefreshIndicator({
    required this.progress,
    required this.isRefreshing,
    required this.extent,
    required this.topInset,
  });

  final double progress;
  final bool isRefreshing;
  final double extent;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    if (!isRefreshing && progress <= 0 && extent <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final reveal = isRefreshing ? 1.0 : Curves.easeOutCubic.transform(progress);
    final opacity = isRefreshing ? 1.0 : reveal;
    final capsuleSize = 24 + (24 * reveal);
    final spinnerSize = 12 + (16 * reveal);
    final effectiveTopInset = math.min(topInset, extent * 0.4).toDouble();
    final bottomPadding = math
        .min(12.0, math.max(0.0, extent - capsuleSize))
        .toDouble();
    final indicatorValue = isRefreshing
        ? null
        : math.max(progress, 0.08).toDouble();

    return ClipRect(
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              top: effectiveTopInset,
              bottom: bottomPadding,
            ),
            child: Opacity(
              opacity: opacity,
              child: SizedBox(
                width: capsuleSize,
                height: capsuleSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: spinnerSize,
                      height: spinnerSize,
                      child: RefreshProgressIndicator(
                        value: indicatorValue,
                        strokeWidth: 2.6,
                        color: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
