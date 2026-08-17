import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/features/home/view/home_scaffold_shell.dart';
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
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final downloadStatus = _FakeDownloadStatus();
    addTearDown(downloadStatus.dispose);

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
          onOpenSearch: () {},
          onFavoriteSortSelected: (_) {},
          onFavoriteCreateFolderPressed: () {},
          onFavoriteModeTogglePressed: () {},
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
  });
}
