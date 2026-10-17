import 'package:flutter/cupertino.dart';
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
    final routeAnimation =
        secondaryAnimation ?? ModalRoute.of(context)?.secondaryAnimation;
    return ListenableBuilder(
      listenable: HazukiLiquidGlass.changes,
      child: child,
      builder: (context, child) => _TransitionSnapshot(
        animation: animation ?? kAlwaysDismissedAnimation,
        secondaryAnimation: HazukiLiquidGlass.isAvailable
            ? routeAnimation ?? kAlwaysDismissedAnimation
            : kAlwaysDismissedAnimation,
        child: child!,
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
  bool _snapshotScheduled = false;

  bool get _isAnimating =>
      widget.animation.status.isAnimating ||
      widget.secondaryAnimation.status.isAnimating;

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
    if (!_isAnimating) {
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
      if (mounted) _controller.allowSnapshotting = _isAnimating;
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
    return GlassSnapshot(
      controller: _controller,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: widget.child,
    );
  }
}
