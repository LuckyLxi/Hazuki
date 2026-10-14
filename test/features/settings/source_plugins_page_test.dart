import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/adapters/hazuki_source_plugin_adapter.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final useUpdate in [false, true]) {
    for (final confirm in [false, true]) {
      testWidgets(
        '${useUpdate ? 'update' : 'repository install'} confirms edited replacement (confirm: $confirm)',
        (tester) async {
          const repository = 'https://plugins.fixture.example/plugins.json';
          final nextVersion = useUpdate ? '1.1.0' : '1.0.0';
          String script(String version) =>
              "Hazuki.registerSource({id:'edited_example',name:'Edited example',version:'$version',search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});";
          var packageDownloads = 0;
          late Directory directory;
          late SourcePluginManager manager;
          await tester.runAsync(() async {
            directory = await Directory.systemTemp.createTemp(
              'hazuki_plugin_ui_',
            );
            manager = SourcePluginManager(
              directory: () async => directory,
              legacyDirectories: [],
              download: (url) async {
                if (url.toString() == repository) {
                  return utf8.encode(
                    jsonEncode({
                      'schemaVersion': 1,
                      'plugins': [
                        {
                          'id': 'edited_example',
                          'name': 'Edited example',
                          'version': nextVersion,
                          'downloadUrl':
                              'https://plugins.fixture.example/replacement.js',
                        },
                      ],
                    }),
                  );
                }
                packageDownloads++;
                return utf8.encode(
                  script(
                    url.path.endsWith('initial.js') ? '1.0.0' : nextVersion,
                  ),
                );
              },
            );
            await manager.addRepository(repository);
            await manager.installFromRepository(
              repository,
              SourcePluginIndexEntry(
                id: 'edited_example',
                name: 'Edited example',
                version: '1.0.0',
                downloadUrl: Uri.parse(
                  'https://plugins.fixture.example/initial.js',
                ),
              ),
            );
            await manager.write(
              'edited_example',
              '${script('1.0.0')}\n// User edits',
            );
            await manager.setCustomEdited('edited_example', true);
          });
          addTearDown(manager.dispose);
          addTearDown(() async {
            await tester.runAsync(() => directory.delete(recursive: true));
          });
          final previous = manager.pluginFor('edited_example')!;
          final gateway = HazukiSourcePluginAdapter(
            manager,
            metadataLoader: (_) async => null,
            settingLoader: (_, _) => null,
            settingWriter: (_, _, _) async {},
            actionRunner: (_, _) async => null,
          );
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SourcePluginsPage(manager: gateway),
            ),
          );
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          final s = AppLocalizations.of(
            tester.element(find.byType(SourcePluginsPage)),
          )!;

          if (useUpdate) {
            await tester.ensureVisible(find.text(s.pluginsCheckUpdate));
            await tester.runAsync(
              () => tester.tap(find.text(s.pluginsCheckUpdate)),
            );
          } else {
            await tester.ensureVisible(find.byType(ExpansionTile));
            await tester.runAsync(() => tester.tap(find.byType(ExpansionTile)));
            await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text(s.pluginsInstall));
            await tester.runAsync(
              () => tester.tap(find.text(s.pluginsInstall)),
            );
          }
          // The page's progress indicator remains animated while confirmation
          // is pending, so settle only the dialog's entrance transition.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(s.pluginsEditedUpdate), findsOneWidget);
          expect(packageDownloads, 1);
          expect(manager.pluginFor('edited_example'), same(previous));

          if (confirm) {
            await tester.runAsync(() async {
              final replaced = Completer<void>();
              void onReplaced() {
                if (manager.pluginFor('edited_example')?.customEdited ==
                        false &&
                    !replaced.isCompleted) {
                  replaced.complete();
                }
              }

              manager.addListener(onReplaced);
              try {
                await tester.tap(find.text(s.commonConfirm));
                await replaced.future.timeout(const Duration(seconds: 5));
              } finally {
                manager.removeListener(onReplaced);
              }
            });
            expect(packageDownloads, 2);
            expect(
              manager.pluginFor('edited_example')!.manifest.version,
              nextVersion,
            );
            expect(
              manager.pluginFor('edited_example')!.directory,
              isNot(previous.directory),
            );
            // The prior generation remains available as a backup.
            await tester.runAsync(() async {
              final backup = File(
                '${directory.path}/${previous.directory}/main.js',
              );
              expect(await backup.readAsString(), contains('// User edits'));
            });
          } else {
            await tester.tap(find.text(s.commonCancel));
            expect(packageDownloads, 1);
            expect(manager.pluginFor('edited_example'), same(previous));
            await tester.runAsync(() async {
              expect(
                await manager.readIfExists('edited_example'),
                contains('// User edits'),
              );
            });
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('plugin manager reflects install, disable and uninstall', (
    tester,
  ) async {
    late Directory directory;
    late SourcePluginManager manager;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('hazuki_plugin_ui_');
      manager = SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
      );
      await manager.initialize();
    });
    final gateway = HazukiSourcePluginAdapter(
      manager,
      metadataLoader: (_) async => null,
      settingLoader: (_, _) => null,
      settingWriter: (_, _, _) async {},
      actionRunner: (_, _) async => null,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourcePluginsPage(manager: gateway),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SourcePluginsPage));
    final s = AppLocalizations.of(context)!;
    expect(find.text(s.pluginsEmpty), findsOneWidget);
    expect(find.text(s.pluginsImportLocal), findsOneWidget);
    expect(find.text(s.pluginsAddRepository), findsOneWidget);

    const script =
        "Hazuki.registerSource({id:'widget_example',name:'Widget example',version:'1.0.0',search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});";
    await tester.runAsync(() => manager.importPackage(utf8.encode(script)));
    await tester.pumpAndSettle();
    expect(find.text('Widget example'), findsOneWidget);
    expect(find.text(s.pluginsEmpty), findsNothing);

    await tester.runAsync(() async {
      final disabled = Completer<void>();
      void onDisabled() {
        if (manager.pluginFor('widget_example')?.enabled == false &&
            !disabled.isCompleted) {
          disabled.complete();
        }
      }

      manager.addListener(onDisabled);
      await tester.tap(find.byType(Switch));
      await disabled.future.timeout(const Duration(seconds: 5));
      manager.removeListener(onDisabled);
    });
    await tester.pumpAndSettle();
    expect(manager.pluginFor('widget_example')!.enabled, isFalse);
    expect(manager.catalog, isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.runAsync(() async {
      final uninstalled = Completer<void>();
      void onUninstalled() {
        if (manager.pluginFor('widget_example') == null &&
            !uninstalled.isCompleted) {
          uninstalled.complete();
        }
      }

      manager.addListener(onUninstalled);
      await tester.tap(find.text(s.pluginsUninstall));
      await uninstalled.future.timeout(const Duration(seconds: 5));
      manager.removeListener(onUninstalled);
    });
    await tester.pumpAndSettle();
    expect(find.text(s.pluginsEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
}
