part of 'home_scaffold_shell.dart';

@visibleForTesting
Future<void> handleHomePopRequest({
  required Future<bool> Function() onWillPop,
  required Future<void> Function() onExitRequested,
}) async {
  if (await onWillPop()) {
    await onExitRequested();
  }
}

@visibleForTesting
Offset resolveHomeNavigationDrawerOffset({
  required Size viewportSize,
  required double progress,
}) {
  final scale = 1 - 0.035 * progress;
  return Offset(
    18 * progress + (1 - scale) * viewportSize.width / 2,
    -(1 - scale) * viewportSize.height / 2,
  );
}

class HomeNavigationDrawerLayout extends StatelessWidget {
  const HomeNavigationDrawerLayout({
    super.key,
    required this.viewportWidth,
    required this.progress,
    required this.child,
  });

  final double viewportWidth;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = 1 - 0.035 * progress;
    final scaledWidth = viewportWidth * scale;
    return Padding(
      padding: EdgeInsets.only(
        left: 18 * progress + viewportWidth * (1 - scale),
      ),
      // Scale the entire layout width with the foreground. Reducing it by
      // the translation instead makes the glass bar recalculate its action
      // reservation and shift independently on narrow screens. Use layout
      // coordinates so the glass shader samples without a paint transform.
      child: OverflowBox(
        alignment: Alignment.bottomLeft,
        fit: OverflowBoxFit.deferToChild,
        minWidth: scaledWidth,
        maxWidth: scaledWidth,
        child: child,
      ),
    );
  }
}

@visibleForTesting
void resetHomeDrawerScale(AnimationController controller) {
  controller.value = 0;
}

/// Keeps the glass scaffold stable while only the foreground transform and
/// navigation layout follow the drawer. Rebuilding the scaffold every tick
/// also rebuilds its glass scopes and background infrastructure.
class HomeDrawerTransition extends StatelessWidget {
  const HomeDrawerTransition({
    super.key,
    required this.animation,
    required this.child,
    required this.navigationBuilder,
    this.showNavigation = true,
  });

  final Animation<double> animation;
  final Widget child;
  final Widget Function(BuildContext, double, Size) navigationBuilder;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    final foreground = AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(18 * animation.value, 0),
        child: Transform.scale(
          scale: 1 - 0.035 * animation.value,
          alignment: Alignment.centerRight,
          child: child,
        ),
      ),
    );
    if (!showNavigation) return foreground;

    return ListenableBuilder(
      listenable: HazukiLiquidGlass.changes,
      child: foreground,
      builder: (context, foreground) => LayoutBuilder(
        builder: (context, constraints) {
          final glass = HazukiLiquidGlass.isAvailable;
          final navigation = AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final progress = animation.value;
              final offset = resolveHomeNavigationDrawerOffset(
                viewportSize: constraints.biggest,
                progress: progress,
              );
              final content = navigationBuilder(
                context,
                progress,
                constraints.biggest,
              );
              if (glass) {
                return Padding(
                  padding: EdgeInsets.only(bottom: -offset.dy),
                  child: content,
                );
              }
              return Positioned(
                left: 0,
                right: 0,
                bottom: -offset.dy,
                child: content,
              );
            },
          );
          if (glass) {
            return GlassScaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              enableBackgroundSampling: false,
              resizeToAvoidBottomInset: false,
              topEdgeFade: false,
              bottomEdgeFade: false,
              contentAwareBrightness: false,
              bottomBarHeight:
                  HomeBottomNavigation.floatingBarHeight +
                  HomeBottomNavigation.floatingVerticalPadding * 2,
              body: foreground!,
              bottomBar: navigation,
            );
          }
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [foreground!, navigation],
          );
        },
      ),
    );
  }
}

@visibleForTesting
VoidCallback holdHomeDrawerScaleUntilRouteReturns({
  required Animation<double> routeAnimation,
  required VoidCallback onRouteReturning,
}) {
  var listening = true;
  late final AnimationStatusListener listener;

  void stopListening() {
    if (!listening) {
      return;
    }
    listening = false;
    routeAnimation.removeStatusListener(listener);
  }

  listener = (status) {
    if (status != AnimationStatus.reverse &&
        status != AnimationStatus.dismissed) {
      return;
    }
    stopListening();
    onRouteReturning();
  };
  routeAnimation.addStatusListener(listener);
  return stopListening;
}
