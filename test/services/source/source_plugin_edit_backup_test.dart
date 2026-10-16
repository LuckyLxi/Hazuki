import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

String script(String id, {String version = '1.0.0'}) =>
    '''
Hazuki.registerSource({id:'$id',version:'$version',
search:{load:async()=>({comics:[]})},
comic:{loadInfo:async()=>({title:'Comic',chapters:{}}),loadEp:async()=>({images:[]})}});
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SourcePluginManager manager;
  late SourceRuntimeAssembly assembly;
  var version = '1.0.0';
  var packageUrl = 'https://example.com/a.js?original=1';
  var offline = false;
  final requests = <String>[];

  SourcePluginManager createManager() => SourcePluginManager(
    directory: () async => root,
    legacyDirectories: [],
    download: (url) async {
      requests.add(url.toString());
      if (offline) throw StateError('offline');
      if (url.path.endsWith('plugins.json')) {
        return utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'plugins': [
              {
                'id': 'a',
                'name': 'A',
                'version': version,
                'downloadUrl': packageUrl,
              },
            ],
          }),
        );
      }
      return utf8.encode(script('a', version: version));
    },
  );

  Future<void> installMarket() async {
    await manager.refreshRepository(sourcePluginsRepositoryUrl);
    await manager.installFromRepository(
      sourcePluginsRepositoryUrl,
      manager.entriesFor(sourcePluginsRepositoryUrl).single,
    );
  }

  Future<void> failCommits() => Directory(
    '${root.path}/${SourcePluginManager.installedPluginsFileName}.pending',
  ).create();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'advanced_software_update_source': 'github',
    });
    root = await Directory.systemTemp.createTemp('hazuki_plugin_backups_');
    version = '1.0.0';
    packageUrl = 'https://example.com/a.js?original=1';
    offline = false;
    requests.clear();
    manager = createManager();
    assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    await assembly.runtimeRegistry.loadActiveSourcePreference();
  });

  tearDown(() async {
    assembly.dispose();
    await root.delete(recursive: true);
  });

  test(
    'editing rotates one backup and restoring consumes it across restarts',
    () async {
      final original = script('a');
      await manager.importPackage(utf8.encode(original));
      await assembly.ensureSourceInitialized('a');
      final engine = assembly.testing.handleFor('a').runtime.engine;
      final edited = '$original\n// B';
      await assembly.gateways.script.saveEditedActiveSource(edited);
      expect(await assembly.gateways.advanced.hasActiveSourceBackup(), true);
      expect(assembly.testing.handleFor('a').runtime.engine, same(engine));
      await assembly.gateways.script.saveEditedActiveSource('$original\n// C');
      expect(await manager.readIfExists('a'), endsWith('// C'));
      final restarted = createManager();
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(await restarted.restoreEditBackup('a'), true);
      expect(await restarted.readIfExists('a'), edited);
      expect(await restarted.isCustomEdited('a'), true);
      expect(await restarted.hasEditBackup('a'), false);
      expect(await restarted.restoreEditBackup('a'), false);
      final restored = createManager();
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(await restored.hasEditBackup('a'), false);
    },
  );

  test(
    'restoring the first backup restores unedited state and requests restart',
    () async {
      final original = script('a');
      await manager.importPackage(utf8.encode(original));
      await assembly.gateways.script.saveEditedActiveSource(
        '$original\n// edit',
      );
      expect(await assembly.gateways.script.restoreActiveSourceBackup(), true);
      expect(await manager.readIfExists('a'), original);
      expect(await manager.isCustomEdited('a'), false);
      expect(await assembly.gateways.advanced.hasActiveSourceBackup(), false);
      expect(
        assembly.testing.handleFor('a').facade.runtimeState.isWaitingForRestart,
        true,
      );
    },
  );

  test('repeated saves retain only the current edit and one backup', () async {
    await manager.importPackage(utf8.encode(script('a')));
    for (final content in ['B', 'C', 'D', 'E']) {
      await manager.saveEditedScript('a', content);
    }
    expect(await Directory('${root.path}/edits').list().length, 2);
    expect(await manager.restoreEditBackup('a'), true);
    expect(await manager.readIfExists('a'), 'D');
    expect(await Directory('${root.path}/edits').list().length, 1);
  });

  for (final restoring in [false, true]) {
    test(
      'unrelated plugin changes preserve the running source after ${restoring ? 'restore' : 'save'}',
      () async {
        await manager.importPackage(utf8.encode(script('a')));
        await manager.importPackage(utf8.encode(script('b')));
        await assembly.ensureSourceInitialized('a');
        final handle = assembly.testing.handleFor('a');
        final engine = handle.runtime.engine;
        final revision = assembly.testing.runtime.sourceRevision;
        await assembly.gateways.script.saveEditedActiveSource('invalid B !!!');
        await assembly.gateways.script.saveEditedActiveSource('invalid C !!!');
        if (restoring) {
          expect(
            await assembly.gateways.script.restoreActiveSourceBackup(),
            true,
          );
        }

        Future<void> expectOriginalRuntime() async {
          expect(handle.isDisposed, false);
          expect(assembly.testing.handleFor('a'), same(handle));
          expect(handle.runtime.engine, same(engine));
          expect(assembly.testing.runtime.sourceRevision, revision);
          expect(handle.facade.runtimeState.isWaitingForRestart, true);
          await assembly.ensureSourceInitialized('a');
        }

        await manager.setEnabled('b', false);
        await expectOriginalRuntime();
        await manager.setEnabled('b', true);
        await expectOriginalRuntime();
        await manager.importPackage(utf8.encode(script('b', version: '2.0.0')));
        await expectOriginalRuntime();
        await manager.uninstall('b');
        await expectOriginalRuntime();
      },
    );
  }

  test(
    'redownload replaces the same source despite its pending edits',
    () async {
      await installMarket();
      await assembly.ensureSourceInitialized('a');
      final handle = assembly.testing.handleFor('a');
      final revision = assembly.testing.runtime.sourceRevision;
      await assembly.gateways.script.saveEditedActiveSource('invalid edit !!!');
      expect(await manager.redownload('a'), true);
      expect(handle.isDisposed, true);
      expect(assembly.testing.runtime.sourceRevision, isNot(revision));
      await assembly.ensureSourceInitialized('a');
      expect(
        assembly.testing.handleFor('a').runtime.sourceMeta!.version,
        '1.0.0',
      );
    },
  );

  test('reenabling the edited source publishes its saved revision', () async {
    await manager.importPackage(utf8.encode(script('a')));
    await assembly.ensureSourceInitialized('a');
    final handle = assembly.testing.handleFor('a');
    final revision = assembly.testing.runtime.sourceRevision;
    await assembly.gateways.script.saveEditedActiveSource(
      script('a', version: '2.0.0'),
    );
    await manager.setEnabled('a', false);
    await manager.setEnabled('a', true);
    expect(handle.isDisposed, true);
    expect(assembly.testing.runtime.sourceRevision, isNot(revision));
    await assembly.ensureSourceInitialized('a');
    expect(
      assembly.testing.handleFor('a').runtime.sourceMeta!.version,
      '2.0.0',
    );
  });

  for (final restoring in [false, true]) {
    test(
      'failed ${restoring ? 'restore' : 'save'} preserves current script and previous backup',
      () async {
        await manager.importPackage(utf8.encode(script('a')));
        await manager.saveEditedScript('a', 'B');
        final previous = manager.pluginFor('a')!.toJson();
        final committed = await File(
          '${root.path}/${SourcePluginManager.installedPluginsFileName}',
        ).readAsString();
        await failCommits();
        await expectLater(
          restoring
              ? manager.restoreEditBackup('a')
              : manager.saveEditedScript('a', 'C'),
          throwsA(isA<FileSystemException>()),
        );
        expect(manager.pluginFor('a')!.toJson(), previous);
        expect(await manager.readIfExists('a'), 'B');
        expect(await manager.hasEditBackup('a'), true);
        expect(
          await File(
            '${root.path}/${SourcePluginManager.installedPluginsFileName}',
          ).readAsString(),
          committed,
        );
      },
    );
  }

  test(
    'online redownload refreshes the index at the same version without creating a backup',
    () async {
      await installMarket();
      packageUrl = 'https://example.com/new-location.js?token=a%2Fb';
      requests.clear();
      expect(
        await assembly.gateways.update.downloadActiveSourceAndReload(),
        true,
      );
      expect(requests, [sourcePluginsRepositoryUrl, packageUrl]);
      expect(await manager.hasEditBackup('a'), false);
    },
  );

  test(
    'online replacement preserves the edit backup and its original version',
    () async {
      await installMarket();
      await manager.saveEditedScript('a', '${script('a')}\n// edit');
      final backup = manager.pluginFor('a')!.editBackup!.toJson();
      version = '2.0.0';
      expect(await manager.redownload('a'), true);
      expect(manager.pluginFor('a')!.manifest.version, version);
      expect(manager.pluginFor('a')!.editBackup!.toJson(), backup);
      expect(await manager.restoreEditBackup('a'), true);
      expect(await manager.readIfExists('a'), script('a'));
      expect(manager.pluginFor('a')!.manifest.version, '1.0.0');
      expect(await manager.isCustomEdited('a'), false);
      expect(await manager.hasEditBackup('a'), false);
    },
  );

  test(
    'failed online download leaves edited script and backup intact',
    () async {
      await installMarket();
      await manager.saveEditedScript('a', 'edited');
      final before = manager.pluginFor('a')!.toJson();
      offline = true;
      await expectLater(manager.redownload('a'), throwsStateError);
      expect(manager.pluginFor('a')!.toJson(), before);
      expect(await manager.readIfExists('a'), 'edited');
    },
  );

  test(
    'local imports are excluded from online operations and matching market updates',
    () async {
      await manager.importPackage(utf8.encode(script('a')));
      version = '2.0.0';
      await manager.checkStartupUpdates();
      expect(manager.availableUpdates, isEmpty);
      requests.clear();
      expect(await manager.checkUpdate('a'), null);
      expect(
        await assembly.gateways.update.checkActiveSourceVersionFromCloud(),
        null,
      );
      expect(await manager.redownload('a'), false);
      await expectLater(
        manager.installFromRepository(
          sourcePluginsRepositoryUrl,
          manager.entriesFor(sourcePluginsRepositoryUrl).single,
        ),
        throwsA(isA<SourcePluginException>()),
      );
      expect(requests, isEmpty);
      expect(manager.pluginFor('a')!.manifest.version, '1.0.0');
    },
  );

  for (final uninstalling in [false, true]) {
    test(
      'failed ${uninstalling ? 'uninstall' : 'disable'} retains active source, handle and saved preference',
      () async {
        await manager.importPackage(utf8.encode(script('a')));
        await manager.importPackage(utf8.encode(script('b')));
        await assembly.runtimeRegistry.activateSource('b');
        await assembly.ensureSourceInitialized('b');
        await assembly.gateways.script.saveEditedActiveSource(
          '${script('b')}\n// pending edit',
        );
        final handle = assembly.testing.handleFor('b');
        final publishedDirectory = assembly.runtimeRegistry
            .definitionFor('b')
            .pluginDirectory;
        await failCommits();
        await expectLater(
          uninstalling
              ? manager.uninstall('b')
              : manager.setEnabled('b', false),
          throwsA(isA<FileSystemException>()),
        );
        expect(manager.pluginFor('b')!.enabled, true);
        expect(assembly.runtimeRegistry.activeSourceKey, 'b');
        expect(assembly.testing.handleFor('b'), same(handle));
        expect(handle.isDisposed, false);
        expect(
          manager.catalog
              .singleWhere((entry) => entry.key == 'b')
              .pluginDirectory,
          publishedDirectory,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            'active_source_key_v1',
          ),
          'b',
        );
        final restarted = createManager();
        addTearDown(restarted.dispose);
        await restarted.initialize();
        expect(restarted.pluginFor('b')!.enabled, true);
      },
    );
  }

  test(
    'failed catalog application rolls back the committed enabled record',
    () async {
      await manager.importPackage(utf8.encode(script('a')));
      await manager.importPackage(utf8.encode(script('b')));
      await assembly.runtimeRegistry.activateSource('b');
      await assembly.gateways.script.saveEditedActiveSource(
        '${script('b')}\n// pending edit',
      );
      final handle = assembly.testing.handleFor('b');
      final applyCatalog = manager.onCatalogChanged;
      manager.onCatalogChanged = (catalog) async {
        if (!catalog.any((entry) => entry.key == 'b')) {
          throw StateError('selection persistence failed');
        }
        await applyCatalog?.call(catalog);
      };
      await expectLater(manager.setEnabled('b', false), throwsStateError);
      expect(manager.pluginFor('b')!.enabled, true);
      expect(assembly.runtimeRegistry.activeSourceKey, 'b');
      expect(assembly.testing.handleFor('b'), same(handle));
      expect(handle.isDisposed, false);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'active_source_key_v1',
        ),
        'b',
      );
      final restarted = createManager();
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restarted.pluginFor('b')!.enabled, true);
    },
  );
}
