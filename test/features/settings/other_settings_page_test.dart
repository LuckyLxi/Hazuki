import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/features/settings/view/other/other_settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';
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

  testWidgets(
    'conversion menu defaults to off and animates opening and dismissal',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('other-chinese-conversion-menu'));
      expect(
        find.descendant(of: menu, matching: find.text('Off')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.byType(Switch)),
        findsNothing,
      );

      final button = find.byKey(const ValueKey('chinese-conversion-button'));
      final buttonRect = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final surface = find.byKey(
        const ValueKey('chinese-conversion-menu-surface'),
      );
      final opacity = find.byKey(
        const ValueKey('chinese-conversion-menu-opacity'),
      );
      final scale = find.byKey(const ValueKey('chinese-conversion-menu-scale'));
      final route = ModalRoute.of(tester.element(surface))!;
      expect(route.animation!.value, greaterThan(0));
      expect(route.animation!.value, lessThan(1));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      expect(
        tester.widget<Transform>(scale).transform.storage[0],
        inExclusiveRange(0.86, 1),
      );
      await tester.pumpAndSettle();
      expect(route.animation!.value, 1);
      final menuRect = tester.getRect(surface);
      expect(menuRect.right, closeTo(buttonRect.right, 0.1));
      expect(menuRect.top, closeTo(buttonRect.bottom + 8, 0.1));
      expect(
        tester.widget<ClipRRect>(surface).borderRadius,
        BorderRadius.circular(28),
      );
      expect(
        find.descendant(of: surface, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      expect(find.text('Traditional Chinese'), findsOneWidget);
      expect(find.text('Simplified Chinese'), findsOneWidget);

      await tester.tapAt(const Offset(790, 590));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.status, AnimationStatus.reverse);
      expect(route.animation!.value, greaterThan(0));
      expect(route.animation!.value, lessThan(1));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      expect(
        tester.widget<Transform>(scale).transform.storage[0],
        inExclusiveRange(0.86, 1),
      );
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(hazukiChineseConversionPreferenceKey), isNull);
    },
  );

  testWidgets(
    'conversion choices persist and restore when reopening settings',
    (tester) async {
      // Prepare assets outside the widget test's fake clock.
      await tester.runAsync(() async {
        await hazukiChineseConversion.setMode(
          ChineseConversionMode.traditional,
        );
        await hazukiChineseConversion.setMode(ChineseConversionMode.simplified);
        await hazukiChineseConversion.setMode(ChineseConversionMode.off);
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('other-chinese-conversion-menu'));
      final prefs = await SharedPreferences.getInstance();
      for (final (mode, label) in [
        (ChineseConversionMode.traditional, 'Traditional Chinese'),
        (ChineseConversionMode.simplified, 'Simplified Chinese'),
        (ChineseConversionMode.off, 'Off'),
      ]) {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        final choice = find.byKey(
          ValueKey('chinese-conversion-choice-${mode.name}'),
        );
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(
          prefs.getString(hazukiChineseConversionPreferenceKey),
          mode.name,
        );
        expect(
          find.descendant(of: menu, matching: find.text(label)),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: menu, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

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
