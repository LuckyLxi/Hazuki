import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/features/settings/view/advanced/advanced_settings_page.dart';
import 'package:hazuki/features/settings/view/debug/favorites_debug_page.dart';
import 'package:hazuki/features/settings/view/debug/lab_settings_page.dart';
import 'package:hazuki/features/settings/view/network/cloud_sync_page.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/features/settings/view/settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Plugins extends Mock implements SourcePluginGateway {}

class _Dependencies extends Mock implements SettingsCoreDependencies {}

class _CloudSync extends Mock implements CloudSyncService {}

class _SourceScript extends Mock implements SourceScriptGateway {}

class _Debug extends Mock implements SourceDebugGateway {}

class _SoftwareUpdate extends Mock implements SoftwareUpdateService {}

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets(
      'settings opens its subpages and lists plugins above cloud sync in $locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final plugins = _Plugins();
        when(plugins.initialize).thenAnswer((_) async {});
        when(() => plugins.installed).thenReturn([]);
        when(() => plugins.entriesFor(any())).thenReturn([]);
        when(() => plugins.checkingIndex).thenReturn(false);
        final dependencies = _Dependencies();
        when(() => dependencies.sourcePlugins).thenReturn(plugins);
        final cloudSync = _CloudSync();
        when(cloudSync.loadConfig).thenAnswer(
          (_) async => const CloudSyncConfig(
            enabled: false,
            url: '',
            username: '',
            password: '',
          ),
        );
        when(() => dependencies.cloudSync).thenReturn(cloudSync);
        final sourceScript = _SourceScript();
        when(sourceScript.hasActiveSourceBackup).thenAnswer((_) async => false);
        when(() => dependencies.sourceScript).thenReturn(sourceScript);
        final debug = _Debug();
        when(
          debug.loadSoftwareLogCaptureEnabled,
        ).thenAnswer((_) async => false);
        when(
          () => debug.logChanges,
        ).thenReturn(const AlwaysStoppedAnimation(0));
        when(debug.collectAllDebugInfo).thenAnswer((_) async => {'logs': []});
        when(() => dependencies.sourceDebug).thenReturn(debug);
        final update = _SoftwareUpdate();
        when(
          update.loadUpdateSource,
        ).thenAnswer((_) async => SoftwareUpdateSource.github);
        when(() => dependencies.softwareUpdate).thenReturn(update);
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

        Future<void> openTile(String title) async {
          final tile = find.widgetWithText(ListTile, title);
          await tester.scrollUntilVisible(tile, 200);
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();
        }

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await openTile(strings.settingsCloudSyncTitle);
        expect(
          tester.widget<CloudSyncPage>(find.byType(CloudSyncPage)).service,
          same(cloudSync),
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await openTile(strings.settingsLabTitle);
        expect(
          tester
              .widget<LabSettingsPage>(find.byType(LabSettingsPage))
              .sourcePlugins,
          same(plugins),
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await openTile(strings.settingsAdvancedTitle);
        final advanced = tester.widget<AdvancedSettingsPage>(
          find.byType(AdvancedSettingsPage),
        );
        expect(advanced.sourceService, same(sourceScript));
        expect(advanced.sourcePlugins, same(plugins));
        expect(advanced.softwareUpdateService, same(update));
        await openTile(strings.advancedDebugTitle);
        expect(
          tester.widget<LogsPage>(find.byType(LogsPage)).debugGateway,
          same(debug),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
