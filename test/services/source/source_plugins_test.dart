import 'dart:async';
import 'package:hazuki/services/source/gateways/source_content_gateways.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<int> package({
  String id = 'independent',
  String version = '1.0.0',
  String? script,
  String? entry,
  int apiVersion = 1,
}) {
  final implementation =
      script ??
      "Hazuki.registerSource({search:{load:async(k,o,p)=>({comics:[{id:'a',title:k,cover:''}],maxPage:1})},comic:{loadInfo:async(id)=>({id,title:'Comic',chapters:{'c':'Chapter'},tags:{}}),loadEp:async()=>({images:[]})}});";
  final identity = jsonEncode({
    'id': id,
    'name': 'Independent',
    'version': version,
    'apiVersion': apiVersion,
    'entry': ?entry,
  });
  return utf8.encode(
    implementation.replaceFirst(
      'Hazuki.registerSource({',
      'Hazuki.registerSource({...$identity,',
    ),
  );
}

void main() {
  test('declared buttons require callbacks supplied by that plugin', () async {
    SharedPreferences.setMockInitialValues({});
    final inspector = SourcePluginScriptInspector();
    for (final declaration in [
      "{id:'checkIn',location:'homeProfile'}",
      "{id:'resetDeviceInfo',location:'advanced',action:'missing'}",
    ]) {
      await expectLater(
        inspector.inspect('''
Hazuki.registerSource({id:'buttons',presentation:{buttons:[$declaration]},
search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({title:'',chapters:{}}),loadEp:async()=>({images:[]})}});
'''),
        throwsA(isA<SourcePluginException>()),
      );
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SourcePluginManager manager;
  final downloads = <String, List<int>>{};
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hazuki_plugins_');
    downloads.clear();
    manager = SourcePluginManager(
      directory: () async => root,
      legacyDirectories: [],
      download: (url) async =>
          downloads[url.toString()] ?? (throw StateError('download failed')),
    );
  });
  tearDown(() async {
    manager.dispose();
    await root.delete(recursive: true);
  });

  test(
    'declared login methods use local inspection and the real isolated runtime loader',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => root.path,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            ),
      );
      final storage = MemorySourceSecureSessionStorage();
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: storage,
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(
        package(
          script: '''Hazuki.registerSource({
      init:async()=>{await Hazuki.storage.set('initRan',true);},
      search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({title:'Comic'}),loadEp:async()=>({images:[]})},
      account:{loginMethods:[{id:'sms',title:{en:'SMS',zh:'短信'},input:'account'}],
        login:async(a,p,ctx)=>{
          const code=await ctx.requestText({title:'SMS code'});
          if(a!=='phone'||p!==''||code!=='1234'||ctx.method!=='sms')throw Error('wrong input');
          await Hazuki.secrets.set('session','private-session');
          return {token:'session',displayName:'User'};
        }}});''',
        ),
      );
      final gateway = assembly.gateways.home as SourceInteractiveAccountGateway;
      expect((await gateway.loadLoginMethods()).single.id, 'sms');
      final before = assembly.testing.handleFor('independent');
      expect(before.facade.loadSourceData('independent', 'initRan'), isNull);
      await gateway.loginInteractive(
        account: 'phone',
        password: '',
        method: 'sms',
        cancellation: SourceLoginCancellation(),
        present: (request, _) async {
          expect(
            before.facade.loadSourceData('independent', 'initRan'),
            isNull,
          );
          return '1234';
        },
      );
      expect(assembly.gateways.home.isLogged, isTrue);
      expect(assembly.gateways.home.currentAccount, 'User');
      expect(assembly.testing.handleFor('independent'), isNot(same(before)));
      expect(
        storage.values['hazuki_plugin_secret_v1:independent:session'],
        'private-session',
      );
      await assembly.gateways.home.logout();
      expect(assembly.gateways.home.isLogged, isFalse);
    },
  );

  test(
    'new callbacks preserve group order and report progress only for logged-in readers',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => root.path,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            ),
      );
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(
        package(
          script: '''Hazuki.registerSource({
      search:{load:async()=>({comics:[]})},
      comic:{loadInfo:async id=>new ComicDetails({title:'Grouped',chapterGroups:[
        {id:'a',title:'Serial',chapters:[{id:'10',title:'First'},{id:'2',title:'Second'}]},
        {id:'b',title:'Other',chapters:[{id:'1',title:'Other'}]}]}),
      loadEp:async()=>({images:['image']}),
      onReadingProgress:async p=>{
        await Hazuki.delay(5);
        const events=Hazuki.storage.get('events') ?? [];
        events.push(p);
        await Hazuki.storage.set('events',events);
        if(p.page===2) throw Error('sync failure');
      }}});''',
        ),
      );
      await assembly.runtimeRegistry.ensureInitialized(
        sourceKey: 'independent',
      );
      final details = await assembly.gateways.reader.loadComicDetails('comic');
      expect(details.chapters.keys, ['10', '2', '1']);
      final handle = assembly.testing.handleFor('independent');
      final reporter = assembly.gateways.reader as SourceReadingProgressGateway;
      Map<String, Object> event(int page, String reason) => {
        'comicId': 'comic',
        'chapterId': '10',
        'page': page,
        'totalPages': 3,
        'visiblePages': [page],
        'reason': reason,
      };
      await reporter.reportReadingProgress(
        event(1, 'initial'),
        sourceKey: 'independent',
      );
      await assembly.gateways.reader.loadChapterImages(
        comicId: 'comic',
        epId: '10',
      );
      expect(handle.facade.loadSourceData('independent', 'events'), isNull);
      await handle.facade.saveSourceData('independent', 'account', [
        'user',
        'password',
      ]);
      await assembly.gateways.reader.loadChapterImages(
        comicId: 'comic',
        epId: '10',
      );
      expect(handle.facade.loadSourceData('independent', 'events'), isNull);
      await Future.wait([
        reporter.reportReadingProgress(
          event(1, 'initial'),
          sourceKey: 'independent',
        ),
        reporter.reportReadingProgress(
          event(2, 'chapter'),
          sourceKey: 'independent',
        ),
        reporter.reportReadingProgress(
          event(3, 'initial'),
          sourceKey: 'independent',
        ),
      ]);
      final events =
          handle.facade.loadSourceData('independent', 'events') as List;
      expect(events.map((e) => e['page']), [1, 2, 3]);
      await handle.facade.deleteSourceData('independent', 'account');
      await reporter.reportReadingProgress(
        event(1, 'exit'),
        sourceKey: 'independent',
      );
      expect(
        (handle.facade.loadSourceData('independent', 'events') as List),
        hasLength(3),
      );
      await handle.facade.saveSourceData(
        'independent',
        'login_session',
        'browser-session',
      );
      await reporter.reportReadingProgress(
        event(1, 'initial'),
        sourceKey: 'independent',
      );
      expect(
        (handle.facade.loadSourceData('independent', 'events') as List),
        hasLength(4),
      );
      await handle.facade.deleteSourceData('independent', 'login_session');
    },
  );

  test(
    'fresh registry stays empty and persists enable/uninstall state',
    () async {
      await manager.initialize();
      expect(manager.catalog, isEmpty);
      await manager.importPackage(package());
      expect(manager.catalog.single.key, 'independent');
      final scriptFile = await manager.sourceFileFor('independent');
      expect(
        (await scriptFile.parent.list().toList()).map(
          (file) => file.uri.pathSegments.last,
        ),
        ['main.js'],
      );
      await manager.setEnabled('independent', false);
      expect(manager.catalog, isEmpty);
      final restored = SourcePluginManager(
        directory: () async => root,
        legacyDirectories: [],
      );
      await restored.initialize();
      expect(restored.installed.single.enabled, false);
      await restored.setEnabled('independent', true);
      await restored.uninstall('independent');
      expect(restored.installed, isEmpty);
      restored.dispose();
      expect(await (await manager.sourceFileFor('independent')).exists(), true);
    },
  );

  test(
    'rejects incompatible or malformed JS and missing runtime methods',
    () async {
      for (final bytes in [
        package(apiVersion: 2),
        <int>[1, 2, 3],
        <int>[0xff, 0xfe],
        <int>[0x50, 0x4b, 0x03, 0x04],
        utf8.encode('/* @hazuki-plugin\n{bad json}\n*/'),
        utf8.encode('Hazuki.registerSource({id:"without_metadata"});'),
      ]) {
        await expectLater(manager.importPackage(bytes), throwsA(anything));
        expect(manager.installed, isEmpty);
      }
      expect(await File('${root.parent.path}/escape.txt').exists(), false);
    },
  );

  test(
    'invalid ID rules reject imports and leave installed updates intact',
    () async {
      for (final rule in [r'(?:\d+)', '(']) {
        final script =
            "Hazuki.registerSource({presentation:{directComicIdRules:{patterns:[${jsonEncode(rule)}],extractDigits:true}},search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});";
        await expectLater(
          manager.importPackage(package(script: script)),
          throwsA(isA<SourcePluginException>()),
        );
        expect(manager.installed, isEmpty);
      }
      await manager.importPackage(package());
      final original = await (await manager.sourceFileFor(
        'independent',
      )).readAsString();
      await expectLater(
        manager.importPackage(
          package(
            version: '2.0.0',
            script:
                "Hazuki.registerSource({presentation:{directComicIdRules:{patterns:['no_capture'],extractDigits:true}},search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
          ),
        ),
        throwsA(isA<SourcePluginException>()),
      );
      expect(manager.installed.single.manifest.version, '1.0.0');
      expect(
        await (await manager.sourceFileFor('independent')).readAsString(),
        original,
      );
    },
  );

  test('runtime reads new capabilities independently of plugin identity', () async {
    final assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    addTearDown(assembly.dispose);
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    await manager.importPackage(
      package(
        script:
            r"Hazuki.registerSource({presentation:{directComicIdRules:{patterns:['^book-(\\d+)$'],extractDigits:true},dailyRecommendation:{searchOrder:'recent'}},search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
      ),
    );
    final search = assembly.gateways.search;
    final recommendation = assembly.gateways.dailyRecommendation;
    expect(search.supportsDirectComicId, isTrue);
    expect(
      search.directComicIdRulesForSource('independent')!.match('BOOK-123'),
      '123',
    );
    expect(recommendation.supportsDailyRecommendation, isTrue);
    expect(
      recommendation.dailyRecommendationForSource('independent')!.searchOrder,
      'recent',
    );
    await manager.importPackage(
      package(
        version: '2.0.0',
        script:
            "Hazuki.registerSource({presentation:{directComicId:true},search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
      ),
    );
    expect(search.supportsDirectComicId, isFalse);
    expect(recommendation.supportsDailyRecommendation, isFalse);
  });

  test(
    'accepts BOM, ordinary comments and code without a metadata header',
    () async {
      final script = utf8.decode(package());
      expect(
        (await SourcePluginScriptInspector().inspect('\uFEFF \n$script')).id,
        'independent',
      );
      expect(
        (await SourcePluginScriptInspector().inspect(
          '/* @hazuki-plugin {bad json} */\nconst code = 1;\n$script',
        )).id,
        'independent',
      );
    },
  );

  test(
    'source entry fields do not control the installed script path',
    () async {
      await manager.importPackage(package(entry: '../escape.js'));
      expect(manager.installed.single.manifest.entry, 'main.js');
      expect(
        (await manager.sourceFileFor('independent')).uri.pathSegments.last,
        'main.js',
      );
    },
  );

  test(
    'registers a class source without headers or a registration call',
    () async {
      const script = """
class PlainSource extends HazukiSource {
  key = ['plain', 'source'].join('_');
  search = {load: async () => ({comics: [], maxPage: 1})};
  comic = {
    loadInfo: async id => new ComicDetails({title: 'Comic', chapters: {}, tags: {}, viewsCount: 12, headerStats: [{text: {zh: '每周更新', en: 'Weekly'}}], infoFields: [{label: {zh: '状态', en: 'Status'}, values: 'Ongoing'}]}),
    loadEp: async () => ({images: []})
  };
}
""";
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(utf8.encode(script));
      expect(manager.installed.single.manifest.id, 'plain_source');
      expect(manager.installed.single.manifest.name, 'plain_source');
      expect(manager.installed.single.manifest.version, '0.0.0');
      final details = await assembly.gateways.reader.loadComicDetails(
        'comic',
        sourceKey: 'plain_source',
      );
      expect(details.infoFields.single.label, {'zh': '状态', 'en': 'Status'});
      expect(details.infoFields.single.values, ['Ongoing']);
      expect(details.viewsCount, '12');
      expect(details.headerStats.single.text, {'zh': '每周更新', 'en': 'Weekly'});
      await assembly.runtimeRegistry.ensureInitialized(
        sourceKey: 'plain_source',
      );
      expect(
        (await assembly.gateways.search.searchComics(
          keyword: '',
          page: 1,
        )).comics,
        isEmpty,
      );
    },
  );

  test('local plugins may use a version label instead of SemVer', () async {
    await manager.importPackage(package(version: 'nightly'));
    expect(manager.installed.single.manifest.version, 'nightly');
  });

  test('inspection does not run init or modify source data', () async {
    final source = utf8.decode(
      package(
        script:
            "Hazuki.registerSource({init:()=>{throw new Error('must not run');},search:{load:()=>({comics:[]})},comic:{loadInfo:()=>({}),loadEp:()=>({images:[]})}});",
      ),
    );
    expect(
      (await SourcePluginScriptInspector().inspect(source)).id,
      'independent',
    );
    await expectLater(
      SourcePluginScriptInspector().inspect(
        "$source\nHazuki.storage.set('account', ['injected']);",
      ),
      throwsA(anything),
    );
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('import defers init and its side effects until first use', () async {
    final assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    addTearDown(assembly.dispose);
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    await manager.importPackage(
      package(
        script: """
Hazuki.registerSource({
  settings: {label: {default: 'Ready'}},
  async init() {
    const runs = Hazuki.storage.get('init_runs') || 0;
    await Hazuki.storage.set('init_runs', runs + 1);
    this.label = Hazuki.settings.get('label');
  },
  search: {load: async () => ({comics: [{id: 'a', title: globalThis.__hazuki_source.label, cover: ''}], maxPage: 1})},
  comic: {loadInfo: async () => ({}), loadEp: async () => ({images: []})}
});
""",
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('source_data_independent'), isNull);
    final handle = assembly.testing.handleFor('independent');
    expect(handle.runtime.engine, isNull);

    final result = await assembly.gateways.search.searchComics(
      keyword: 'query',
      page: 1,
    );
    expect(result.comics.single.title, 'Ready');
    expect(handle.facade.loadSourceData('independent', 'init_runs'), 1);
    await assembly.gateways.search.searchComics(keyword: 'query', page: 1);
    expect(handle.facade.loadSourceData('independent', 'init_runs'), 1);
  });

  test('init failure is reported on first use and keeps the package', () async {
    final assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    addTearDown(assembly.dispose);
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    await manager.importPackage(
      package(
        script:
            "Hazuki.registerSource({init:async()=>{throw new Error('init unavailable');},search:{load:async()=>({comics:[]})},comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});",
      ),
    );
    expect(manager.installed.single.manifest.id, 'independent');
    expect(manager.errors, isEmpty);
    await expectLater(
      assembly.gateways.search.searchComics(keyword: '', page: 1),
      throwsA(anything),
    );
    expect(manager.errors['independent'], contains('init unavailable'));
    expect(manager.installed.single.manifest.id, 'independent');
    expect(await (await manager.sourceFileFor('independent')).exists(), isTrue);
  });

  test(
    'SDK defaults remain live and stored falsy values take precedence',
    () async {
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(package());
      await assembly.ensureSourceInitialized('independent');
      final handle = assembly.testing.handleFor('independent');
      final engine = handle.runtime.engine!;
      engine.evaluate(
        "globalThis.__hazuki_source.settings.option = {default:'initial'}",
      );
      expect(engine.evaluate("Hazuki.settings.get('option')"), 'initial');
      engine.evaluate(
        "globalThis.__hazuki_source.settings.option.default = 'refreshed'",
      );
      expect(engine.evaluate("Hazuki.settings.get('option')"), 'refreshed');
      for (final value in [false, 0, '', null]) {
        await handle.facade.js.resolve(
          engine.evaluate(
            "Hazuki.settings.set('option', ${jsonEncode(value)})",
          ),
        );
        expect(engine.evaluate("Hazuki.settings.get('option')"), value);
      }
    },
  );

  test(
    'placed actions run in their own plugin without switching sources',
    () async {
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(package());
      await manager.importPackage(
        package(
          id: 'extension',
          script: """
Hazuki.registerSource({
  presentation: {actions: [{id: 'mark', title: 'Mark', location: 'lines'}]},
  settings: {option: {title: 'Option', type: 'switch', default: false, location: 'lines', onChanged: async value => {await Hazuki.storage.set('changed', value);}}},
  actions: {mark: async () => {await Hazuki.storage.set('marker', 'private'); return 'done';}},
  search: {load: async () => ({comics: []})},
  comic: {loadInfo: async () => ({}), loadEp: async () => ({images: []})}
});
""",
        ),
      );
      expect(assembly.runtimeRegistry.activeSourceKey, 'independent');
      expect(
        await assembly.pluginGateway.runAction('extension', 'mark'),
        'done',
      );
      expect(assembly.runtimeRegistry.activeSourceKey, 'independent');
      expect(
        assembly.testing
            .handleFor('extension')
            .facade
            .loadSourceData('extension', 'marker'),
        'private',
      );
      expect(
        assembly.testing
            .handleFor('independent')
            .facade
            .loadSourceData('independent', 'marker'),
        isNull,
      );
      await assembly.pluginGateway.saveSetting('extension', 'option', true);
      expect(assembly.pluginGateway.loadSetting('extension', 'option'), isTrue);
      expect(
        assembly.testing
            .handleFor('extension')
            .facade
            .loadSourceData('extension', 'changed'),
        isTrue,
      );
      await manager.setEnabled('extension', false);
      await expectLater(
        assembly.pluginGateway.runAction('extension', 'mark'),
        throwsA(anything),
      );
    },
  );

  for (final id in ['example', 'jm', 'copy_manga', 'picacg']) {
    test(
      'imports the $id source file directly without a metadata header',
      () async {
        final script = File('test/fixtures/source_plugins/$id/main.js');
        expect(await script.readAsString(), isNot(contains('@hazuki-plugin')));
        await manager.importPackage(await script.readAsBytes());
        final manifest = manager.installed.single.manifest;
        expect(manifest.id, id);
        expect(manifest.version, switch (id) {
          'example' => '1.0.0',
          'jm' => '1.0.4',
          'picacg' => '1.0.3',
          _ => '1.0.2',
        });
        expect(manifest.presentation['searchDefaultOrder'], isNotEmpty);
      },
    );
  }

  test('registered identity stays fixed for SDK storage calls', () async {
    final assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    addTearDown(assembly.dispose);
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    await manager.importPackage(package());
    await assembly.runtimeRegistry.ensureInitialized(sourceKey: 'independent');
    final handle = assembly.testing.handleFor('independent');
    final engine = handle.runtime.engine!;
    expect(
      () => engine.evaluate(
        "'use strict'; globalThis.__hazuki_source.key = 'other';",
      ),
      throwsA(anything),
    );
    await handle.facade.js.resolve(
      engine.evaluate("Hazuki.storage.set('marker', 'private')"),
    );
    expect(engine.evaluate("Hazuki.storage.get('marker')"), 'private');
    expect(handle.facade.loadSourceData('independent', 'marker'), 'private');
  });

  test('failed validation retains old package and custom edits', () async {
    await manager.importPackage(package());
    await manager.write('independent', 'edited');
    await manager.setCustomEdited('independent', true);
    final old = await manager.sourceFileFor('independent');
    manager.validatePackage = (_, _) async =>
        throw StateError('invalid registration');
    await expectLater(
      manager.importPackage(package(version: '2.0.0')),
      throwsStateError,
    );
    expect((await manager.sourceFileFor('independent')).path, old.path);
    expect(await manager.readIfExists('independent'), 'edited');
    expect(await manager.isCustomEdited('independent'), true);
  });

  test('reads GitHub default branch, list first, selected JS second', () async {
    downloads['https://api.github.com/repos/author/sources'] = utf8.encode(
      '{"default_branch":"dev"}',
    );
    const index =
        'https://raw.githubusercontent.com/author/sources/dev/plugins.json';
    downloads[index] = utf8.encode(
      '{"schemaVersion":1,"plugins":[{"id":"independent","name":"Independent","version":"1.0.0","downloadUrl":"https://downloads.example/plugin.js"}]}',
    );
    final repository = await manager.addRepository(
      'https://github.com/author/sources',
    );
    expect(repository, index);
    expect(manager.installed, isEmpty);
    downloads['https://downloads.example/plugin.js'] = package();
    await manager.installFromRepository(
      repository,
      manager.entriesFor(repository).single,
    );
    expect(manager.installed.single.repository, index);
    await manager.removeRepository(repository);
    expect(manager.installed, hasLength(1));
  });

  test('branches with slash and custom index paths are encoded', () async {
    final result = await manager.resolveRepository(
      'https://github.com/a/b',
      branch: 'feature/plugins',
      path: 'sources/plugins.json',
    );
    expect(result.pathSegments, [
      'a',
      'b',
      'feature/plugins',
      'sources',
      'plugins.json',
    ]);
    expect(
      (await manager.resolveRepository(
        'https://github.com/a/b/blob/main/list.json',
      )).path,
      '/a/b/main/list.json',
    );
  });

  test('tree and blob URLs consume the entire explicit branch', () async {
    for (final (address, path, expectedPath) in [
      ('tree/feature/plugins', 'plugins.json', 'plugins.json'),
      ('tree/feature/plugins/sources', 'index.json', 'sources/index.json'),
      (
        'blob/feature/plugins/sources/index.json',
        'plugins.json',
        'sources/index.json',
      ),
      ('tree/main/sources', 'plugins.json', 'sources/plugins.json'),
    ]) {
      final result = await manager.resolveRepository(
        'https://github.com/a/b/$address',
        branch: 'feature/plugins',
        path: path,
      );
      expect(result.pathSegments, [
        'a',
        'b',
        'feature/plugins',
        ...expectedPath.split('/'),
      ]);
    }
  });

  test(
    'rejects package/index identity mismatch and cross-source takeover',
    () async {
      const repository = 'https://example.com/plugins.json';
      downloads[repository] = utf8.encode(
        '{"schemaVersion":1,"plugins":[{"id":"independent","name":"Independent","version":"1.0.0","downloadUrl":"https://example.com/plugin.js"}]}',
      );
      await manager.addRepository(repository);
      downloads['https://example.com/plugin.js'] = package(id: 'different');
      await expectLater(
        manager.installFromRepository(
          repository,
          manager.entriesFor(repository).single,
        ),
        throwsA(isA<SourcePluginException>()),
      );
      await manager.importPackage(package());
      downloads['https://example.com/plugin.js'] = package();
      await expectLater(
        manager.installFromRepository(
          repository,
          manager.entriesFor(repository).single,
        ),
        throwsA(isA<SourcePluginException>()),
      );
      expect(manager.installed.single.repository, null);
    },
  );

  test(
    'network failure and callback failure roll back package registry',
    () async {
      await manager.importPackage(package());
      final old = manager.installed.single;
      manager.onCatalogChanged = (catalog) async {
        if (catalog.single.pluginVersion == '2.0.0') {
          throw StateError('runtime switch failed');
        }
      };
      await expectLater(
        manager.importPackage(package(version: '2.0.0')),
        throwsStateError,
      );
      expect(manager.installed.single.directory, old.directory);
      await expectLater(
        manager.addRepository('https://example.com/missing.json'),
        throwsStateError,
      );
      expect(manager.repositories, [sourcePluginsRepositoryUrl]);
    },
  );

  test(
    'legacy scripts are backed up once without modifying originals',
    () async {
      final legacy = Directory('${root.path}/legacy')..createSync();
      File('${legacy.path}/jm.js').writeAsStringSync('custom old script');
      final migration = SourcePluginManager(
        directory: () async => Directory('${root.path}/new'),
        legacyDirectories: [legacy],
      );
      await migration.initialize();
      expect(
        await File('${root.path}/new/legacy_backup/0/jm.js').readAsString(),
        'custom old script',
      );
      expect(
        await File('${legacy.path}/jm.js').readAsString(),
        'custom old script',
      );
      expect(migration.installed, isEmpty);
      migration.dispose();
    },
  );

  test('semver and index validation handle prereleases and duplicate ids', () {
    expect(comparePluginVersions('2.0.0', '1.9.9'), greaterThan(0));
    expect(comparePluginVersions('1.0.0', '1.0.0-beta.2'), greaterThan(0));
    expect(comparePluginVersions('1.0.0-beta.2', '1.0.0-beta.11'), lessThan(0));
    expect(
      () => parsePluginIndex('{"schemaVersion":2,"plugins":[]}'),
      throwsA(isA<SourcePluginException>()),
    );
  });

  test(
    'uninstalled source data stays associated with the same plugin id',
    () async {
      final secure = MemorySourceSecureSessionStorage();
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: secure,
      );
      // A real package is validated and run by the same QuickJS host as the app.
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      expect(assembly.runtimeRegistry.activeSourceKey, null);
      await manager.importPackage(package());
      final handle = assembly.testing.handleFor('independent');
      await handle.session.ensurePrefs();
      await handle.facade.saveSourceData('independent', 'account', [
        'user',
        'password',
      ]);
      await manager.uninstall('independent');
      expect(assembly.runtimeRegistry.activeSourceKey, null);
      await manager.importPackage(package());
      final restored = assembly.testing.handleFor('independent');
      await restored.session.ensurePrefs();
      expect(restored.facade.loadAccountDataSync(), ['user', 'password']);
      // Manager belongs to the test; dispose the host separately at teardown.
      addTearDown(
        () => assembly.testing.handleFor('independent').requestDispose(),
      );
    },
  );

  test(
    'deleting an inactive plugin through runtime operations preserves its backup',
    () async {
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(package());
      await manager.importPackage(package(id: 'inactive'));
      await manager.setCustomEdited('inactive', true);
      await assembly.runtimeRegistry.ensureInitialized(sourceKey: 'inactive');
      final handle = assembly.testing.handleFor('inactive');
      final backup = await manager.sourceFileFor('inactive');
      final content = await backup.readAsString();

      await assembly.testing.runtimeOperations.deleteLocalSourceFile(
        'inactive',
      );

      expect(manager.pluginFor('inactive'), isNull);
      expect(assembly.runtimeRegistry.activeSourceKey, 'independent');
      expect(assembly.runtimeRegistry.allowedSources.map((s) => s.key), [
        'independent',
      ]);
      expect(handle.isDisposed, isTrue);
      expect(await backup.readAsString(), content);
    },
  );

  test(
    'invalid native update keeps the previous registration and emits the final catalog',
    () async {
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      final catalogs = <List<String>>[];
      assembly.gateways.search.addListener(
        () => catalogs.add(
          assembly.gateways.search.allowedSources.map((s) => s.key).toList(),
        ),
      );
      await manager.importPackage(package());
      expect(catalogs.last, ['independent']);
      await expectLater(
        manager.importPackage(
          package(version: '2.0.0', script: 'Hazuki.registerSource({});'),
        ),
        throwsA(anything),
      );
      expect(manager.installed.single.manifest.version, '1.0.0');
      await manager.setEnabled('independent', false);
      expect(catalogs.last, isEmpty);
    },
  );

  test(
    'new plugin searches, reads details and loads local chapter bytes',
    () async {
      final image = File('${root.path}/page.png');
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZQ0AAAAASUVORK5CYII=',
      );
      await image.writeAsBytes(bytes);
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(assembly.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => root.path,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            ),
      );
      await assembly.runtimeRegistry.loadActiveSourcePreference();
      await manager.importPackage(
        package(
          script:
              "Hazuki.registerSource({resources:{'about.txt':'embedded'},search:{load:async(k)=>({comics:[{id:'a',title:k,cover:''}],maxPage:1})},comic:{loadInfo:async(id)=>({id,title:'Comic',chapters:{'c':'Chapter'},tags:{}}),loadEp:async()=>({images:['https://fixture.example/page.png']}),transformImageBytes:async(bytes)=>({bytes,extension:'png'})}});",
        ),
      );
      assembly.testing.handleFor('independent').dio.httpClientAdapter =
          _ImageAdapter(bytes);
      await assembly.runtimeRegistry.ensureInitialized(
        sourceKey: 'independent',
      );
      final engine = assembly.testing.handleFor('independent').runtime.engine!;
      expect(
        await engine.evaluate("Hazuki.resources.readText('about.txt')"),
        'embedded',
      );
      await expectLater(
        engine.evaluate("Hazuki.resources.readText('toString')")
            as Future<dynamic>,
        throwsA(anything),
      );
      expect(
        (await assembly.gateways.search.searchComics(
          keyword: 'hello',
          page: 1,
        )).comics.single.title,
        'hello',
      );
      expect((await assembly.gateways.reader.loadComicDetails('a')).chapters, {
        'c': 'Chapter',
      });
      expect(
        await assembly.gateways.reader.loadChapterImages(
          comicId: 'a',
          epId: 'c',
        ),
        ['https://fixture.example/page.png'],
      );
      final prepared = await assembly.gateways.reader.prepareChapterImageData(
        'https://fixture.example/page.png',
        comicId: 'a',
        epId: 'c',
        useDiskCache: false,
      );
      expect(prepared.bytes, bytes);
      expect(prepared.wasProcessed, true);
      await manager.setEnabled('independent', false);
      expect(assembly.runtimeRegistry.activeSourceKey, null);
    },
  );
}

class _ImageAdapter implements HttpClientAdapter {
  _ImageAdapter(this.bytes);
  final List<int> bytes;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      'content-type': ['image/png'],
    },
  );
  @override
  void close({bool force = false}) {}
}
