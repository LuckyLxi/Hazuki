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
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var progress = 0.0;
      late StateSetter setDrawerState;

      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                setDrawerState = setState;
                final offset = resolveHomeNavigationDrawerOffset(
                  viewportSize: Size(width, 800),
                  progress: progress,
                );
                return GlassScaffold(
                  enableBackgroundSampling: false,
                  topEdgeFade: false,
                  bottomEdgeFade: false,
                  contentAwareBrightness: false,
                  body: const SizedBox.expand(),
                  bottomBar: Padding(
                    padding: EdgeInsets.only(bottom: -offset.dy),
                    child: HomeNavigationDrawerLayout(
                      viewportWidth: width,
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
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byKey(
        const ValueKey('home-bottom-navigation-glass-anchor'),
      );
      final initial = tester.getRect(bar);

      // Check both directions, including widths where the trailing action
      // prevents the pill from being centered in the viewport.
      for (final next in [0.25, 0.5, 0.75, 1.0, 0.75, 0.5, 0.25, 0.0]) {
        setDrawerState(() => progress = next);
        await tester.pump(const Duration(milliseconds: 16));
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
        expect(tester.takeException(), isNull);
      }
    });
  }
}
