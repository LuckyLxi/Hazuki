import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/features/settings/view/other/other_settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSelection extends Mock implements SourceSelectionGateway {}

class _MockDependencies extends Mock implements SettingsCoreDependencies {}

void main() {
  late _MockSelection selection;
  late _MockDependencies dependencies;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      hazukiComicIdSearchEnhancePreferenceKey: true,
    });
    selection = _MockSelection();
    when(() => selection.supportsDirectComicId).thenReturn(true);
    when(() => selection.supportsDailyRecommendation).thenReturn(false);
    dependencies = _MockDependencies();
    when(() => dependencies.sourceSelection).thenReturn(selection);
  });

  Widget app() => MaterialApp(
    theme: ThemeData(platform: TargetPlatform.android),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: OtherSettingsPage(dependencies: dependencies),
  );

  Finder comicIdSwitch(WidgetTester tester) {
    final strings = AppLocalizations.of(
      tester.element(find.byType(OtherSettingsPage)),
    )!;
    return find.widgetWithText(
      SwitchListTile,
      strings.advancedComicIdSearchTitle,
    );
  }

  testWidgets('other settings preserves and updates the comic ID preference', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final tile = comicIdSwitch(tester);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(comicIdSwitch(tester)).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comic ID setting follows source support without clearing it', (
    tester,
  ) async {
    when(() => selection.supportsDirectComicId).thenReturn(false);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(comicIdSwitch(tester), findsNothing);
    final onSourceChanged =
        verify(() => selection.addListener(captureAny())).captured.single
            as VoidCallback;

    when(() => selection.supportsDirectComicId).thenReturn(true);
    onSourceChanged();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(comicIdSwitch(tester)).value, isTrue);

    when(() => selection.supportsDirectComicId).thenReturn(false);
    onSourceChanged();
    await tester.pumpAndSettle();
    expect(comicIdSwitch(tester), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey), isTrue);
    expect(tester.takeException(), isNull);
  });
}
