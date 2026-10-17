import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/search_box_outline.dart';
import 'package:hazuki/features/home/view/home_scaffold_shell.dart';
import 'package:hazuki/features/home/view/home_drawer_snapshot.dart';
import 'package:hazuki/features/home/support/home_feature_contracts.dart';

class _FakeDownloadStatus extends ChangeNotifier
    implements HomeDownloadStatusListenable {
  @override
  bool get hasTasks => false;

  @override
  int get taskCount => 0;
}

void main() {
  test('navigation drawer offset matches the foreground transform', () {
    final offset = resolveHomeNavigationDrawerOffset(
      viewportSize: const Size(360, 800),
      progress: 1,
    );

    expect(offset.dx, closeTo(24.3, 0.001));
    expect(offset.dy, closeTo(-14, 0.001));
  });

  test('home pop request exits after confirmation', () async {
    var exitRequested = false;

    await handleHomePopRequest(
      onWillPop: () async => true,
      onExitRequested: () async {
        exitRequested = true;
      },
    );

    expect(exitRequested, isTrue);
  });

  test('home pop request stays on home before confirmation', () async {
    var exitRequested = false;

    await handleHomePopRequest(
      onWillPop: () async => false,
      onExitRequested: () async {
        exitRequested = true;
      },
    );

    expect(exitRequested, isFalse);
  });

  testWidgets('home scaffold builds from injected children and services', (
    tester,
  ) async {
    await tester.runAsync(() => HazukiLiquidGlass.initialize(enabled: false));
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final downloadStatus = _FakeDownloadStatus();
    addTearDown(downloadStatus.dispose);
    var searchOpenCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScaffoldShell(
          scaffoldKey: GlobalKey<ScaffoldState>(),
          currentIndex: 0,
          discoverSearchMorphProgress: 0,
          usePinnedDiscoverSearch: false,
          downloadStatus: downloadStatus,
          activeSourceKey: 'fake',
          supportsSourceAccount: false,
          discoverChild: const Text('discover child'),
          favoriteChild: const Text('favorite child'),
          favoriteAppBarActions: const FavoriteAppBarActionsState(
            showSort: false,
            showCreateFolder: false,
            currentSortOrder: 'mr',
            showModeToggle: false,
            currentMode: FavoritePageMode.cloud,
          ),
          showFavoriteBackToTop: false,
          isLogged: false,
          profileLoading: false,
          avatarUrl: '',
          username: 'guest',
          autoCheckInEnabled: false,
          showCheckInActions: false,
          checkInBusy: false,
          checkedInToday: false,
          onWillPop: () async => false,
          onExitRequested: () async {},
          onOpenSearch: () => searchOpenCount++,
          onFavoriteSortSelected: (_) {},
          onFavoriteCreateFolderPressed: () {},
          onFavoriteModeTogglePressed: () {},
          onFavoriteBackToTopPressed: () {},
          onProfileTap: null,
          onCheckInPressed: null,
          onSwitchSourcePressed: null,
          onOpenHistory: () {},
          onOpenCategories: () {},
          onOpenRanking: () {},
          onOpenDownloads: () {},
          onOpenDownloadTasks: () {},
          onOpenSettings: () {},
          onOpenLines: () {},
          onDestinationSelected: (_) {},
        ),
      ),
    );

    expect(find.text('discover child'), findsOneWidget);
    expect(find.text('favorite child'), findsOneWidget);
    // Body and header use disjoint rasters. Nesting a header snapshot inside
    // a page snapshot captures the same pixels twice on every drawer motion.
    final snapshots = find.byType(HomeDrawerSnapshot);
    expect(snapshots, findsNWidgets(2));
    for (final snapshot in snapshots.evaluate()) {
      expect(
        find.descendant(
          of: find.byWidget(snapshot.widget),
          matching: find.byType(HomeDrawerSnapshot),
        ),
        findsNothing,
      );
    }
    expect(
      find.byKey(const ValueKey('home-app-bar-repaint-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-discover-repaint-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-favorite-repaint-boundary')),
      findsOneWidget,
    );
    expect(
      tester.widget(
        find.byKey(const ValueKey('home-app-bar-repaint-boundary')),
      ),
      isA<RepaintBoundary>(),
    );

    final searchBox = find.byKey(const ValueKey('home-app-bar-search-box'));
    final glass = find.byKey(
      const ValueKey('home-search-liquid-glass-surface'),
    );
    final originalSize = tester.getSize(searchBox);
    final homeState = tester.state(find.byType(HomeScaffoldShell));
    expect(originalSize.height, 40);
    for (final (index, enabled) in [true, false, true, false].indexed) {
      await tester.runAsync(() => HazukiLiquidGlass.setEnabled(enabled));
      await tester.pumpAndSettle();
      expect(glass, enabled ? findsOneWidget : findsNothing);
      expect(tester.getSize(searchBox), originalSize);
      expect(tester.state(find.byType(HomeScaffoldShell)), same(homeState));
      final material = tester.widget<Material>(
        find.descendant(of: searchBox, matching: find.byType(Material)).first,
      );
      expect(
        material.color,
        enabled
            ? Colors.transparent
            : hazukiSearchBoxBackgroundColor(tester.element(searchBox)),
      );
      if (enabled) {
        final container = tester.widget<GlassContainer>(glass);
        expect(container.quality, HazukiLiquidGlass.navigationQuality);
        expect(
          container.settings,
          HazukiLiquidGlass.navigationSettings(tester.element(glass)),
        );
        expect(tester.getSize(glass), originalSize);
      }
      await tester.tap(
        find.descendant(of: searchBox, matching: find.byType(InkWell)),
      );
      expect(searchOpenCount, index + 1);
      expect(tester.testTextInput.isVisible, isFalse);
    }
    expect(searchOpenCount, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer scale stays fixed until the destination returns', (
    tester,
  ) async {
    final drawerController = AnimationController(vsync: tester, value: 1);
    final routeController = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(drawerController.dispose);
    addTearDown(routeController.dispose);

    holdHomeDrawerScaleUntilRouteReturns(
      routeAnimation: routeController,
      onRouteReturning: () => resetHomeDrawerScale(drawerController),
    );

    routeController.forward();

    expect(routeController.status, AnimationStatus.forward);
    expect(drawerController.value, 1);

    routeController.value = 1;

    expect(routeController.status, AnimationStatus.completed);
    expect(drawerController.value, 1);

    routeController.reverse();

    expect(routeController.status, AnimationStatus.reverse);
    expect(drawerController.value, 0);
    expect(drawerController.isAnimating, isFalse);
    routeController.stop();
  });
}
