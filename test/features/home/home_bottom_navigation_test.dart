import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/utils/draggable_indicator_physics.dart';

import 'package:hazuki/features/home/view/home_bottom_navigation.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

void main() {
  testWidgets('navigation accent follows theme changes while drawer scales', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    State? navigationState;
    for (final (brightness, seed) in [
      (Brightness.light, Colors.blue),
      (Brightness.dark, Colors.orange),
    ]) {
      final theme = ThemeData(colorSchemeSeed: seed, brightness: brightness);
      final expectedAccent = ColorScheme.fromSeed(
        seedColor: theme.colorScheme.primary,
        brightness: brightness,
      ).primary;
      for (final scale in [1.0, 0.98, 0.965]) {
        await tester.pumpWidget(
          HazukiLiquidGlass.wrap(
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                bottomNavigationBar: HomeBottomNavigation(
                  layoutScale: scale,
                  currentIndex: 0,
                  onDestinationSelected: _ignoreDestination,
                  discoverLabel: 'Discover',
                  favoriteLabel: 'Favorites',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        navigationState ??= tester.state(find.byType(HomeBottomNavigation));
        expect(
          tester.state(find.byType(HomeBottomNavigation)),
          same(navigationState),
        );
        final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        expect(bar.selectedIconColor, expectedAccent);
        expect(bar.selectedLabelColor, expectedAccent);
      }
    }
  });

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
      await HazukiLiquidGlass.setEnabled(false);
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

  for (final width in [320.0, 360.0, 800.0]) {
    for (final scale in [1.0, 0.8]) {
      testWidgets(
        'fallback matches glass dimensions at width $width and scale $scale',
        (tester) async {
          await tester.runAsync(HazukiLiquidGlass.initialize);
          await tester.binding.setSurfaceSize(Size(width, 760));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          addTearDown(() => HazukiLiquidGlass.setEnabled(true));
          var selectedIndex = 0;

          Widget buildNavigation() => HazukiLiquidGlass.wrap(
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: StatefulBuilder(
                  builder: (context, setState) => HomeBottomNavigation(
                    currentIndex: selectedIndex,
                    onDestinationSelected: (index) =>
                        setState(() => selectedIndex = index),
                    discoverLabel: 'Discover',
                    favoriteLabel: 'Favorites',
                    layoutScale: scale,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpWidget(buildNavigation());
          final glassBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
          final glassSize = Size(glassBar.tabWidth! * 2, glassBar.barHeight);

          await HazukiLiquidGlass.setEnabled(false);
          await tester.pumpWidget(buildNavigation());
          await tester.pumpAndSettle();

          final surface = find.byKey(
            const ValueKey('home-bottom-navigation-fallback-surface'),
          );
          void expectMatchingSize() {
            final size = tester.getRect(surface).size;
            expect(size.width, closeTo(glassSize.width, 0.001));
            expect(size.height, closeTo(glassSize.height, 0.001));
          }

          void expectCenteredLabel(String label, IconData icon) {
            final labelCenter = tester.getRect(find.text(label)).center.dy;
            expect(
              labelCenter,
              closeTo(tester.getRect(surface).center.dy, 0.001),
            );
            expect(
              labelCenter,
              closeTo(tester.getRect(find.byIcon(icon)).center.dy, 0.001),
            );
          }

          expect(find.byType(GlassTabBar), findsNothing);
          expectMatchingSize();
          expectCenteredLabel('Discover', Icons.explore);
          await tester.tap(find.byIcon(Icons.favorite_border));
          await tester.pumpAndSettle();
          expect(selectedIndex, 1);
          expectMatchingSize();
          expectCenteredLabel('Favorites', Icons.favorite);
          await tester.tap(find.byIcon(Icons.explore_outlined));
          await tester.pumpAndSettle();
          expect(selectedIndex, 0);
          expectMatchingSize();
          expectCenteredLabel('Discover', Icons.explore);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
    expect(tabBar.interactionBehavior, GlassInteractionBehavior.full);
    expect(tabBar.indicatorBorderRadius, GlassDefaults.capsuleRadius);
    expect(tabBar.barBorderRadius, GlassDefaults.capsuleRadius);
    expect(tabBar.settings?.thickness, 10);
    expect(tabBar.settings?.blur, 2);
    expect(
      tabBar.settings?.glassColor,
      ThemeData.dark().colorScheme.surfaceContainer.withValues(alpha: 0.16),
    );
    expect(tabBar.indicatorSettings?.refractiveIndex, 1.15);

    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    final anchorRect = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation-glass-anchor')),
    );
    final glassRect = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation-premium')),
    );
    expect(anchorRect.center.dx, closeTo(scaffoldRect.center.dx, 0.01));
    expect(anchorRect.bottom, closeTo(scaffoldRect.bottom, 0.01));
    expect(glassRect.left, closeTo(anchorRect.left, 0.01));
    expect(glassRect.top, closeTo(anchorRect.top, 0.01));

    tabBar.onTabSelected(1);
    expect(selectedIndex, 1);
  });

  testWidgets('back-to-top glass splits from the favorite destination', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    var backToTopPressed = false;
    var showBackToTop = true;
    late StateSetter setNavigationState;

    await tester.pumpWidget(
      HazukiLiquidGlass.wrap(
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                setNavigationState = setState;
                return HomeBottomNavigation(
                  currentIndex: 1,
                  onDestinationSelected: _ignoreDestination,
                  discoverLabel: 'Discover',
                  favoriteLabel: 'Favorites',
                  backToTopLabel: 'Back to top',
                  showBackToTop: showBackToTop,
                  onBackToTopPressed: () => backToTopPressed = true,
                );
              },
            ),
          ),
        ),
      ),
    );

    var tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    var button = tabBar.extraButton!;
    final glassButton = find.byWidgetPredicate(
      (widget) => widget is GlassButton && widget.label == 'Back to top',
    );
    ExcludeFocus focusGuard() => tester.widget<ExcludeFocus>(
      find.ancestor(of: glassButton, matching: find.byType(ExcludeFocus)).first,
    );
    ExcludeSemantics semanticsGuard() => tester.widget<ExcludeSemantics>(
      find
          .ancestor(of: glassButton, matching: find.byType(ExcludeSemantics))
          .first,
    );
    expect(button.transformScale, lessThan(1));
    expect(button.transformOffset.dx, lessThan(0));
    expect(button.ignorePointer, isTrue);
    expect(focusGuard().excluding, isTrue);
    expect(semanticsGuard().excluding, isTrue);

    await tester.pumpAndSettle();

    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    button = tabBar.extraButton!;
    expect(button.size, HomeBottomNavigation.floatingBarHeight);
    expect(button.transformScale, closeTo(1, 0.01));
    expect(button.transformOffset.dx, closeTo(0, 0.1));
    expect(button.ignorePointer, isFalse);
    expect(button.glowOpacity, 0);
    expect(focusGuard().excluding, isFalse);
    expect(semanticsGuard().excluding, isFalse);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('home-bottom-navigation-glass-anchor')),
          )
          .width,
      240,
    );

    button.onTap();
    expect(backToTopPressed, isTrue);

    final morphBuilder = tester.widget<AnimatedBuilder>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedBuilder &&
            widget.animation is GlassMorphController,
      ),
    );
    final morph = morphBuilder.animation as GlassMorphController;
    // Retain the pre-upgrade trajectory as well as the final hidden position.
    final closing = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 60, damping: 11.3),
      morph.value,
      0,
      -2.5,
    );
    setNavigationState(() => showBackToTop = false);
    await tester.pump();
    await tester.pump();
    for (var frame = 1; frame <= 4; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      final raw = closing.x(frame / 10);
      final clamped = raw.clamp(0.0, 1.0);
      final undershoot = raw < 0 ? raw : 0.0;
      final t = clamped - 1;
      final path = t * t * (3.5 * t + 2.5) + 1 + undershoot;
      final size = Curves.linearToEaseOut.transform(clamped) + undershoot;
      button = tester
          .widget<GlassTabBar>(find.byType(GlassTabBar))
          .extraButton!;
      expect(morph.value, closeTo(raw, 0.000001));
      expect(button.transformOffset.dx, closeTo(91 * path - 91, 0.000001));
      expect(button.transformScale, closeTo(size.clamp(0.0, 1.0), 0.000001));
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).blendAmount,
        closeTo(10 + ((path - size).abs() * 150).clamp(0.0, 28.0), 0.000001),
      );
    }
    await tester.pumpAndSettle();

    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    button = tabBar.extraButton!;
    expect(button.transformScale, closeTo(0, 0.01));
    expect(button.transformOffset.dx, closeTo(-91, 0.1));
    expect(button.ignorePointer, isTrue);
    expect(focusGuard().excluding, isTrue);
    expect(semanticsGuard().excluding, isTrue);
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

    final barRect = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation-glass-anchor')),
    );
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

  testWidgets(
    'liquid glass indicator stays on a newly selected held destination',
    (tester) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      var selectedIndex = 0;
      late StateSetter setNavigationState;

      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: StatefulBuilder(
                builder: (context, setState) {
                  setNavigationState = setState;
                  return HomeBottomNavigation(
                    currentIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      setNavigationState(() => selectedIndex = index);
                    },
                    discoverLabel: 'Discover',
                    favoriteLabel: 'Favorites',
                  );
                },
              ),
            ),
          ),
        ),
      );

      final barRect = tester.getRect(
        find.byKey(const ValueKey('home-bottom-navigation-glass-anchor')),
      );
      final favoriteCenter = Offset(
        barRect.left + barRect.width * 3 / 4,
        barRect.center.dy,
      );
      final gesture = await tester.startGesture(favoriteCenter);
      await tester.pump(const Duration(milliseconds: 150));
      expect(selectedIndex, 1);

      await gesture.moveBy(const Offset(1, 0));
      await tester.pump(const Duration(milliseconds: 100));

      final indicator = tester.widget<AnimatedGlassIndicator>(
        find.byType(AnimatedGlassIndicator).first,
      );
      final alignment = indicator.alignment.resolve(TextDirection.ltr);
      expect(alignment.x, greaterThan(0.5));

      await gesture.cancel();
    },
  );

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

    final barRect = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation-glass-anchor')),
    );
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

  for (final width in [320.0, 360.0]) {
    testWidgets('all floating controls remain tappable at width $width', (
      tester,
    ) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selectedIndex = 0;
      var backToTopPressed = false;

      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: StatefulBuilder(
                builder: (context, setState) => HomeBottomNavigation(
                  currentIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                  discoverLabel: 'Discover',
                  favoriteLabel: 'Favorites',
                  showBackToTop: true,
                  backToTopLabel: 'Back to top',
                  onBackToTopPressed: () => backToTopPressed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barRect = tester.getRect(find.byType(GlassTabBar));
      expect(barRect.left, greaterThanOrEqualTo(12));
      expect(barRect.right, lessThanOrEqualTo(width - 12));
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(selectedIndex, 1);
      await tester.tap(find.byIcon(Icons.vertical_align_top_rounded));
      expect(backToTopPressed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

void _ignoreDestination(int index) {}
