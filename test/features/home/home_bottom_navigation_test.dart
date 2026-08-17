import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/utils/draggable_indicator_physics.dart';

import 'package:hazuki/features/home/view/home_bottom_navigation.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

void main() {
  test('indicator drag starts from its selected position without jumping', () {
    expect(
      DraggableIndicatorPhysics.getAlignmentFromDragDelta(
        startAlignment: -1,
        delta: 0,
        extent: 240,
        itemCount: 2,
      ),
      -1,
    );
    expect(
      DraggableIndicatorPhysics.getAlignmentFromDragDelta(
        startAlignment: -1,
        delta: 12,
        extent: 240,
        itemCount: 2,
      ),
      closeTo(-0.8, 0.001),
    );
  });

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
        tester.widget<Text>(find.text('Discover')).style?.decoration,
        TextDecoration.none,
      );
      expect(
        tester.widget<Text>(find.text('Favorites')).style?.decoration,
        TextDecoration.none,
      );
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
    expect(tabBar.barHeight, HomeBottomNavigation.floatingBarHeight);
    expect(
      tabBar.verticalPadding,
      HomeBottomNavigation.floatingVerticalPadding,
    );
    expect(
      hazukiPromptPlacementController.bottomPadding,
      HomeBottomNavigation.floatingBarHeight +
          HomeBottomNavigation.floatingVerticalPadding * 2 +
          HomeBottomNavigation.promptGap,
    );
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

  testWidgets('liquid glass indicator preserves its off-center press offset', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);

    await tester.pumpWidget(
      HazukiLiquidGlass.wrap(
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigation(
              currentIndex: 0,
              onDestinationSelected: _ignoreDestination,
              discoverLabel: 'Discover',
              favoriteLabel: 'Favorites',
            ),
          ),
        ),
      ),
    );

    final barRect = tester.getRect(find.byType(GlassTabBar));
    final selectedCenter = Offset(
      barRect.left + barRect.width / 4,
      barRect.center.dy,
    );
    final gesture = await tester.startGesture(
      selectedCenter + const Offset(20, 0),
    );
    await gesture.moveBy(const Offset(4, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    var indicator = tester.widget<AnimatedGlassIndicator>(
      find.byType(AnimatedGlassIndicator).first,
    );
    var alignment = indicator.alignment.resolve(TextDirection.ltr);
    expect(alignment.x, greaterThan(-1));
    final firstMoveAlignment = alignment.x;

    await gesture.moveBy(const Offset(16, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    indicator = tester.widget<AnimatedGlassIndicator>(
      find.byType(AnimatedGlassIndicator).first,
    );
    alignment = indicator.alignment.resolve(TextDirection.ltr);
    expect(alignment.x, greaterThan(firstMoveAlignment));

    await gesture.cancel();
  });

  testWidgets('liquid glass indicator follows physical drag direction in RTL', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);

    await tester.pumpWidget(
      HazukiLiquidGlass.wrap(
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: HomeBottomNavigation(
                currentIndex: 0,
                onDestinationSelected: _ignoreDestination,
                discoverLabel: 'Discover',
                favoriteLabel: 'Favorites',
              ),
            ),
          ),
        ),
      ),
    );

    final barRect = tester.getRect(find.byType(GlassTabBar));
    final selectedCenter = Offset(
      barRect.left + barRect.width * 3 / 4,
      barRect.center.dy,
    );
    final gesture = await tester.startGesture(selectedCenter);
    await gesture.moveBy(const Offset(-12, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final indicator = tester.widget<AnimatedGlassIndicator>(
      find.byType(AnimatedGlassIndicator).first,
    );
    final alignment = indicator.alignment.resolve(TextDirection.rtl);
    expect(alignment.x, lessThan(1));

    await gesture.cancel();
  });
}

void _ignoreDestination(int index) {}
