import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';
import 'dart:async';
import '../../support/source_presentation_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/features/settings/view/advanced/advanced_settings_page.dart';
import 'package:hazuki/features/settings/view/debug/lab_settings_page.dart';
import 'package:hazuki/features/settings/view/network/line_settings_page.dart';
import 'package:hazuki/features/settings/view/other/other_settings_page.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugin_action_widgets.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugin_settings_page.dart';
import 'package:hazuki/features/settings/view/reading_settings_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSelection extends Mock implements SourceSelectionGateway {}

class _MockSettings extends Mock implements SourceSettingsGateway {}

class _MockAdvanced extends Mock implements SourceAdvancedGateway {}

class _MockSoftwareUpdate extends Mock implements SoftwareUpdateService {}

class _MockDependencies extends Mock implements SettingsCoreDependencies {}

class _Plugins extends ChangeNotifier implements SourcePluginGateway {
  _Plugins() {
    installed = [
      InstalledSourcePlugin(
        manifest: SourcePluginManifest(
          id: 'fixture',
          name: 'Fixture plugin',
          version: '1.0.0',
          apiVersion: 1,
          entry: 'main.js',
          presentation: {
            'actions': [
              for (final location in SourcePluginActionLocation.values)
                {
                  'id': location.name,
                  'title': 'Action ${location.name}',
                  if (location != SourcePluginActionLocation.plugin)
                    'location': location.name,
                },
            ],
          },
        ),
        directory: 'fixture',
      ),
      InstalledSourcePlugin(
        manifest: const SourcePluginManifest(
          id: 'disabled',
          name: 'Disabled plugin',
          version: '1.0.0',
          apiVersion: 1,
          entry: 'main.js',
          presentation: {
            'actions': [
              {
                'id': 'ignored',
                'title': 'Ignored action',
                'location': 'reading',
              },
            ],
          },
        ),
        directory: 'disabled',
        enabled: false,
      ),
    ];
  }

  @override
  late List<InstalledSourcePlugin> installed;
  final metadataLoads = <String>[];
  final calls = <(String, String)>[];
  final values = <String, dynamic>{};
  Future<dynamic> Function()? action;
  Map<String, dynamic> settings = {
    'default': {'title': 'Default option', 'type': 'switch', 'default': false},
    'lines': {
      'title': 'Lines option',
      'type': 'switch',
      'default': false,
      'location': 'lines',
    },
    'stream': {
      'title': 'Lines stream',
      'type': 'select',
      'default': '1',
      'options': ['1', '2'],
      'location': 'lines',
    },
    'host': {
      'title': 'Lines host',
      'type': 'input',
      'default': '',
      'location': 'lines',
    },
  };

  @override
  Future<SourceMeta?> loadMetadata(String id) async {
    metadataLoads.add(id);
    return SourceMeta(
      name: 'Fixture plugin',
      key: id,
      version: '1.0.0',
      supportsAccount: false,
      settingsDefaults: const {},
      settings: settings,
      presentation: installed.first.manifest.presentation,
      translation: installed.first.manifest.translation,
    );
  }

  @override
  Object? loadSetting(String id, String key) => values['$id/$key'];
  @override
  Future<void> saveSetting(String id, String key, dynamic value) async {
    values['$id/$key'] = value;
  }

  @override
  Future<dynamic> runAction(String id, String actionId) async {
    calls.add((id, actionId));
    return action == null ? 'Done' : action!();
  }

  @override
  InstalledSourcePlugin? pluginFor(String id) =>
      installed.where((plugin) => plugin.manifest.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget page, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.android),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: page,
);

void main() {
  late _Plugins plugins;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    plugins = _Plugins();
  });
  tearDown(() => plugins.dispose());

  for (final market in [false, true]) {
    testWidgets(
      'advanced backup actions appear after editing and animate away for ${market ? 'market' : 'local'} plugins',
      (tester) async {
        var hasBackup = false;
        var restores = 0;
        var downloads = 0;
        final advanced = _MockAdvanced();
        when(advanced.hasActiveSourceBackup).thenAnswer((_) async => hasBackup);
        when(
          advanced.loadSoftwareLogCaptureEnabled,
        ).thenAnswer((_) async => false);
        final software = _MockSoftwareUpdate();
        when(
          software.loadUpdateSource,
        ).thenAnswer((_) async => SoftwareUpdateSource.github);
        final plugin = plugins.installed.first;
        plugins.installed = [
          InstalledSourcePlugin(
            manifest: plugin.manifest,
            directory: plugin.directory,
            repository: market ? 'https://example.com/plugins.json' : null,
            customEdited: true,
          ),
        ];
        await tester.pumpWidget(
          _app(
            withTestSourcePresentation(
              AdvancedSettingsPage(
                sourceService: advanced,
                sourcePlugins: plugins,
                softwareUpdateService: software,
                logsPageBuilder: (_) => const SizedBox.shrink(),
                comicSourceEditorPageBuilder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      hasBackup = true;
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save source edit'),
                  ),
                ),
                restoreComicSource: (_) async {
                  restores++;
                  hasBackup = false;
                  return true;
                },
                redownloadComicSource: (_) async {
                  downloads++;
                  return false;
                },
              ),
              activeSourceKey: 'fixture',
              catalog: const [
                SourceCatalogEntry(
                  key: 'fixture',
                  name: 'Fixture',
                  fileName: 'fixture.js',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final backupButton = find.byKey(const ValueKey('restore-comic-source'));
        final onlineButton = find.byKey(
          const ValueKey('redownload-comic-source'),
        );
        expect(backupButton, findsNothing);
        expect(onlineButton, findsNothing);
        final editorButton = find.widgetWithIcon(
          ListTile,
          Icons.javascript_rounded,
        );
        await tester.scrollUntilVisible(editorButton, 250);
        await tester.tap(editorButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save source edit'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(backupButton, 250);
        await tester.pumpAndSettle();
        if (market) {
          await tester.ensureVisible(onlineButton);
          await tester.pumpAndSettle();
          await tester.tap(onlineButton);
          await tester.pumpAndSettle();
          expect(downloads, 1);
        } else {
          expect(
            find.byKey(const ValueKey('redownload-comic-source')),
            findsNothing,
          );
        }
        await tester.ensureVisible(backupButton);
        await tester.pumpAndSettle();
        await tester.tap(backupButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        if (market) {
          expect(onlineButton, findsOneWidget);
          final fade = tester.widget<FadeTransition>(
            find
                .ancestor(
                  of: onlineButton,
                  matching: find.byType(FadeTransition),
                )
                .first,
          );
          expect(fade.opacity.value, greaterThan(0));
          expect(fade.opacity.value, lessThan(1));
          final size = tester.widget<SizeTransition>(
            find
                .ancestor(
                  of: onlineButton,
                  matching: find.byType(SizeTransition),
                )
                .first,
          );
          expect(size.sizeFactor.value, greaterThan(0));
          expect(size.sizeFactor.value, lessThan(1));
        }
        await tester.pumpAndSettle();
        expect(restores, 1);
        expect(backupButton, findsNothing);
        expect(onlineButton, findsNothing);
        expect(plugins.installed.single.customEdited, true);
        expect(tester.takeException(), null);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'advanced device button uses its declared owner and action in the original slot',
    (tester) async {
      final advanced = _MockAdvanced();
      when(advanced.hasActiveSourceBackup).thenAnswer((_) async => false);
      when(
        advanced.loadSoftwareLogCaptureEnabled,
      ).thenAnswer((_) async => false);
      final softwareUpdate = _MockSoftwareUpdate();
      when(
        softwareUpdate.loadUpdateSource,
      ).thenAnswer((_) async => SoftwareUpdateSource.jsDelivr);
      const button = {
        'id': 'resetDeviceInfo',
        'location': 'advanced',
        'action': 'resetSession',
        'title': {'en': 'Reset declared device', 'zh': '重置声明的设备'},
        'subtitle': {'en': 'Plugin device identifiers', 'zh': '插件设备标识'},
        'successMessage': {'en': 'Reset complete', 'zh': '重置完成'},
      };
      await tester.pumpWidget(
        _app(
          withTestSourcePresentation(
            AdvancedSettingsPage(
              sourceService: advanced,
              sourcePlugins: plugins,
              softwareUpdateService: softwareUpdate,
              logsPageBuilder: (_) => const SizedBox.shrink(),
              comicSourceEditorPageBuilder: (_) => const SizedBox.shrink(),
              restoreComicSource: (_) async => false,
            ),
            activeSourceKey: 'fixture',
            catalog: const [
              SourceCatalogEntry(
                key: 'fixture',
                name: 'Fixture',
                fileName: 'fixture.js',
                presentation: {
                  'buttons': [button],
                },
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Reset declared device'), 300);
      expect(find.byIcon(Icons.phonelink_erase_outlined), findsOneWidget);
      expect(find.text('Reset declared device'), findsOneWidget);
      await tester.tap(find.text('Reset declared device'));
      await tester.pumpAndSettle();
      expect(plugins.calls, [('fixture', 'resetSession')]);
      expect(find.text('Reset complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'advanced update route menu retains choices and saves selection',
    (tester) async {
      final advanced = _MockAdvanced();
      when(advanced.hasActiveSourceBackup).thenAnswer((_) async => false);
      when(
        advanced.loadSoftwareLogCaptureEnabled,
      ).thenAnswer((_) async => false);
      final softwareUpdate = _MockSoftwareUpdate();
      when(
        softwareUpdate.loadUpdateSource,
      ).thenAnswer((_) async => SoftwareUpdateSource.jsDelivr);
      for (final source in SoftwareUpdateSource.values) {
        when(
          () => softwareUpdate.setUpdateSource(source),
        ).thenAnswer((_) async {});
      }
      await tester.pumpWidget(
        _app(
          AdvancedSettingsPage(
            sourceService: advanced,
            softwareUpdateService: softwareUpdate,
            logsPageBuilder: (_) => const SizedBox.shrink(),
            comicSourceEditorPageBuilder: (_) => const SizedBox.shrink(),
            restoreComicSource: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dropdown = find.byType(HazukiFrostedDropdown<SoftwareUpdateSource>);
      await tester.scrollUntilVisible(dropdown, 250);
      expect(
        tester
            .widget<HazukiFrostedDropdown<SoftwareUpdateSource>>(dropdown)
            .selected,
        SoftwareUpdateSource.jsDelivr,
      );
      for (final (value, label) in [
        (SoftwareUpdateSource.github, 'GitHub'),
        (SoftwareUpdateSource.ghproxy, 'ghproxy'),
        (SoftwareUpdateSource.jsDelivr, 'jsdelivr'),
      ]) {
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        final surface = find.byKey(
          const ValueKey('hazuki-frosted-menu-surface'),
        );
        expect(
          find.descendant(of: surface, matching: find.byType(BackdropFilter)),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: surface, matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        verify(() => softwareUpdate.setUpdateSource(value)).called(1);
        expect(
          tester
              .widget<HazukiFrostedDropdown<SoftwareUpdateSource>>(dropdown)
              .selected,
          value,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  void localizedFixture({String location = 'plugin'}) {
    plugins.installed = [
      InstalledSourcePlugin(
        manifest: SourcePluginManifest.fromJson({
          ...plugins.installed.first.manifest.toJson(),
          'presentation': {
            'actions': [
              {'id': 'run', 'title': 'Refresh', 'location': location},
            ],
          },
          'translation': {
            'zh_CN': {'Refresh': '刷新', 'Done': '完成', 'Quality': '画质'},
            'en': {'High': 'High quality'},
          },
        }),
        directory: 'fixture',
      ),
    ];
  }

  testWidgets(
    'settings and actions follow locale while preserving saved values',
    (tester) async {
      localizedFixture();
      plugins.settings = {
        'enabled': {
          'title': {'en': 'Enable', 'zh': '启用'},
          'type': 'switch',
          'default': false,
        },
        'quality': {
          'title': 'Quality',
          'type': 'select',
          'default': 'high',
          'options': [
            {
              'value': 'high',
              'label': {'en': 'High', 'zh': '高'},
            },
            {
              'value': 'low',
              'text': {'en': 'Low', 'zh': '低'},
            },
          ],
        },
        'host': {
          'title': {'en': 'Host', 'zh': '地址'},
          'type': 'input',
          'default': 'https://example.com',
        },
      };
      final page = SourcePluginSettingsPage(id: 'fixture', gateway: plugins);
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      await tester.pumpWidget(_app(page, locale: const Locale('zh')));
      await tester.pumpAndSettle();
      expect(plugins.metadataLoads, ['fixture']);
      expect(find.text('刷新'), findsOneWidget);
      expect(find.text('启用'), findsOneWidget);
      expect(find.text('画质'), findsOneWidget);
      expect(find.text('高'), findsOneWidget);
      expect(find.text('https://example.com'), findsOneWidget);
      await tester.tap(find.byType(HazukiFrostedDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('低').last);
      await tester.pumpAndSettle();
      expect(plugins.values['fixture/quality'], 'low');
      await tester.tap(find.text('地址'));
      await tester.pumpAndSettle();
      expect(find.text('地址'), findsNWidgets(2));
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();
      expect(find.text('Host'), findsNWidgets(2));
      expect(find.text('Low'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://example.com',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uninitialized actions and pending results follow the current locale',
    (tester) async {
      localizedFixture(location: 'reading');
      final pending = Completer<dynamic>();
      plugins.action = () => pending.future;
      final page = Scaffold(
        body: SourcePluginActionList(
          gateway: plugins,
          location: SourcePluginActionLocation.reading,
        ),
      );
      await tester.pumpWidget(_app(page));
      expect(find.text('Refresh'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      await tester.pumpWidget(_app(page, locale: const Locale('zh')));
      await tester.pumpAndSettle();
      expect(find.text('刷新'), findsOneWidget);
      pending.complete('Done');
      await tester.pumpAndSettle();
      expect(find.text('完成'), findsOneWidget);
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(plugins.metadataLoads, isEmpty);
      expect(plugins.calls, [('fixture', 'run')]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('action titles and results accept language maps', (tester) async {
    plugins.action = () async => {'zh': '完成', 'en': 'Completed'};
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SourcePluginActionTile(
            gateway: plugins,
            pluginId: 'fixture',
            action: const SourcePluginAction(
              id: 'run',
              title: {'zh': '执行', 'en': 'Run'},
            ),
          ),
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.tap(find.text('执行'));
    await tester.pumpAndSettle();
    expect(find.text('完成'), findsOneWidget);
    expect(plugins.calls, [('fixture', 'run')]);
    expect(tester.takeException(), isNull);
  });

  for (final location in SourcePluginActionLocation.values) {
    testWidgets('actions are placed and run in the ${location.name} page', (
      tester,
    ) async {
      final settings = _MockSettings();
      when(() => settings.activeSourceKey).thenReturn('fixture');
      when(() => settings.presentationForSource('fixture')).thenReturn({});
      final selection = _MockSelection();
      when(() => selection.supportsDirectComicId).thenReturn(false);
      when(() => selection.supportsDailyRecommendation).thenReturn(false);
      when(() => selection.isActiveDailyCheckInSource).thenReturn(false);
      final dependencies = _MockDependencies();
      when(() => dependencies.sourceSelection).thenReturn(selection);
      when(() => dependencies.sourcePlugins).thenReturn(plugins);
      final advanced = _MockAdvanced();
      when(advanced.hasActiveSourceBackup).thenAnswer((_) async => false);
      when(
        advanced.loadSoftwareLogCaptureEnabled,
      ).thenAnswer((_) async => false);
      final softwareUpdate = _MockSoftwareUpdate();
      when(
        softwareUpdate.loadUpdateSource,
      ).thenAnswer((_) async => SoftwareUpdateSource.jsDelivr);
      final page = switch (location) {
        SourcePluginActionLocation.plugin => SourcePluginSettingsPage(
          id: 'fixture',
          gateway: plugins,
        ),
        SourcePluginActionLocation.reading => ReadingSettingsPage(
          sourceService: settings,
          sourcePlugins: plugins,
        ),
        SourcePluginActionLocation.other => OtherSettingsPage(
          dependencies: dependencies,
        ),
        SourcePluginActionLocation.lab => LabSettingsPage(
          sourcePlugins: plugins,
        ),
        SourcePluginActionLocation.advanced => AdvancedSettingsPage(
          sourceService: advanced,
          sourcePlugins: plugins,
          softwareUpdateService: softwareUpdate,
          logsPageBuilder: (_) => const SizedBox.shrink(),
          comicSourceEditorPageBuilder: (_) => const SizedBox.shrink(),
          restoreComicSource: (_) async => false,
        ),
        SourcePluginActionLocation.lines => LineSettingsPage(
          sourceService: settings,
          sourcePlugins: plugins,
        ),
      };
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Action ${location.name}'),
        300,
      );
      expect(find.text('Action ${location.name}'), findsOneWidget);
      expect(find.text('Ignored action'), findsNothing);
      if (location == SourcePluginActionLocation.lines) {
        final strings = AppLocalizations.of(
          tester.element(find.byType(LineSettingsPage)),
        )!;
        expect(find.text(strings.lineSettingsTitle), findsOneWidget);
        expect(find.byType(SourcePluginSettingsPage), findsNothing);
        expect(find.text('Default option'), findsNothing);
      }
      if (location != SourcePluginActionLocation.plugin &&
          location != SourcePluginActionLocation.lines) {
        expect(plugins.metadataLoads, isEmpty);
      }
      await tester.tap(find.text('Action ${location.name}'));
      await tester.pumpAndSettle();
      expect(plugins.calls, [('fixture', location.name)]);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reading quality uses the frosted menu and saves the selection', (
    tester,
  ) async {
    final settings = _MockSettings();
    when(() => settings.activeSourceKey).thenReturn('fixture');
    when(() => settings.presentationForSource('fixture')).thenReturn({
      'imageQualitySetting': 'quality',
      'imageQualityTitle': 'Image quality',
      'imageQualityOptions': {
        'standard': 'Standard quality',
        'original': 'Original quality',
      },
      'imageQualityDefault': 'standard',
      'buttons': [
        {'id': 'imageQuality', 'location': 'reading'},
      ],
    });
    when(
      () => settings.updateSourceSetting('fixture', 'quality', 'original'),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(_app(ReadingSettingsPage(sourceService: settings)));
    await tester.pumpAndSettle();
    final dropdown = find.byType(HazukiFrostedDropdown<String>);
    await tester.scrollUntilVisible(dropdown, 300);
    expect(find.text('Image quality'), findsOneWidget);
    expect(
      find.descendant(of: dropdown, matching: find.text('Standard quality')),
      findsOneWidget,
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hazuki-frosted-menu-surface')),
      findsOneWidget,
    );
    await tester.tap(find.text('Original quality'));
    await tester.pumpAndSettle();
    verify(
      () => settings.updateSourceSetting('fixture', 'quality', 'original'),
    ).called(1);
    expect(
      find.descendant(of: dropdown, matching: find.text('Original quality')),
      findsOneWidget,
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey(('hazuki-frosted-menu', 'original')),
                  ),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    verifyNever(
      () => settings.updateSourceSetting('fixture', 'quality', any()),
    );
    expect(find.byType(ReadingSettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'plugin select settings show labels and persist values with the frosted menu',
    (tester) async {
      plugins.settings['quality'] = {
        'title': 'Image quality',
        'type': 'select',
        'default': 'standard',
        'options': [
          {'value': 'standard', 'label': 'Standard quality'},
          {'value': 'original', 'label': 'Original quality'},
        ],
      };
      await tester.pumpWidget(
        _app(SourcePluginSettingsPage(id: 'fixture', gateway: plugins)),
      );
      await tester.pumpAndSettle();
      final dropdown = find.byType(HazukiFrostedDropdown<String>);
      expect(dropdown, findsOneWidget);
      expect(find.text('Standard quality'), findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original quality'));
      await tester.pumpAndSettle();
      expect(plugins.values['fixture/quality'], 'original');
      expect(
        find.descendant(of: dropdown, matching: find.text('Original quality')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plugin defaults stay local and lines controls save scoped values',
    (tester) async {
      await tester.pumpWidget(
        _app(SourcePluginSettingsPage(id: 'fixture', gateway: plugins)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Action plugin'), findsOneWidget);
      expect(find.text('Action lines'), findsNothing);
      expect(find.text('Default option'), findsOneWidget);
      expect(find.text('Lines option'), findsNothing);

      final sourceSettings = _MockSettings();
      when(() => sourceSettings.activeSourceKey).thenReturn('fixture');
      await tester.pumpWidget(
        _app(
          LineSettingsPage(
            sourceService: sourceSettings,
            sourcePlugins: plugins,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Action plugin'), findsNothing);
      expect(find.text('Action lines'), findsOneWidget);
      expect(find.text('Default option'), findsNothing);
      expect(find.text('Lines option'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(SwitchListTile, 'Lines option'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(plugins.values['fixture/lines'], isTrue);
      await tester.tap(find.byType(HazukiFrostedDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      expect(plugins.values['fixture/stream'], '2');
      await tester.tap(find.text('Lines host'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://custom.example');
      await tester.tap(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(TextField)),
          )!.commonConfirm,
        ),
      );
      await tester.pumpAndSettle();
      expect(plugins.values['fixture/host'], 'https://custom.example');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lines actions only belong to the current source', (
    tester,
  ) async {
    plugins.installed.add(
      InstalledSourcePlugin(
        manifest: const SourcePluginManifest(
          id: 'jm',
          name: 'JMComic',
          version: '1.0.0',
          apiVersion: 1,
          entry: 'main.js',
          presentation: {
            'actions': [
              {'id': 'refresh', 'title': 'Refresh lines', 'location': 'lines'},
            ],
          },
        ),
        directory: 'jm',
      ),
    );
    final settings = _MockSettings();
    String? activeSource = 'fixture';
    when(() => settings.activeSourceKey).thenAnswer((_) => activeSource);
    Future<void> showLines() async {
      await tester.pumpWidget(
        _app(LineSettingsPage(sourceService: settings, sourcePlugins: plugins)),
      );
      await tester.pumpAndSettle();
    }

    await showLines();
    expect(find.text('Action lines'), findsOneWidget);
    expect(find.text('Refresh lines'), findsNothing);
    expect(find.text('JMComic'), findsNothing);
    await tester.tap(find.text('Action lines'));
    await tester.pumpAndSettle();
    expect(plugins.calls, [('fixture', 'lines')]);

    activeSource = 'jm';
    await showLines();
    expect(find.text('Action lines'), findsNothing);
    expect(find.text('Refresh lines'), findsOneWidget);
    expect(find.text('JMComic'), findsOneWidget);
    await tester.tap(find.text('Refresh lines'));
    await tester.pumpAndSettle();
    expect(plugins.calls, [('fixture', 'lines'), ('jm', 'refresh')]);

    plugins.installed = [
      for (final plugin in plugins.installed)
        plugin.manifest.id == 'jm' ? plugin.copyWith(enabled: false) : plugin,
    ];
    plugins.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Refresh lines'), findsNothing);

    activeSource = 'missing';
    await showLines();
    expect(find.byType(SourcePluginActionTile), findsNothing);
    activeSource = null;
    await showLines();
    expect(find.byType(SourcePluginActionTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled and uninstalled plugins remove their action entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SourcePluginActionList(
            gateway: plugins,
            location: SourcePluginActionLocation.reading,
          ),
        ),
      ),
    );
    expect(find.text('Action reading'), findsOneWidget);
    plugins.installed = [plugins.installed.first.copyWith(enabled: false)];
    plugins.notifyListeners();
    await tester.pump();
    expect(find.text('Action reading'), findsNothing);
    plugins.installed = [plugins.installed.first.copyWith(enabled: true)];
    plugins.notifyListeners();
    await tester.pump();
    expect(find.text('Action reading'), findsOneWidget);
    plugins.installed = [];
    plugins.notifyListeners();
    await tester.pump();
    expect(find.text('Action reading'), findsNothing);
    expect(plugins.metadataLoads, isEmpty);
  });

  testWidgets('action clicks wait once and expose failures', (tester) async {
    final pending = Completer<dynamic>();
    plugins.action = () => pending.future;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SourcePluginActionList(
            gateway: plugins,
            location: SourcePluginActionLocation.reading,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Action reading'));
    await tester.pump();
    await tester.tap(find.text('Action reading'));
    expect(plugins.calls, hasLength(1));
    pending.completeError(StateError('Action failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Action failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
