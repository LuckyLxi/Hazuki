import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/software_update/software_update_dialog_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/software_update/software_update_download_service.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/services/software_update/software_update_reminder_policy.dart';
import 'package:hazuki/services/software_update/software_update_reminder_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _check = SoftwareUpdateCheckResult(
  currentVersion: '1.0.0',
  latestVersion: '2.0.0',
  releaseUrl: 'https://example.com/releases/2',
  hasUpdate: true,
);
const _skipKey = 'update_skip';

void main() {
  late SoftwareUpdateDownloadService downloads;
  late SoftwareUpdateDialogPresenter presenter;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    downloads = SoftwareUpdateDownloadService();
    presenter = SoftwareUpdateDialogPresenter(
      downloadService: downloads,
      reminderPolicy: SoftwareUpdateReminderPolicy(
        now: () => DateTime(2026, 9, 10),
      ),
    );
  });
  tearDown(() => downloads.dispose());

  testWidgets('manual check bypasses a saved skip and records remind later', (
    tester,
  ) async {
    final saved = jsonEncode({
      'date': '2026-09-10',
      'currentVersion': _check.currentVersion,
      'latestVersion': _check.latestVersion,
    });
    SharedPreferences.setMockInitialValues({_skipKey: saved});
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(),
      ),
    );
    final strings = AppLocalizations.of(navigatorKey.currentContext!)!;
    final skipped = await presenter.showForCheck(
      navigatorKey: navigatorKey,
      isMounted: () => true,
      skipPrefsKey: _skipKey,
      check: _check,
    );
    expect(skipped, isNull);
    expect(find.text(strings.softwareUpdateAvailableTitle), findsNothing);

    final shown = presenter.showForCheck(
      navigatorKey: navigatorKey,
      isMounted: () => true,
      skipPrefsKey: _skipKey,
      check: _check,
      respectSkipPreference: false,
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.softwareUpdateAvailableTitle), findsOneWidget);
    await tester.tap(find.text(strings.comicDetailRemindLaterToday));
    await tester.pumpAndSettle();
    expect(await shown, SoftwareUpdateDialogAction.skipToday);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(_skipKey)!), jsonDecode(saved));
  });

  testWidgets('stops if owner leaves while preferences are being loaded', (
    tester,
  ) async {
    final pending = Completer<SoftwareUpdateReminder?>();
    final store = _ReminderStore()..pendingRead = pending.future;
    presenter = SoftwareUpdateDialogPresenter(
      downloadService: downloads,
      reminderStore: store,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(),
      ),
    );
    var mounted = true;
    final result = presenter.showForCheck(
      navigatorKey: navigatorKey,
      isMounted: () => mounted,
      skipPrefsKey: _skipKey,
      check: _check,
    );
    mounted = false;
    pending.complete(null);
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(navigatorKey.currentContext!)!;
    expect(find.text(strings.softwareUpdateAvailableTitle), findsNothing);
    expect(await result, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_skipKey), isFalse);
    expect(store.writes, isEmpty);
  });

  testWidgets('records the day of dismissal and cancellation does not write', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 10, 23, 59);
    final store = _ReminderStore();
    presenter = SoftwareUpdateDialogPresenter(
      downloadService: downloads,
      reminderStore: store,
      reminderPolicy: SoftwareUpdateReminderPolicy(now: () => now),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(),
      ),
    );
    final shown = presenter.showForCheck(
      navigatorKey: navigatorKey,
      isMounted: () => true,
      skipPrefsKey: _skipKey,
      check: _check,
    );
    await tester.pumpAndSettle();
    now = DateTime(2026, 9, 11);
    final strings = AppLocalizations.of(navigatorKey.currentContext!)!;
    await tester.tap(find.text(strings.comicDetailRemindLaterToday));
    await tester.pumpAndSettle();
    expect(await shown, SoftwareUpdateDialogAction.skipToday);
    expect(store.writes.single.$1, _skipKey);
    expect(store.writes.single.$2.date, '2026-09-11');

    final cancelled = presenter.showForCheck(
      navigatorKey: navigatorKey,
      isMounted: () => true,
      skipPrefsKey: _skipKey,
      check: _check,
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop(SoftwareUpdateDialogAction.cancel);
    await tester.pumpAndSettle();
    expect(await cancelled, SoftwareUpdateDialogAction.cancel);
    expect(store.writes, hasLength(1));
  });

  test(
    'startup checks use the injected checker and ignore late results',
    () async {
      final pending = Completer<SoftwareUpdateCheckResult?>();
      var calls = 0;
      var mounted = true;
      final support = SoftwareUpdateDialogSupport(
        downloadService: downloads,
        checkForUpdates: () {
          calls++;
          return pending.future;
        },
      );
      final result = support.showIfNeeded(
        isMounted: () => mounted,
        skipPrefsKey: _skipKey,
      );
      expect(calls, 1);
      mounted = false;
      pending.complete(_check);
      expect(await result, isNull);
    },
  );
}

class _ReminderStore implements SoftwareUpdateReminderStore {
  Future<SoftwareUpdateReminder?>? pendingRead;
  final writes = <(String, SoftwareUpdateReminder)>[];

  @override
  Future<SoftwareUpdateReminder?> read(String key) =>
      pendingRead ?? Future.value();

  @override
  Future<void> write(String key, SoftwareUpdateReminder reminder) async {
    writes.add((key, reminder));
  }
}
