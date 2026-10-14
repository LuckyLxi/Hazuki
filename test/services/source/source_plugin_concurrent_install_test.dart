import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

SourcePluginIndexEntry entry(String id) => SourcePluginIndexEntry(
  id: id,
  name: id,
  version: '1.0.0',
  downloadUrl: Uri.parse('https://plugins.fixture.example/$id.js'),
);

List<int> package(String id) => utf8.encode(
  "Hazuki.registerSource({id:'$id',name:'$id',version:'1.0.0',search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final failSlowDownload in [false, true]) {
    test(
      'slow download does not block other installs (failure: $failSlowDownload)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final directory = await Directory.systemTemp.createTemp(
          'hazuki_concurrent_plugins_',
        );
        final slowDownload = Completer<List<int>>();
        final slowStarted = Completer<void>();
        final manager = SourcePluginManager(
          directory: () async => directory,
          legacyDirectories: [],
          download: (url) async {
            if (url.path.endsWith('/slow.js')) {
              slowStarted.complete();
              return slowDownload.future;
            }
            return package('fast');
          },
        );
        addTearDown(() async {
          manager.dispose();
          await directory.delete(recursive: true);
        });
        await manager.initialize();
        final slow = manager.installFromRepository(
          sourcePluginsRepositoryUrl,
          entry('slow'),
        );
        final slowResult = expectLater(
          slow,
          failSlowDownload ? throwsStateError : completes,
        );
        await slowStarted.future.timeout(const Duration(seconds: 5));
        try {
          await manager
              .installFromRepository(sourcePluginsRepositoryUrl, entry('fast'))
              .timeout(const Duration(seconds: 5));
          expect(manager.pluginFor('fast'), isNotNull);
          expect(manager.pluginFor('slow'), isNull);
        } finally {
          if (failSlowDownload) {
            slowDownload.completeError(StateError('download failed'));
          } else {
            slowDownload.complete(package('slow'));
          }
          await slowResult;
        }
        final restored = SourcePluginManager(
          directory: () async => directory,
          legacyDirectories: [],
        );
        addTearDown(restored.dispose);
        await restored.initialize();
        expect(
          restored.installed.map((plugin) => plugin.manifest.id),
          unorderedEquals(['fast', if (!failSlowDownload) 'slow']),
        );
      },
    );
  }

  test('concurrent downloads commit catalog changes serially', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'hazuki_serial_plugin_commits_',
    );
    final firstCommit = Completer<void>();
    final releaseCommit = Completer<void>();
    final secondDownload = Completer<void>();
    final commits = <List<String>>[];
    final manager = SourcePluginManager(
      directory: () async => directory,
      legacyDirectories: [],
      download: (url) async {
        final id = url.pathSegments.last.split('.').first;
        if (id == 'second') secondDownload.complete();
        return package(id);
      },
    );
    addTearDown(() async {
      manager.dispose();
      await directory.delete(recursive: true);
    });
    await manager.initialize();
    manager.onCatalogChanged = (catalog) async {
      commits.add(catalog.map((plugin) => plugin.key).toList());
      if (commits.length == 1) {
        firstCommit.complete();
        await releaseCommit.future;
      }
    };
    final first = manager.installFromRepository(
      sourcePluginsRepositoryUrl,
      entry('first'),
    );
    await firstCommit.future.timeout(const Duration(seconds: 5));
    final second = manager.installFromRepository(
      sourcePluginsRepositoryUrl,
      entry('second'),
    );
    try {
      await secondDownload.future.timeout(const Duration(seconds: 5));
      expect(commits, [
        ['first'],
      ]);
      expect(manager.pluginFor('second'), isNull);
    } finally {
      releaseCommit.complete();
      await Future.wait([first, second]);
    }
    expect(commits, [
      ['first'],
      ['first', 'second'],
    ]);
  });
}
