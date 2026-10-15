import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/features/settings/view/debug/lab_settings_page.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/features/settings/view/settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:mocktail/mocktail.dart';

class _Plugins extends Mock implements SourcePluginGateway {}

class _Dependencies extends Mock implements SettingsCoreDependencies {}

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'settings opens plugins immediately above cloud sync in $locale',
      (tester) async {
        final plugins = _Plugins();
        when(plugins.initialize).thenAnswer((_) async {});
        when(() => plugins.installed).thenReturn([]);
        when(() => plugins.entriesFor(any())).thenReturn([]);
        when(() => plugins.checkingIndex).thenReturn(false);
        final dependencies = _Dependencies();
        when(() => dependencies.sourcePlugins).thenReturn(plugins);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(
              appearanceSettings: const AppearanceSettingsData(
                themeMode: ThemeMode.system,
                oledPureBlack: false,
                dynamicColor: false,
                presetIndex: 0,
                displayModeRaw: 'system',
                comicDetailDynamicColor: false,
                useSystemFont: true,
              ),
              onAppearanceChanged:
                  (_, {revealOrigin, revealSyncRegion}) async {},
              locale: Locale(locale),
              onLocaleChanged: (_) async {},
              cloudSyncPageBuilder: (_) =>
                  const Scaffold(body: Text('Cloud sync page')),
              labSettingsPageBuilder: (_) =>
                  LabSettingsPage(sourcePlugins: plugins),
              advancedSettingsPageBuilder: (_) => const SizedBox.shrink(),
              coreDependencies: dependencies,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = AppLocalizations.of(
          tester.element(find.byType(SettingsPage)),
        )!;
        final pluginTile = find.widgetWithText(
          ListTile,
          strings.settingsPluginsTitle,
        );
        await tester.ensureVisible(pluginTile);
        await tester.pumpAndSettle();
        expect(strings.settingsPluginsTitle, locale == 'zh' ? '插件' : 'Plugins');
        final titles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title as Text).data)
            .toList();
        expect(
          titles[titles.indexOf(strings.settingsPluginsTitle) + 1],
          strings.settingsCloudSyncTitle,
        );
        await tester.tap(pluginTile);
        await tester.pumpAndSettle();
        expect(find.byType(SourcePluginsPage), findsOneWidget);
        expect(
          DefaultTabController.of(tester.element(find.byType(TabBar))).index,
          SourcePluginsTab.installed.index,
        );
        verify(plugins.initialize).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
