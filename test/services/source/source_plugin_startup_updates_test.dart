import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _script(String id, String version) => utf8.encode(
  "Hazuki.registerSource({id:'$id',name:'Plugin $id',version:'$version',search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SourcePluginManager manager;
  late List<String> requested;
  final versions = <String, String>{};

  Map<String, dynamic> index() => {
    'schemaVersion': 1,
    'plugins': [
      for (final entry in versions.entries)
        {
          'id': entry.key,
          'name': 'Plugin ${entry.key}',
          'version': entry.value,
          'downloadUrl':
              'https://downloads.example/${entry.key}.js?token=a%2Fb',
        },
    ],
  };

  SourcePluginManager createManager({bool offline = false}) =>
      SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
        download: (url) async {
          requested.add(url.toString());
          if (offline) throw StateError('Offline');
          if (url.toString() == sourcePluginsRepositoryUrl) {
            return utf8.encode(jsonEncode(index()));
          }
          final id = url.pathSegments.last.replaceFirst('.js', '');
          return _script(id, versions[id]!);
        },
      );

  Future<List<dynamic>> records() async =>
      (jsonDecode(
                await File(
                  '${directory.path}/${SourcePluginManager.installedPluginsFileName}',
                ).readAsString(),
              )
              as Map)['plugins']
          as List;

  Future<void> installMarket(String id, String version) async {
    versions[id] = version;
    await manager.initialize();
    await manager.installFromRepository(
      sourcePluginsRepositoryUrl,
      SourcePluginIndexEntry(
        id: id,
        name: 'Plugin $id',
        version: version,
        downloadUrl: Uri.parse('https://downloads.example/$id.js?token=a%2Fb'),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'advanced_software_update_source': 'github',
    });
    directory = await Directory.systemTemp.createTemp(
      'hazuki_startup_updates_',
    );
    requested = [];
    versions.clear();
    manager = createManager();
  });
  tearDown(() async {
    manager.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'all plugin identities share one file across installs, updates and uninstall',
    () async {
      await manager.importPackage(_script('a', '1.0.0'));
      expect(await records(), [
        {'id': 'a', 'version': '1.0.0'},
      ]);
      await manager.importPackage(_script('b', '2.0.0'));
      expect(await records(), [
        {'id': 'a', 'version': '1.0.0'},
        {'id': 'b', 'version': '2.0.0'},
      ]);
      await manager.importPackage(_script('a', '1.1.0'));
      expect(await records(), [
        {'id': 'a', 'version': '1.1.0'},
        {'id': 'b', 'version': '2.0.0'},
      ]);
      await manager.uninstall('b');
      expect(await records(), [
        {'id': 'a', 'version': '1.1.0'},
      ]);
      final restored = createManager();
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.installed.single.manifest.id, 'a');
      expect(restored.installed.single.manifest.version, '1.1.0');
      expect(
        await directory
            .list()
            .where((file) => file.path.endsWith('installed_plugins.json'))
            .length,
        1,
      );
    },
  );

  test(
    'startup downloads once and compares every installed ID using numeric versions',
    () async {
      await installMarket('a', '1.9.0');
      await installMarket('b', '2.0.0');
      await manager.setEnabled('b', false);
      await installMarket('c', '3.0.0');
      await manager.importPackage(_script('local', '1.0.0'));
      requested.clear();
      versions.addAll({
        'a': '1.10.0',
        'b': '2.1.0',
        'c': '2.0.0',
        'uninstalled': '99.0.0',
        'local': '99.0.0',
      });
      final restarted = createManager();
      addTearDown(restarted.dispose);
      await Future.wait([
        restarted.checkStartupUpdates(),
        restarted.checkStartupUpdates(),
      ]);
      await restarted.checkStartupUpdates();
      expect(requested, [sourcePluginsRepositoryUrl]);
      expect(restarted.availableUpdates.map((update) => update.entry.id), [
        'a',
        'b',
      ]);
      expect(restarted.availableUpdates.first.localVersion, '1.9.0');
      expect(restarted.availableUpdates.last.plugin.enabled, isFalse);
      expect(await restarted.checkUpdate('a'), isNotNull);
      expect(await restarted.checkUpdate('c'), isNull);
      expect(requested, [sourcePluginsRepositoryUrl]);
      expect(await File('${directory.path}/plugins.json').exists(), isTrue);
      expect(restarted.checkingIndex, isFalse);
      final update = restarted.availableUpdates.first;
      await restarted.installFromRepository(
        sourcePluginsRepositoryUrl,
        update.entry,
      );
      expect(requested.last, 'https://downloads.example/a.js?token=a%2Fb');
      expect(restarted.pluginFor('a')!.repository, sourcePluginsRepositoryUrl);
      expect((await records()).first, {'id': 'a', 'version': '1.10.0'});
      expect(restarted.availableUpdates.map((update) => update.entry.id), [
        'b',
      ]);
    },
  );

  test(
    'startup excludes third-party plugins with matching IDs and preserves their own updates',
    () async {
      const repository = 'https://third-party.example/plugins.json';
      const packageUrl = 'https://third-party.example/c.js';
      var thirdPartyVersion = '1.0.0';
      SourcePluginManager createRepositoryManager() => SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
        download: (url) async {
          requested.add(url.toString());
          if (url.toString() == repository) {
            return utf8.encode(
              jsonEncode({
                'schemaVersion': 1,
                'plugins': [
                  {
                    'id': 'c',
                    'name': 'Third-party C',
                    'version': thirdPartyVersion,
                    'downloadUrl': packageUrl,
                  },
                ],
              }),
            );
          }
          if (url.toString() == packageUrl) {
            return _script('c', thirdPartyVersion);
          }
          if (url.toString() == sourcePluginsRepositoryUrl) {
            return utf8.encode(jsonEncode(index()));
          }
          final id = url.pathSegments.last.replaceFirst('.js', '');
          return _script(id, versions[id]!);
        },
      );

      manager.dispose();
      manager = createRepositoryManager();
      versions.addAll({'a': '1.0.0', 'b': '1.0.0', 'c': '1.0.0'});
      await manager.importPackage(_script('a', '1.0.0'));
      await manager.refreshRepository(sourcePluginsRepositoryUrl);
      await manager.installFromRepository(
        sourcePluginsRepositoryUrl,
        manager
            .entriesFor(sourcePluginsRepositoryUrl)
            .firstWhere((entry) => entry.id == 'b'),
      );
      await manager.addRepository(repository);
      await manager.installFromRepository(
        repository,
        manager.entriesFor(repository).single,
      );

      manager.dispose();
      manager = createRepositoryManager();
      requested.clear();
      versions.addAll({'a': '1.1.0', 'b': '1.1.0', 'c': '9.0.0'});
      thirdPartyVersion = '1.2.0';
      await manager.checkStartupUpdates();
      expect(requested, [sourcePluginsRepositoryUrl]);
      expect(manager.availableUpdates.map((update) => update.entry.id), ['b']);
      expect(manager.pluginFor('c')!.repository, repository);
      expect(manager.pluginFor('c')!.manifest.version, '1.0.0');

      final update = await manager.checkUpdate('c');
      expect(requested.last, repository);
      expect(update!.version, '1.2.0');
      expect(update.downloadUrl.toString(), packageUrl);
      await manager.installFromRepository(repository, update);
      expect(requested.last, packageUrl);
      expect(manager.pluginFor('c')!.repository, repository);
      expect(manager.pluginFor('c')!.manifest.version, '1.2.0');
      expect(manager.availableUpdates.map((update) => update.entry.id), ['b']);
    },
  );

  test(
    'an index failure retains installed records and cached catalog for manual retry',
    () async {
      await manager.importPackage(_script('a', '1.0.0'));
      versions['a'] = '1.1.0';
      await manager.checkStartupUpdates();
      final previousRecords = await records();
      final offline = createManager(offline: true);
      addTearDown(offline.dispose);
      await offline.checkStartupUpdates();
      expect(offline.indexError, contains('Offline'));
      expect(offline.checkingIndex, isFalse);
      expect(offline.installed.single.manifest.version, '1.0.0');
      expect(offline.entriesFor(sourcePluginsRepositoryUrl).single.id, 'a');
      expect(await records(), previousRecords);
      await offline.checkStartupUpdates();
      expect(requested, [
        sourcePluginsRepositoryUrl,
        sourcePluginsRepositoryUrl,
      ]);
      await manager.refreshRepository(sourcePluginsRepositoryUrl);
      expect(manager.indexError, isNull);
    },
  );

  test(
    'failed package validation and failed commits preserve the shared version file',
    () async {
      await manager.importPackage(_script('a', '1.0.0'));
      final previous = await records();
      manager.validatePackage = (_, _) async =>
          throw StateError('Invalid plugin');
      await expectLater(
        manager.importPackage(_script('b', '1.0.0')),
        throwsStateError,
      );
      expect(await records(), previous);
      manager.validatePackage = null;
      await Directory(
        '${directory.path}/${SourcePluginManager.installedPluginsFileName}.pending',
      ).create();
      await expectLater(
        manager.importPackage(_script('a', '2.0.0')),
        throwsA(isA<FileSystemException>()),
      );
      expect(await records(), previous);
      expect(manager.installed.single.manifest.version, '1.0.0');
    },
  );

  test(
    'migrates legacy generations to the unified file without losing plugin state',
    () async {
      await File('${directory.path}/registry-0001.json').writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'repositories': [],
          'installed': [
            {
              'manifest': {
                'id': 'a',
                'name': 'A',
                'version': '1.0.0',
                'apiVersion': 1,
                'entry': 'main.js',
              },
              'directory': 'packages/a',
              'enabled': false,
              'customEdited': true,
            },
          ],
        }),
      );
      await manager.initialize();
      expect(await records(), [
        {'id': 'a', 'version': '1.0.0'},
      ]);
      expect(manager.installed.single.enabled, isFalse);
      expect(manager.installed.single.customEdited, isTrue);
      await manager.uninstall('a');
      final restored = createManager();
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.installed, isEmpty);
      expect(await records(), isEmpty);
    },
  );
}
