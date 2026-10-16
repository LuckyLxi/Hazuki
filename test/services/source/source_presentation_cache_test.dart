import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> _plugin(
  String version, {
  bool showTags = true,
  Map<String, dynamic> detailMetadata = const {},
}) => utf8.encode('''
Hazuki.registerSource({id:'custom_metadata',name:'Custom',version:'$version',apiVersion:1,
presentation:{...${jsonEncode(detailMetadata)},showTags:$showTags,listTagGroups:['Genre'],enrichMissingTags:true,
refreshCloudFavorites:true,requiresLogin:true,searchOrders:{new:'New'},
buttons:[{id:'copyComicId',location:'comicDetailInfo'}]},
search:{load:async()=>({comics:[]})},
comic:{loadInfo:async()=>({title:'Comic',chapters:{}}),loadEp:async()=>({images:[]})}});
''');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SourcePluginManager manager;
  SourcePluginManager createManager() =>
      SourcePluginManager(directory: () async => root, legacyDirectories: []);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hazuki_metadata_');
    manager = createManager();
  });
  tearDown(() async {
    manager.dispose();
    await root.delete(recursive: true);
  });

  test(
    'update, disable, uninstall and restart retain only display rules',
    () async {
      await manager.importPackage(_plugin('1.0.0'));
      await manager.importPackage(_plugin('1.0.1', showTags: false));
      await manager.setEnabled('custom_metadata', false);
      expect(manager.catalog, isEmpty);
      expect(manager.historicalPresentationFor('custom_metadata'), {
        'showTags': false,
        'listTagGroups': ['Genre'],
      });
      await manager.uninstall('custom_metadata');
      manager.dispose();
      manager = createManager();
      await manager.initialize();
      expect(manager.installed, isEmpty);
      expect(manager.historicalPresentationFor('custom_metadata'), {
        'showTags': false,
        'listTagGroups': ['Genre'],
      });
      expect(manager.historicalPresentationFor('never_installed'), isEmpty);
    },
  );

  test('failed update restores metadata and plugin version', () async {
    await manager.importPackage(_plugin('1.0.0'));
    var reject = true;
    manager.onCatalogChanged = (_) async {
      if (reject) {
        reject = false;
        throw StateError('reject new catalog');
      }
    };
    await expectLater(
      manager.importPackage(_plugin('1.0.1', showTags: false)),
      throwsStateError,
    );
    expect(manager.pluginFor('custom_metadata')!.manifest.version, '1.0.0');
    expect(
      manager.historicalPresentationFor('custom_metadata')['showTags'],
      true,
    );
    manager.dispose();
    manager = createManager();
    await manager.initialize();
    expect(
      manager.historicalPresentationFor('custom_metadata')['showTags'],
      true,
    );
  });

  test('failed first install does not create historical metadata', () async {
    var reject = true;
    manager.onCatalogChanged = (catalog) async {
      if (catalog.isNotEmpty && reject) {
        reject = false;
        throw StateError('reject install');
      }
    };
    await expectLater(
      manager.importPackage(_plugin('1.0.0')),
      throwsStateError,
    );
    expect(manager.historicalPresentationFor('custom_metadata'), isEmpty);
  });

  test(
    'legacy registry without metadata cache bootstraps from manifests',
    () async {
      await manager.importPackage(_plugin('1.0.0'));
      final registries = await root
          .list()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      final file = registries.single as File;
      final state = jsonDecode(await file.readAsString()) as Map;
      state.remove('historicalPresentations');
      await file.writeAsString(jsonEncode(state));
      manager.dispose();
      manager = createManager();
      await manager.initialize();
      expect(
        manager.historicalPresentationFor('custom_metadata')['showTags'],
        true,
      );
      await manager.uninstall('custom_metadata');
      manager.dispose();
      manager = createManager();
      await manager.initialize();
      expect(
        manager.historicalPresentationFor('custom_metadata')['showTags'],
        true,
      );
    },
  );

  test(
    'runtime separates operational metadata from historical rendering',
    () async {
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await manager.importPackage(_plugin('1.0.0'));
      final registry = assembly.runtimeRegistry;
      expect(
        registry.presentationFor('custom_metadata')['enrichMissingTags'],
        true,
      );
      await manager.setEnabled('custom_metadata', false);
      expect(registry.presentationFor('custom_metadata'), isEmpty);
      expect(registry.displayPresentationFor('custom_metadata'), {
        'showTags': true,
        'listTagGroups': ['Genre'],
      });
      expect(
        registry.displayPresentationFor('custom_metadata')['buttons'],
        isNull,
      );
    },
  );

  test(
    'retired detail fields are excluded from historical display rules',
    () async {
      const detailMetadata = {
        'showUploader': false,
        'showCategories': true,
        'showChineseTeam': true,
        'detailTagGroups': ['Genre'],
      };
      await manager.importPackage(
        _plugin('1.0.0', detailMetadata: detailMetadata),
      );
      await manager.uninstall('custom_metadata');
      manager.dispose();
      manager = createManager();
      await manager.initialize();
      expect(manager.historicalPresentationFor('custom_metadata'), {
        'showTags': true,
        'listTagGroups': ['Genre'],
      });
      expect(manager.installed, isEmpty);
      expect(manager.catalog, isEmpty);
    },
  );

  test('new presentation fields reject invalid values', () {
    for (final value in [
      {
        'listTagGroups': [123],
      },
      {'enrichMissingTags': 'true'},
      {'showComments': 'true'},
      {'showComments': null},
      {'showComments': 1},
      {
        'favoriteOrderAliases': {'old': 1},
      },
      {
        'localFavoriteOrders': {'custom': 'unknown'},
      },
    ]) {
      expect(
        () => SourcePluginManifest.fromJson({
          'id': 'custom',
          'name': 'Custom',
          'version': '1.0.0',
          'entry': 'main.js',
          'presentation': value,
        }),
        throwsA(isA<SourcePluginException>()),
      );
    }
  });
}
