import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/download/source_chapter_archive_capability.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceScriptEngine engine;
  late SourceChapterArchiveCapability capability;
  late Directory root;
  late _Adapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hazuki-source-archive-');
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'sample',
          name: 'Sample',
          fileName: 'sample.js',
        ),
        SourceCatalogEntry(key: 'other', name: 'Other', fileName: 'other.js'),
      ],
      defaultSourceKey: 'sample',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    await host.activeHandle.session.ensurePrefs();
    engine = SourceScriptEngine(hostPromiseRejectionHandler: (_) {});
    host.activeHandle.runtime.engine = engine;
    await engine.evaluate('globalThis.__hazuki_source = {comic:{}}');
    adapter = _Adapter();
    host.activeHandle.dio.httpClientAdapter = adapter;
    host.activeHandle.httpGateway.configureCookieBridge();
    capability = SourceChapterArchiveCapability(
      host,
      _Operations((key) async {
        final handle = host.handleFor(key);
        await handle.session.ensurePrefs();
        handle.dio.httpClientAdapter = adapter;
        handle.httpGateway.configureCookieBridge();
      }),
    );
  });
  tearDown(() async {
    host.dispose();
    await root.delete(recursive: true);
  });

  test('only a missing declaration returns null', () async {
    expect(
      await capability.loadChapterArchive(comicId: 'c', epId: 'e'),
      isNull,
    );
    for (final callback in [
      '() => null',
      '() => ({})',
      '() => {throw Error("failed")}',
    ]) {
      await engine.evaluate(
        'globalThis.__hazuki_source.comic.downloadChapter = $callback',
      );
      await expectLater(
        capability.loadChapterArchive(comicId: 'c', epId: 'e'),
        throwsA(anything),
      );
    }
  });

  test(
    'passes chapter IDs safely, retains headers and pins the source',
    () async {
      await engine.evaluate('''
      globalThis.__hazuki_source.comic.downloadChapter = async function(comicId, chapterId) {
        return {url:'https://example.com/archive',fileName:'chapter.zip',
          method:'POST', body:JSON.stringify({comicId,chapterId}),
          headers:{'X-Token':'plugin-token','Content-Type':'application/json'}};
      };
    ''');
      const comicId = 'comic"\\id';
      const chapterId = 'chapter\n1';
      final request = (await capability.loadChapterArchive(
        comicId: comicId,
        epId: chapterId,
      ))!;
      expect(request.sourceKey, 'sample');
      await host.handleFor('sample').cookieStore.set('https://example.com/', [
        const SourceCookie(
          name: 'session',
          value: 'sample-only',
          domain: 'example.com',
          path: '/',
        ),
      ]);
      await host.activateSource('other');
      final file = File('${root.path}/chapter.part');
      await capability.downloadChapterArchive(
        request,
        file,
        sourceKey: '',
        shouldCancel: () => false,
      );
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.data,
        jsonEncode({'comicId': comicId, 'chapterId': chapterId}),
      );
      expect(adapter.requests.single.headers['X-Token'], 'plugin-token');
      expect(adapter.requests.single.headers['cookie'], 'session=sample-only');
    },
  );

  test('HTTP failures do not retry or become downloaded archives', () async {
    adapter.status = 503;
    final request = SourceChapterArchive.parse({
      'url': 'https://example.com/a.zip',
    });
    await expectLater(
      capability.downloadChapterArchive(
        request,
        File('${root.path}/a.part'),
        sourceKey: 'sample',
        shouldCancel: () => false,
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(await File('${root.path}/a.part').exists(), isFalse);
  });

  test('invalid source and mismatched download scope are rejected', () async {
    await expectLater(
      capability.loadChapterArchive(
        comicId: 'c',
        epId: 'e',
        sourceKey: 'missing',
      ),
      throwsStateError,
    );
    final request = SourceChapterArchive.parse({
      'url': 'https://example.com/a.zip',
    }, sourceKey: 'sample');
    await expectLater(
      capability.downloadChapterArchive(
        request,
        File('${root.path}/a.part'),
        sourceKey: 'other',
        shouldCancel: () => false,
      ),
      throwsStateError,
    );
    expect(adapter.requests, isEmpty);
  });

  test('rejects malformed requests and unsafe file names', () {
    for (final value in [
      null,
      {'url': 'file:///secret'},
      {'url': '/relative.zip'},
      {
        'url': 'https://example.com/a.zip',
        'headers': {'X': 1},
      },
      {
        'url': 'https://example.com/a.zip',
        'headers': {'X': 'a\nb'},
      },
      {'url': 'https://example.com/a.zip', 'fileName': '../a.zip'},
      {'url': 'https://example.com/a.zip', 'fileName': 'CON.zip'},
      {'url': 'https://example.com/a.zip', 'method': 'DELETE'},
      {'url': 'https://example.com/a.zip', 'body': 'get body'},
    ]) {
      expect(() => SourceChapterArchive.parse(value), throwsFormatException);
    }
    expect(
      SourceChapterArchive.parse({
        'url': 'https://example.com/download/',
      }).fileName,
      'chapter.archive',
    );
    expect(
      SourceChapterArchive.parse({
        'url': 'https://example.com/chapter.rar?token=a',
      }).fileName,
      'chapter.rar',
    );
  });

  test(
    'SDK accepts an optional callback and rejects malformed declarations',
    () async {
      final inspector = SourcePluginScriptInspector(
        loadAssetText: (path) => File(path).readAsString(),
      );
      const prefix =
          "Hazuki.registerSource({id:'sample',search:{load:()=>({comics:[]})},comic:{loadInfo:()=>({title:'T'}),loadEp:()=>({images:[]})";
      await inspector.inspect('$prefix}});');
      await inspector.inspect(
        '$prefix,downloadChapter:()=>({url:"https://example.com/a.zip"})}});',
      );
      await expectLater(
        inspector.inspect('$prefix,downloadChapter:true}});'),
        throwsA(anything),
      );
    },
  );
}

class _Operations extends Fake implements SourceRuntimeOperations {
  _Operations(this.initialize);
  final Future<void> Function(String) initialize;
  @override
  Future<void> ensureSourceInitialized(String sourceKey) =>
      initialize(sourceKey);
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromBytes([1, 2, 3], status);
  }

  @override
  void close({bool force = false}) {}
}
