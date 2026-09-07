import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';

const _profile = HomeSidebarProfileState(
  isLogged: false,
  profileLoading: false,
  avatarUrl: '',
  username: 'guest',
  autoCheckInEnabled: false,
  showCheckInActions: false,
  checkInBusy: false,
  checkedInToday: false,
);

const _checkInProfile = HomeSidebarProfileState(
  isLogged: true,
  profileLoading: false,
  avatarUrl: '',
  username: 'reader',
  autoCheckInEnabled: false,
  showCheckInActions: true,
  checkInBusy: false,
  checkedInToday: false,
);

void main() {
  testWidgets('drawer menu preserves destination selection and actions', (
    tester,
  ) async {
    var historyOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Drawer(
            child: HomeDrawerContent(
              profile: _profile,
              actions: HomeSidebarActions(
                onOpenHistory: () => historyOpened = true,
              ),
              activeSourceKey: 'test',
              selectedDestination: HomeDrawerDestination.history,
            ),
          ),
        ),
      ),
    );

    final historyTile = find.ancestor(
      of: find.byIcon(Icons.history_outlined),
      matching: find.byType(ListTile),
    );

    expect(historyTile, findsOneWidget);
    expect(tester.widget<ListTile>(historyTile).selected, isTrue);

    await tester.tap(historyTile);

    expect(historyOpened, isTrue);
  });

  testWidgets('drawer menu keeps all configured destinations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Drawer(
            child: HomeDrawerContent(
              profile: _profile,
              actions: HomeSidebarActions(),
              activeSourceKey: 'test',
            ),
          ),
        ),
      ),
    );

    for (final item in [
      ...homeSidebarPrimaryItems,
      ...homeSidebarSecondaryItems,
    ]) {
      expect(find.byIcon(item.icon), findsOneWidget);
    }
  });

  testWidgets('drawer menu shows the announcement unread badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Drawer(
            child: HomeDrawerContent(
              profile: _profile,
              actions: HomeSidebarActions(),
              activeSourceKey: 'test',
              unreadAnnouncementCount: 3,
            ),
          ),
        ),
      ),
    );

    final announcementTile = find.ancestor(
      of: find.byIcon(Icons.notifications_none_rounded),
      matching: find.byType(ListTile),
    );

    expect(announcementTile, findsOneWidget);
    expect(
      find.descendant(of: announcementTile, matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('profile header preserves check-in transition settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Drawer(
            child: HomeDrawerContent(
              profile: _checkInProfile,
              actions: HomeSidebarActions(),
              activeSourceKey: 'test',
            ),
          ),
        ),
      ),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );

    expect(switcher.duration, const Duration(milliseconds: 260));
    expect(switcher.switchInCurve, Curves.easeOutBack);
    expect(switcher.switchOutCurve, Curves.easeInCubic);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    final snapshot = tester.widget<SnapshotWidget>(find.byType(SnapshotWidget));
    expect(snapshot.autoresize, isTrue);
    expect(
      find.ancestor(
        of: find.byType(Hero),
        matching: find.byType(SnapshotWidget),
      ),
      findsNothing,
    );
  });
}
