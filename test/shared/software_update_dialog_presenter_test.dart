import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/software_update/software_update_dialog_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/software_update/software_update_download_service.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _check = SoftwareUpdateCheckResult(
  currentVersion: '1.0.0',
  latestVersion: '2.0.0',
  releaseUrl: 'https://example.com/releases/2',
  hasUpdate: true,
);
const _skipKey = 'update_skip';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  late SoftwareUpdateDownloadService downloads;
  late SoftwareUpdateDialogPresenter presenter;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    downloads = SoftwareUpdateDownloadService();
    presenter = SoftwareUpdateDialogPresenter(downloadService: downloads);
  });
  tearDown(() => downloads.dispose());

  testWidgets('manual check bypasses a saved skip and records remind later', (
    tester,
  ) async {
    final saved = jsonEncode({
      'date': _today(),
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
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(navigatorKey.currentContext!)!;
    expect(find.text(strings.softwareUpdateAvailableTitle), findsNothing);
    expect(await result, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_skipKey), isFalse);
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
