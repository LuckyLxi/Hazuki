import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

Future<T?> showHomeAnimatedDialog<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
  bool useGlassTransition = false,
}) {
  final clearGlass = useGlassTransition && HazukiLiquidGlass.isAvailable;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: l10n(context).dialogBarrierLabel,
    barrierColor: clearGlass
        ? Colors.black.withValues(alpha: 0.18)
        : Colors.black45,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
    },
    transitionBuilder:
        (buildContext, animation, secondaryAnimation, dialogChild) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final progress = curved.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop filters must read the page directly, without an
              // ancestor opacity layer isolating them during the transition.
              IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: (clearGlass ? 1.2 : 8) * progress,
                      sigmaY: (clearGlass ? 1.2 : 8) * progress,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
                child: useGlassTransition
                    ? HomeDialogGlassProgress(
                        progress: progress,
                        child: dialogChild,
                      )
                    : FadeTransition(opacity: curved, child: dialogChild),
              ),
            ],
          );
        },
  );
}

class HomeDialogGlassProgress extends InheritedWidget {
  const HomeDialogGlassProgress({
    super.key,
    required this.progress,
    required super.child,
  });

  final double progress;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomeDialogGlassProgress>()
          ?.progress ??
      1;

  @override
  bool updateShouldNotify(HomeDialogGlassProgress oldWidget) =>
      progress != oldWidget.progress;
}

Color homeDialogBackgroundColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final brightness = ThemeData.estimateBrightnessForColor(colorScheme.surface);
  return brightness == Brightness.dark
      ? colorScheme.surfaceContainerLow
      : colorScheme.surfaceContainerHigh;
}
