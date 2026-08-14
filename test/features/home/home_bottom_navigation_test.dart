import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/home/view/home_bottom_navigation.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

void main() {
  testWidgets(
    'fallback scales with drawer layout and uses its own prompt height',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigation(
              currentIndex: 0,
              onDestinationSelected: _ignoreDestination,
              discoverLabel: 'Discover',
              favoriteLabel: 'Favorites',
              layoutScale: 0.8,
            ),
          ),
        ),
      );

      expect(find.byType(GlassTabBar), findsNothing);
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('home-bottom-navigation-fallback-scale')),
      );
      expect(transform.transform.storage[0], closeTo(0.8, 0.001));
      expect(transform.transform.storage[5], closeTo(0.8, 0.001));
      expect(
        hazukiPromptPlacementController.bottomPadding,
        HomeBottomNavigation.fallbackPromptBottomPadding,
      );
    },
  );

  testWidgets('uses liquid glass surface and preserves destination taps', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    var selectedIndex = 0;

    await tester.pumpWidget(
      HazukiLiquidGlass.wrap(
        child: MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigation(
              currentIndex: selectedIndex,
              onDestinationSelected: (index) => selectedIndex = index,
              discoverLabel: 'Discover',
              favoriteLabel: 'Favorites',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GlassTabBar), findsOneWidget);
    final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.tabWidth, 108);
    expect(
      tabBar.indicatorExpansion,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    expect(tabBar.interactionBehavior, GlassInteractionBehavior.scaleOnly);
    expect(tabBar.indicatorBorderRadius, 40);
    expect(tabBar.settings?.thickness, 30);
    expect(tabBar.settings?.blur, 3);
    expect(tabBar.settings?.glassColor.a, closeTo(0.08, 0.01));
    expect(tabBar.indicatorSettings, isNull);

    tabBar.onTabSelected(1);
    expect(selectedIndex, 1);
  });
}

void _ignoreDestination(int index) {}
