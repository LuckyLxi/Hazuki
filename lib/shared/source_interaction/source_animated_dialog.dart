import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';

Future<T?> showSourceAnimatedDialog<T>(
  BuildContext context, {
  required Widget child,
}) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    _SourceDialogRoute<T>(
      child: child,
      barrierLabel: l10n(context).dialogBarrierLabel,
      disableAnimations: disableAnimations,
    ),
  );
}

class _SourceDialogRoute<T> extends RawDialogRoute<T> {
  _SourceDialogRoute({
    required Widget child,
    required String barrierLabel,
    required bool disableAnimations,
  }) : _reverseDuration = disableAnimations
           ? Duration.zero
           : const Duration(milliseconds: 200),
       super(
         barrierLabel: barrierLabel,
         barrierColor: Colors.black45,
         transitionDuration: disableAnimations
             ? Duration.zero
             : const Duration(milliseconds: 280),
         pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
           child: Center(
             child: Material(type: MaterialType.transparency, child: child),
           ),
         ),
         transitionBuilder: (context, animation, secondaryAnimation, child) =>
             _SourceDialogTransition(animation: animation, child: child),
       );

  final Duration _reverseDuration;

  @override
  Duration get reverseTransitionDuration => _reverseDuration;
}

class _SourceDialogTransition extends StatefulWidget {
  const _SourceDialogTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_SourceDialogTransition> createState() =>
      _SourceDialogTransitionState();
}

class _SourceDialogTransitionState extends State<_SourceDialogTransition> {
  late CurvedAnimation _motion;
  late CurvedAnimation _opacity;

  void _createAnimations() {
    _motion = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _createAnimations();
  }

  @override
  void didUpdateWidget(_SourceDialogTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _motion.dispose();
      _opacity.dispose();
      _createAnimations();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _opacity,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8 * _opacity.value,
                sigmaY: 8 * _opacity.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(_motion),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(_motion),
              child: widget.child,
            ),
          ),
        ),
      ],
    ),
  );
}
