import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/settings/view/appearance/appearance_settings_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _MockSourceDebugGateway extends Mock implements SourceDebugGateway {}

const _initialSettings = AppearanceSettingsData(
  themeMode: ThemeMode.light,
  oledPureBlack: false,
  dynamicColor: false,
  presetIndex: hazukiDefaultAppearancePresetIndex,
  displayModeRaw: 'system',
  comicDetailDynamicColor: false,
  useSystemFont: true,
);

void main() {
  testWidgets('passes slider bounds for brightness reveal synchronization', (
    tester,
  ) async {
    final appliedModes = <ThemeMode>[];
    Rect? syncRegion;
    var settings = _initialSettings;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppearanceSettingsContent(
                settings: settings,
                locale: const Locale('en'),
                onApply: (next, {revealOrigin, revealSyncRegion}) async {
                  appliedModes.add(next.themeMode);
                  syncRegion = revealSyncRegion;
                  setState(() {
                    settings = next;
                  });
                },
                onApplyLocale: (_) async {},
                debugGateway: _MockSourceDebugGateway(),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(appliedModes, [ThemeMode.dark]);
    expect(syncRegion, isNotNull);
    expect(syncRegion!.width, greaterThan(0));
    expect(syncRegion!.height, 52);
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
      Alignment.center,
    );
  });

  testWidgets('changes the discover section layout from appearance settings', (
    tester,
  ) async {
    var settings = _initialSettings;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppearanceSettingsContent(
                settings: settings,
                locale: const Locale('en'),
                onApply: (next, {revealOrigin, revealSyncRegion}) async {
                  setState(() {
                    settings = next;
                  });
                },
                onApplyLocale: (_) async {},
                debugGateway: _MockSourceDebugGateway(),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Discover section layout'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discover-layout-picker-grid')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('2-column grid'));
    await tester.pumpAndSettle();

    expect(settings.discoverSectionLayout, DiscoverSectionLayout.grid2);
    expect(find.text('2-column grid'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('selects all favorite layouts on $platform', (tester) async {
      var settings = _initialSettings;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppearanceSettingsContent(
                settings: settings,
                locale: const Locale('en'),
                onApply: (next, {revealOrigin, revealSyncRegion}) async {
                  setState(() => settings = next);
                },
                onApplyLocale: (_) async {},
                debugGateway: _MockSourceDebugGateway(),
              ),
            ),
          ),
        ),
      );

      final setting = find.byKey(const ValueKey('favorite-layout-setting'));
      await tester.scrollUntilVisible(setting, 200);
      for (final layout in [
        FavoriteLayout.grid3,
        FavoriteLayout.grid2,
        FavoriteLayout.coverOnly,
        FavoriteLayout.list,
      ]) {
        await tester.tap(setting);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        for (final option in FavoriteLayout.values) {
          expect(
            find.byKey(ValueKey('favorite-layout-option-${option.name}')),
            findsOneWidget,
          );
        }
        await tester.tap(
          find.byKey(ValueKey('favorite-layout-option-${layout.name}')),
        );
        await tester.pumpAndSettle();
        expect(settings.favoriteLayout, layout);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
