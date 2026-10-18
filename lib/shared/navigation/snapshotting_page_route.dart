import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../liquid_glass_support.dart';

Route<T> buildSnapshottingPageRoute<T>({
  required WidgetBuilder builder,
  bool allowSnapshotting = true,
  bool skipEntrance = false,
}) {
  return _SnapshottingCupertinoPageRoute<T>(
    builder: builder,
    allowSnapshotting: allowSnapshotting,
    skipEntrance: skipEntrance,
  );
}

class _SnapshottingCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _SnapshottingCupertinoPageRoute({
    required super.builder,
    required super.allowSnapshotting,
    required this.skipEntrance,
  }) : super(requestFocus: false);

  final bool skipEntrance;

  @override
  AnimationController createAnimationController() {
    final controller = super.createAnimationController();
    if (skipEntrance) controller.value = 1;
    return controller;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      RouteTransitionSnapshot(
        animation: allowSnapshotting ? animation : null,
        secondaryAnimation: secondaryAnimation,
        child: child,
      ),
    );
  }
}

/// Caches a glass page while another route slides over or away from it.
///
/// Also used by the home route, which is created by MaterialApp rather than
/// [buildSnapshottingPageRoute]. Only an explicitly supplied [animation] caches
/// this page's own entrance/exit, so detail background reveals stay live.
class RouteTransitionSnapshot extends StatelessWidget {
  const RouteTransitionSnapshot({
    super.key,
    this.animation,
    this.secondaryAnimation,
    required this.child,
  });

  final Animation<double>? animation;
  final Animation<double>? secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final primaryAnimation =
        animation ?? route?.animation ?? kAlwaysDismissedAnimation;
    final routeAnimation =
        secondaryAnimation ??
        route?.secondaryAnimation ??
        kAlwaysDismissedAnimation;
    return AnimatedBuilder(
      animation: Listenable.merge([primaryAnimation, routeAnimation]),
      builder: (context, child) => AbsorbPointer(
        // Keep Hero endpoints and cached pages aligned until both routes settle.
        // Use the real route animations even when snapshotting is disabled.
        absorbing:
            primaryAnimation.status.isAnimating ||
            routeAnimation.status.isAnimating,
        child: child,
      ),
      child: ListenableBuilder(
        listenable: HazukiLiquidGlass.changes,
        child: child,
        builder: (context, child) => _TransitionSnapshot(
          animation: animation ?? kAlwaysDismissedAnimation,
          secondaryAnimation: HazukiLiquidGlass.isAvailable
              ? routeAnimation
              : kAlwaysDismissedAnimation,
          child: child!,
        ),
      ),
    );
  }
}

class _TransitionSnapshot extends StatefulWidget {
  const _TransitionSnapshot({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_TransitionSnapshot> createState() => _TransitionSnapshotState();
}

class _TransitionSnapshotState extends State<_TransitionSnapshot> {
  final SnapshotController _controller = SnapshotController();
  final _scrolling = <ScrollPosition>{};
  bool _snapshotScheduled = false;

  bool get _isAnimating =>
      widget.animation.status.isAnimating ||
      widget.secondaryAnimation.status.isAnimating;

  bool get _shouldCache => _isAnimating && !_hasVisibleScrollingContent;

  bool get _hasVisibleScrollingContent {
    _scrolling.removeWhere(
      (position) =>
          position.context.notificationContext?.mounted != true ||
          !position.isScrollingNotifier.value,
    );
    return _scrolling.any((position) {
      RenderObject? node = position.context.notificationContext
          ?.findRenderObject();
      while (node != null) {
        // Hidden home tabs must not prevent caching the visible page.
        if (node is RenderOffstage && node.offstage ||
            node is RenderOpacity && node.opacity == 0 ||
            node is RenderAnimatedOpacity &&
                node.opacity.value == 0 &&
                !node.opacity.status.isAnimating) {
          return false;
        }
        node = node.parent;
      }
      return true;
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (_scrolling.isNotEmpty) _updateSnapshotting();
      return false;
    }
    if (notification is! ScrollStartNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final notificationContext = notification.context;
    if (notificationContext == null) return false;
    final position = Scrollable.maybeOf(notificationContext)?.position;
    if (position == null) return false;
    if (notification is ScrollStartNotification) {
      _scrolling.add(position);
    } else {
      _scrolling.remove(position);
    }
    // Autoplay can begin after capture. Release before its first moving frame
    // so the carousel remains visible instead of jumping when the route settles.
    _updateSnapshotting();
    return false;
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleAnimationStatus);
    widget.secondaryAnimation.addStatusListener(_handleAnimationStatus);
    _updateSnapshotting();
  }

  @override
  void didUpdateWidget(_TransitionSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_handleAnimationStatus);
      widget.animation.addStatusListener(_handleAnimationStatus);
    }
    if (oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      oldWidget.secondaryAnimation.removeStatusListener(_handleAnimationStatus);
      widget.secondaryAnimation.addStatusListener(_handleAnimationStatus);
    }
    _updateSnapshotting();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    _updateSnapshotting();
  }

  void _updateSnapshotting() {
    if (!_shouldCache) {
      _controller.allowSnapshotting = false;
      return;
    }
    if (_controller.allowSnapshotting || _snapshotScheduled) return;

    // HeroController starts flights after the first frame and rebuilds the
    // in-page Heroes as hidden placeholders in the next frame. Capture only
    // after that rebuild so the raster cannot retain the original Heroes.
    _snapshotScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotScheduled = false;
      if (mounted) _controller.allowSnapshotting = _shouldCache;
    });
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    widget.secondaryAnimation.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: GlassSnapshot(
        controller: _controller,
        mode: SnapshotMode.permissive,
        autoresize: true,
        child: widget.child,
      ),
    );
  }
}
