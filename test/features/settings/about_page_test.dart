import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/about_page.dart';
import 'package:hazuki/features/settings/view/about_page_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/shared/software_update/software_update_dialog_presenter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockUpdates extends Mock implements SoftwareUpdateService {}

class _MockUpdateDialog extends Mock implements SoftwareUpdateDialogPresenter {}

Widget _app(
  Widget page, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: brightness,
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: page,
);

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200);
  await tester.pumpAndSettle();
}

void main() {
  late _MockUpdates updates;
  late _MockUpdateDialog dialog;

  setUpAll(() => registerFallbackValue(() => true));
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Hazuki',
      packageName: 'com.example.hazuki',
      version: '1.1.9',
      buildNumber: '20',
      buildSignature: '',
    );
    updates = _MockUpdates();
    dialog = _MockUpdateDialog();
  });

  Widget page() =>
      AboutPage(softwareUpdateService: updates, softwareUpdateDialog: dialog);

  for (final scenario in [
    (width: 320.0, scale: 1.0, locale: 'en', brightness: Brightness.light),
    (width: 320.0, scale: 2.0, locale: 'en', brightness: Brightness.dark),
    (width: 390.0, scale: 2.0, locale: 'zh', brightness: Brightness.light),
    (width: 1280.0, scale: 1.0, locale: 'zh', brightness: Brightness.dark),
  ]) {
    testWidgets(
      'about fits ${scenario.width}px, ${scenario.scale}x text, ${scenario.locale}, ${scenario.brightness.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scenario.width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          _app(
            page(),
            locale: Locale(scenario.locale),
            brightness: scenario.brightness,
            textScale: scenario.scale,
          ),
        );
        await tester.pumpAndSettle();
        final strings = AppLocalizations.of(
          tester.element(find.byType(AboutPage)),
        )!;
        expect(find.text(strings.aboutVersion('1.1.9')), findsOneWidget);
        expect(find.text('GPL-3.0'), findsOneWidget);
        expect(find.byType(FlutterLogo), findsNothing);
        expect(tester.takeException(), isNull);

        for (final label in [
          strings.aboutProjectTitle,
          strings.aboutFeedbackTitle,
          strings.aboutDisclaimerTitle,
          strings.aboutThirdPartyLicensesTitle,
        ]) {
          await _scrollTo(tester, find.text(label));
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        verifyNever(updates.checkForUpdates);
      },
    );
  }

  testWidgets('disclaimer opens, closes, and licenses show the real version', (
    tester,
  ) async {
    await tester.pumpWidget(_app(page()));
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(
      tester.element(find.byType(AboutPage)),
    )!;
    await _scrollTo(tester, find.text(strings.aboutDisclaimerTitle));
    await tester.tap(find.text(strings.aboutDisclaimerTitle));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(strings.aboutDisclaimerContent), findsOneWidget);
    await tester.tap(find.text(strings.commonClose));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await _scrollTo(tester, find.text(strings.aboutThirdPartyLicensesTitle));
    await tester.tap(find.text(strings.aboutThirdPartyLicensesTitle));
    await tester.pumpAndSettle();
    final licensePage = tester.widget<LicensePage>(find.byType(LicensePage));
    expect(licensePage.applicationName, 'Hazuki');
    expect(licensePage.applicationVersion, '1.1.9');
    expect(find.byType(FlutterLogo), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('update button prevents duplicate checks and opens the update', (
    tester,
  ) async {
    const check = SoftwareUpdateCheckResult(
      currentVersion: '1.1.9',
      latestVersion: '1.2.0',
      releaseUrl: 'https://example.com/releases/1.2.0',
      hasUpdate: true,
    );
    final pending = Completer<SoftwareUpdateCheckResult?>();
    when(updates.checkForUpdates).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_app(page()));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AboutPage));
    when(
      () => dialog.showForCheck(
        dialogContext: context,
        isMounted: any(named: 'isMounted'),
        skipPrefsKey: 'software_update_skip_date',
        check: check,
        respectSkipPreference: false,
      ),
    ).thenAnswer((_) async => null);
    final button = find.byType(FilledButton);
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(button);
    verify(updates.checkForUpdates).called(1);

    pending.complete(check);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    verify(
      () => dialog.showForCheck(
        dialogContext: context,
        isMounted: any(named: 'isMounted'),
        skipPrefsKey: 'software_update_skip_date',
        check: check,
        respectSkipPreference: false,
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project and feedback entries invoke their own actions', (
    tester,
  ) async {
    var projects = 0;
    var feedback = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: AboutPageContent(
            currentVersion: '1.1.9',
            checkingUpdate: false,
            onCheckUpdate: () {},
            onOpenProject: () => projects++,
            onOpenFeedback: () => feedback++,
            onOpenDisclaimer: () {},
            onOpenLicenses: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(
      tester.element(find.byType(AboutPageContent)),
    )!;
    await _scrollTo(tester, find.text(strings.aboutProjectTitle));
    await tester.tap(find.text(strings.aboutProjectTitle));
    await _scrollTo(tester, find.text(strings.aboutFeedbackTitle));
    await tester.tap(find.text(strings.aboutFeedbackTitle));
    expect(projects, 1);
    expect(feedback, 1);
  });
}
