import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:hazuki/shared/preferences/software_update_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _indexUrls = {
  SoftwareUpdateSource.jsDelivr:
      'https://cdn.jsdelivr.net/gh/LuckyLxi/Sources@main/plugins.json',
  SoftwareUpdateSource.github: sourcePluginsRepositoryUrl,
  SoftwareUpdateSource.ghproxy:
      'https://ghproxy.net/https://raw.githubusercontent.com/LuckyLxi/Sources/main/plugins.json',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('hazuki_builtin_index_');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'fresh manager exposes the built-in index without downloading scripts',
    () async {
      final manager = SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
        download: (_) async =>
            throw StateError('Initialization must stay offline'),
      );
      addTearDown(manager.dispose);
      await manager.initialize();
      expect(manager.repositories, [sourcePluginsRepositoryUrl]);
      expect(manager.installed, isEmpty);
      await expectLater(
        manager.removeRepository(sourcePluginsRepositoryUrl),
        throwsException,
      );
      expect(manager.repositories, [sourcePluginsRepositoryUrl]);
    },
  );

  for (final source in SoftwareUpdateSource.values) {
    test(
      '${source.name} routes only the index and preserves install/update download URLs',
      () async {
        const packageUrl =
            'https://cdn.jsdelivr.net/gh/LuckyLxi/Sources@main/fixture.js?token=abc%2Fdef&v=1';
        var version = '1.0.0';
        final requested = <String>[];
        final manager = SourcePluginManager(
          directory: () async => directory,
          legacyDirectories: [],
          download: (url) async {
            requested.add(url.toString());
            if (_indexUrls.values.contains(url.toString())) {
              return utf8.encode(
                jsonEncode({
                  'schemaVersion': 1,
                  'plugins': [
                    {
                      'id': 'fixture',
                      'name': 'Fixture',
                      'version': version,
                      'downloadUrl': packageUrl,
                    },
                  ],
                }),
              );
            }
            if (url.toString() != packageUrl) {
              throw StateError('Download URL was rewritten');
            }
            return utf8.encode(
              "Hazuki.registerSource({id:'fixture',name:'Fixture',version:'$version',search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
            );
          },
        );
        addTearDown(manager.dispose);
        await manager.setUpdateSource(source);
        await manager.initialize();
        await manager.refreshRepository(sourcePluginsRepositoryUrl);
        expect(requested, [_indexUrls[source]]);
        expect(manager.installed, isEmpty);
        await manager.installFromRepository(
          sourcePluginsRepositoryUrl,
          manager.entriesFor(sourcePluginsRepositoryUrl).single,
        );
        expect(requested.last, packageUrl);
        expect(manager.installed.single.repository, sourcePluginsRepositoryUrl);

        final nextSource = SoftwareUpdateSource
            .values[(source.index + 1) % SoftwareUpdateSource.values.length];
        await manager.setUpdateSource(nextSource);
        version = '1.1.0';
        await manager.refreshRepository(sourcePluginsRepositoryUrl);
        final update = await manager.checkUpdate('fixture');
        expect(requested.last, _indexUrls[nextSource]);
        expect(update!.downloadUrl.toString(), packageUrl);
        await manager.installFromRepository(sourcePluginsRepositoryUrl, update);
        expect(requested, [
          _indexUrls[source],
          packageUrl,
          _indexUrls[nextSource],
          packageUrl,
        ]);
        expect(manager.installed.single.manifest.version, '1.1.0');
        expect(manager.installed.single.repository, sourcePluginsRepositoryUrl);
        expect(await manager.loadUpdateSource(), nextSource);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(hazukiSoftwareUpdateSourcePreferenceKey),
          nextSource.preferenceValue,
        );

        final restored = SourcePluginManager(
          directory: () async => directory,
          legacyDirectories: [],
        );
        addTearDown(restored.dispose);
        await restored.initialize();
        expect(restored.repositories, [sourcePluginsRepositoryUrl]);
        expect(
          restored.installed.single.repository,
          sourcePluginsRepositoryUrl,
        );
        expect(await restored.loadUpdateSource(), nextSource);
      },
    );
  }

  test(
    'index route resolver leaves package and unrelated index URLs unchanged',
    () {
      for (final address in [
        'https://cdn.jsdelivr.net/gh/LuckyLxi/Sources@main/fixture.js',
        'https://raw.githubusercontent.com/LuckyLxi/Sources/main/fixture.js',
        'https://downloads.example/plugin.js?signature=a%2Fb',
        'https://another.example/plugins.json',
      ]) {
        final url = Uri.parse(address);
        for (final source in SoftwareUpdateSource.values) {
          expect(resolveSourcePluginIndexUrl(url, source), same(url));
        }
      }
    },
  );

  test(
    'legacy built-in repository aliases keep the same installed identity',
    () async {
      final alias = _indexUrls[SoftwareUpdateSource.jsDelivr]!;
      await File('${directory.path}/registry-0001.json').writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'repositories': [alias, sourcePluginsRepositoryUrl],
          'installed': [
            {
              'manifest': {
                'id': 'fixture',
                'name': 'Fixture',
                'version': '1.0.0',
                'apiVersion': 1,
                'entry': 'main.js',
              },
              'directory': 'packages/fixture',
              'repository': alias,
              'enabled': false,
              'customEdited': true,
            },
          ],
        }),
      );
      final manager = SourcePluginManager(
        directory: () async => directory,
        legacyDirectories: [],
      );
      addTearDown(manager.dispose);
      await manager.initialize();
      expect(manager.repositories, [sourcePluginsRepositoryUrl]);
      expect(manager.installed.single.repository, sourcePluginsRepositoryUrl);
      expect(manager.installed.single.enabled, isFalse);
      expect(manager.installed.single.customEdited, isTrue);
    },
  );
}
