import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/home/view/home_bottom_navigation.dart';
import 'package:hazuki/features/home/view/home_scaffold_shell.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  for (final width in [320.0, 360.0, 400.0, 800.0]) {
    testWidgets('glass navigation follows drawer foreground at width $width', (
      tester,
    ) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final drawer = AnimationController(vsync: tester);
      addTearDown(drawer.dispose);
      var foregroundBuilds = 0;
      const foregroundKey = ValueKey('foreground');

      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            home: HomeDrawerTransition(
              animation: drawer,
              child: Builder(
                builder: (context) {
                  foregroundBuilds++;
                  return const SizedBox.expand(key: foregroundKey);
                },
              ),
              navigationBuilder: (context, progress, viewportSize) =>
                  HomeNavigationDrawerLayout(
                    viewportWidth: viewportSize.width,
                    progress: progress,
                    child: HomeBottomNavigation(
                      currentIndex: 0,
                      onDestinationSelected: (_) {},
                      discoverLabel: 'Discover',
                      favoriteLabel: 'Favorites',
                      layoutScale: 1 - 0.035 * progress,
                    ),
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byKey(
        const ValueKey('home-bottom-navigation-glass-anchor'),
      );
      final initial = tester.getRect(bar);
      final scaffold = tester.widget<GlassScaffold>(find.byType(GlassScaffold));
      final initialBuilds = foregroundBuilds;

      // Check both directions, including widths where the trailing action
      // prevents the pill from being centered in the viewport.
      for (final next in [0.25, 0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0]) {
        drawer.value = next;
        await tester.pump(const Duration(milliseconds: 16));
        final progress = drawer.value;
        final scale = 1 - 0.035 * progress;
        final rect = tester.getRect(bar);
        expect(
          rect.left,
          closeTo(
            18 * progress + width * (1 - scale) + initial.left * scale,
            0.001,
          ),
          reason: 'drawer progress $progress',
        );
        expect(rect.width, closeTo(initial.width * scale, 0.001));
        expect(
          rect.top,
          closeTo(800 * (1 - scale) / 2 + initial.top * scale, 0.001),
        );
        final foreground = tester.getRect(find.byKey(foregroundKey));
        expect(
          foreground.left,
          closeTo(18 * progress + width * (1 - scale), 0.001),
        );
        expect(foreground.top, closeTo(800 * (1 - scale) / 2, 0.001));
        expect(foreground.width, closeTo(width * scale, 0.001));
        expect(foreground.height, closeTo(800 * scale, 0.001));
        expect(
          tester.widget<GlassScaffold>(find.byType(GlassScaffold)),
          same(scaffold),
          reason: 'drawer ticks must not rebuild the glass scaffold',
        );
        expect(foregroundBuilds, initialBuilds);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('fallback and desktop retain drawer geometry', (tester) async {
    await HazukiLiquidGlass.setEnabled(false);
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final drawer = AnimationController(vsync: tester);
    addTearDown(drawer.dispose);
    const foregroundKey = ValueKey('foreground');
    const navigationKey = ValueKey('navigation');

    for (final showNavigation in [true, false]) {
      var navigationBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeDrawerTransition(
            animation: drawer,
            showNavigation: showNavigation,
            child: const SizedBox.expand(key: foregroundKey),
            navigationBuilder: (context, progress, viewportSize) {
              navigationBuilds++;
              return const SizedBox(key: navigationKey, height: 70);
            },
          ),
        ),
      );
      for (final progress in [0.0, 0.5, 1.0, 0.5, 0.0]) {
        drawer.value = progress;
        await tester.pump(const Duration(milliseconds: 16));
        final scale = 1 - 0.035 * progress;
        final foreground = tester.getRect(find.byKey(foregroundKey));
        expect(
          foreground.left,
          closeTo(18 * progress + 360 * (1 - scale), 0.001),
        );
        expect(foreground.top, closeTo(800 * (1 - scale) / 2, 0.001));
        if (showNavigation) {
          final navigation = tester.getRect(find.byKey(navigationKey));
          expect(navigation.width, 360);
          expect(navigation.bottom, closeTo(800 * (1 + scale) / 2, 0.001));
        } else {
          expect(find.byKey(navigationKey), findsNothing);
          expect(navigationBuilds, 0);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
}
