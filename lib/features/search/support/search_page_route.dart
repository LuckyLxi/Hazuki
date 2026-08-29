import 'package:flutter/cupertino.dart';

Route<T> buildSearchEntryPageRoute<T>({required WidgetBuilder builder}) {
  return _SnapshottingCupertinoPageRoute<T>(builder: builder);
}

class _SnapshottingCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _SnapshottingCupertinoPageRoute({required super.builder})
    : super(requestFocus: false);

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
      _TransitionSnapshot(animation: animation, child: child),
    );
  }
}

class _TransitionSnapshot extends StatefulWidget {
  const _TransitionSnapshot({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_TransitionSnapshot> createState() => _TransitionSnapshotState();
}

class _TransitionSnapshotState extends State<_TransitionSnapshot> {
  late final SnapshotController _controller = SnapshotController(
    allowSnapshotting: widget.animation.status.isAnimating,
  );

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(_TransitionSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) {
      return;
    }
    oldWidget.animation.removeStatusListener(_handleAnimationStatus);
    widget.animation.addStatusListener(_handleAnimationStatus);
    _controller.allowSnapshotting = widget.animation.status.isAnimating;
  }

  void _handleAnimationStatus(AnimationStatus status) {
    _controller.allowSnapshotting = status.isAnimating;
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      controller: _controller,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: widget.child,
    );
  }
}
