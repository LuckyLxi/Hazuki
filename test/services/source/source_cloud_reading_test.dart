import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hazuki/services/source/account/account_session_capability.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/content/source_cloud_reading.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Operations extends Fake implements SourceRuntimeOperations {
  Future<void>? delay;
  int initializationCalls = 0;
  @override
  Future<void> ensureSourceInitialized(String sourceKey) async {
    initializationCalls++;
    await delay;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'installation derives cloud policy from callback declarations and rejects history alone',
    () async {
      final inspector = SourcePluginScriptInspector(
        loadAssetText: (path) => File(path).readAsString(),
      );
      const prefix =
          "Hazuki.registerSource({id:'sample',name:'Sample',search:{load:()=>({comics:[]})},comic:{loadInfo:()=>({title:'T'}),loadEp:()=>({images:[]}),";
      final manifest = await inspector.inspect(
        '${prefix}loadReadingProgress:()=>null}});',
      );
      expect(manifest.presentation['__hostCloudReading'], isTrue);
      await expectLater(
        inspector.inspect('${prefix}loadReadingHistory:()=>({items:[]})}});'),
        throwsA(anything),
      );
    },
  );
  late SourceRuntimeHost host;
  late SourceScriptEngine engine;
  late SourceCloudReadingCapability cloud;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'sample',
          name: 'Sample',
          fileName: 'sample.js',
          directUrls: [],
        ),
      ],
      defaultSourceKey: 'sample',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    await host.activeHandle.session.ensurePrefs();
    engine = SourceScriptEngine();
    host.activeHandle.runtime.engine = engine;
    engine.evaluate('globalThis.__hazuki_source = {comic:{}}');
    cloud = SourceCloudReadingCapability(host, _Operations());
  });
  tearDown(() {
    cloud.dispose();
    host.dispose();
  });
  Future<void> login(String marker) async {
    await host.activeHandle.session.saveSourceData(
      'sample',
      'login_session',
      marker,
    );
    host.notifyActiveRuntimeChanged('sample');
  }

  for (final declaration in ['cold', 'local', 'uploadOnly', 'progressOnly']) {
    test('$declaration history skips network initialization', () async {
      cloud.dispose();
      if (declaration == 'cold') {
        host.activeHandle.runtime.engine = null;
        engine.close();
      } else if (declaration == 'uploadOnly') {
        engine.evaluate(
          'globalThis.__hazuki_source.comic.onReadingProgress=()=>{}',
        );
      } else if (declaration == 'progressOnly') {
        engine.evaluate(
          'globalThis.__hazuki_source.comic.loadReadingProgress=()=>null',
        );
      }
      final operations = _Operations();
      cloud = SourceCloudReadingCapability(host, operations);
      await login('first');
      expect(await cloud.refreshCloudReadingHistory('sample'), isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(operations.initializationCalls, 0);
    });
  }

  test('logged-out cloud history skips network initialization', () async {
    cloud.dispose();
    final operations = _Operations();
    engine.evaluate('''
      globalThis.__hazuki_source.comic = {
        loadReadingProgress: () => { throw Error('login required'); },
        loadReadingHistory: () => { throw Error('login required'); }
      };
    ''');
    cloud = SourceCloudReadingCapability(host, operations);

    expect(await cloud.refreshCloudReadingHistory('sample'), isEmpty);
    expect(operations.initializationCalls, 0);
  });

  test(
    'upload-only declaration preserves legacy mode; reader requires login',
    () async {
      engine.evaluate(
        'globalThis.__hazuki_source.comic.onReadingProgress = () => {}',
      );
      expect(await cloud.usesCloudReading('sample'), isFalse);
      engine.evaluate(
        'globalThis.__hazuki_source.comic.loadReadingProgress = () => null',
      );
      expect(await cloud.usesCloudReading('sample'), isTrue);
      await expectLater(
        cloud.loadCloudReadingProgress('sample', 'c'),
        throwsStateError,
      );
      await login('account-one');
      expect(await cloud.loadCloudReadingProgress('sample', 'c'), isNull);
      engine.evaluate(
        'globalThis.__hazuki_source.comic.loadReadingProgress = () => { throw Error("offline") }',
      );
      await expectLater(
        cloud.loadCloudReadingProgress('sample', 'c'),
        throwsA(anything),
      );
      expect(await cloud.usesCloudReading('sample'), isTrue);
    },
  );
  test(
    'disabling a plugin during initialization cannot recreate or read its old runtime',
    () async {
      cloud.dispose();
      final waiting = Completer<void>();
      final operations = _Operations()..delay = waiting.future;
      cloud = SourceCloudReadingCapability(host, operations);
      engine.evaluate(
        'globalThis.__hazuki_source.comic.loadReadingProgress=()=>null',
      );
      final pending = cloud.usesCloudReading('sample');
      final assertion = expectLater(pending, throwsStateError);
      await host.replaceCatalog(const []);
      waiting.complete();
      await assertion;
      expect(host.existingHandles, isEmpty);
    },
  );
  test(
    'imports every page, deduplicates and clears cache on account change',
    () async {
      engine.evaluate('''
      globalThis.calls=[];
      globalThis.__hazuki_source.comic={
        loadReadingProgress:()=>null,
        loadReadingHistory: page=>{ calls.push(page); return {items:page<4?[{
          comic:{id:page===3?'1':String(page),title:'Comic '+page,cover:''},
          progress:{chapterId:'ep',page:page,updatedAtMs:page}}]:[]}; }
      };
    ''');
      await login('first');
      final history = await cloud.refreshCloudReadingHistory('sample');
      expect(history.map((c) => c.id), ['1', '2']);
      expect(engine.evaluate('JSON.stringify(calls)'), '[1,2,3,4]');
      engine.evaluate(
        'globalThis.__hazuki_source.comic.loadReadingHistory=()=>{throw Error("offline")}',
      );
      expect((await cloud.refreshCloudReadingHistory('sample')).length, 2);
      await login('second');
      expect(await cloud.refreshCloudReadingHistory('sample'), isEmpty);
    },
  );
  test('late progress from a replaced account is rejected', () async {
    final delayed = Completer<Object?>();
    engine.setMessageHandler((_) => delayed.future);
    engine.evaluate(
      'globalThis.__hazuki_source.comic.loadReadingProgress=()=>sendMessage({method:"wait"})',
    );
    await login('first');
    final pending = cloud.loadCloudReadingProgress('sample', 'c');
    final assertion = expectLater(pending, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await login('second');
    delayed.complete({'chapterId': 'old', 'page': 30});
    await assertion;
  });
  test('validates original page numbers without guessing chapter indices', () {
    expect(parseCloudReadingProgress({'chapterId': '100', 'page': 7}), {
      'epId': '100',
      'imagePage': 7,
      'cloud': true,
    });
    for (final raw in [
      null,
      {'chapterId': '1', 'page': 0},
      {'chapterId': '1', 'page': 1.5},
      {'chapterId': '1', 'page': 1, 'totalPages': 0},
    ]) {
      expect(() => parseCloudReadingProgress(raw), throwsFormatException);
    }
  });

  for (final logout in [false, true]) {
    test(
      '${logout ? 'logout' : 'account change'} aborts the private cloud HTTP client and discards late cookies',
      () async {
        cloud.dispose();
        final http = _PendingHttp();
        engine.evaluate(
          'globalThis.__hazuki_source.comic.loadReadingProgress=()=>null',
        );
        cloud = SourceCloudReadingCapability(
          host,
          _Operations(),
          loadReadRuntime: (handle) async {
            await handle.session.ensurePrefs();
            handle.dio.httpClientAdapter = http;
            final bridge = SourceJsBridgeCookieCapability(
              activeHandle: () => handle,
            );
            bridge.configureDioCookieBridge(handle);
            final isolated = SourceScriptEngine();
            handle.runtime.engine = isolated;
            isolated.setMessageHandler(
              (message) => bridge.handleJsMessageForHandle(handle, message),
            );
            isolated.evaluate(File('assets/init.js').readAsStringSync());
            isolated.evaluate(
              File('assets/hazuki_plugin_sdk.js').readAsStringSync(),
            );
            isolated.evaluate(
              '''Hazuki.registerSource({id:'sample',search:{load:()=>({comics:[]})},comic:{
        loadInfo:()=>({title:'Test'}),loadEp:()=>({images:[]}),
        loadReadingProgress:async()=>{
          await Hazuki.storage.set('cloud_private_write',true);
          return JSON.parse((await Hazuki.http.get('https://site.example/progress')).body);
        }}});''',
            );
          },
        );
        await login('first');
        final pending = cloud.loadCloudReadingProgress('sample', 'c');
        final assertion = expectLater(pending, throwsStateError);
        await http.started.future;
        if (logout) {
          await SourceAccountSessionCapability(runtimeHost: host).logout();
        } else {
          await login('second');
        }
        await assertion.timeout(const Duration(seconds: 1));
        expect(http.closed, isTrue);
        http.response.complete(
          ResponseBody.fromString(
            '{"chapterId":"old","page":9}',
            200,
            headers: {
              'set-cookie': ['old=late; Path=/; Secure'],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          host.activeHandle.cookieStore.get('https://site.example/'),
          isEmpty,
        );
        expect(
          host.activeHandle.session.loadSourceData(
            'sample',
            'cloud_private_write',
          ),
          isNull,
        );
      },
    );
  }
}

class _PendingHttp implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  bool closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}
