import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_catalog_resolver.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_text_downloader.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _html = '''
<html><body><section id="catalog" class="comics featured"><a id="comic:1" class="comic" href="/comic/1">漫画 &amp; One<img src="/cover.jpg" alt="封面"></a>tail<!--note--><a class="comic" href="/comic/2">Two</a></section><script>globalThis.pageRan = true;</script></body></html>
''';

Future<SourceRuntimeHandle> _createRuntime(String id) async {
  final handle = SourceRuntimeHandle(
    sourceKey: id,
    secureStorage: MemorySourceSecureSessionStorage(),
    ensureInitialized: (_) async {},
    notifyRuntimeStateChanged: (_) {},
  );
  addTearDown(handle.requestDispose);
  final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
  final engine = SourceScriptEngine(
    timeout: 5000,
    hostPromiseRejectionHandler: (_) {},
  );
  handle.runtime.engine = engine;
  engine.setMessageHandler(
    (dynamic request) => bridge.handleJsMessageForHandle(handle, request),
  );
  engine.setGlobal('fixtureHtml', _html);
  engine.evaluate(await File('assets/init.js').readAsString());
  engine.evaluate(await File('assets/hazuki_plugin_sdk.js').readAsString());
  return handle;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'fetches HTML and extracts comics without executing page scripts',
    () async {
      final handle = await _createRuntime('html_source');
      final fixtures = _HtmlFixtures();
      handle.dio.httpClientAdapter = fixtures;
      final result = await handle.facade.js.resolve(
        handle.runtime.engine!.evaluate('''
(async () => {
  const response = await Hazuki.http.get('https://fixture.example/comics', {
    'User-Agent': 'Hazuki HTML test', 'Referer': 'https://fixture.example/'
  });
  const doc = Hazuki.html.parse(response.body);
  try {
    return {status: response.status, comics: doc.querySelectorAll('#catalog > a.comic').map(a => ({
      title: a.text, href: a.attributes.href, image: a.querySelector('img')?.attributes.src ?? null
    })), pageRan: typeof globalThis.pageRan};
  } finally { doc.dispose(); }
})()
'''),
      );
      expect(result, {
        'status': 200,
        'comics': [
          {'title': '漫画 & One', 'href': '/comic/1', 'image': '/cover.jpg'},
          {'title': 'Two', 'href': '/comic/2', 'image': null},
        ],
        'pageRan': 'undefined',
      });
      expect(fixtures.requests, hasLength(1));
      expect(
        fixtures.requests.single.headers['User-Agent'],
        'Hazuki HTML test',
      );
      expect(
        fixtures.requests.single.headers['Referer'],
        'https://fixture.example/',
      );
    },
  );

  test(
    'supports element properties, scoped queries and node traversal',
    () async {
      final handle = await _createRuntime('html_source');
      final engine = handle.runtime.engine!;
      final result = engine.evaluate('''
(() => {
  const doc = new HtmlDocument(fixtureHtml);
  try {
    const catalog = doc.getElementById('catalog');
    const first = doc.getElementById('comic:1');
    const second = catalog.querySelectorAll('a[href]')[1];
    return {
      classes: catalog.classNames, id: first.id, tag: first.localName,
      parent: first.parent.id, rootParent: doc.querySelector('html').parent,
      previous: first.previousElementSibling, next: first.nextElementSibling.text,
      secondPrevious: second.previousElementSibling.id, secondNext: second.nextElementSibling,
      children: catalog.children.map(e => e.localName),
      nodes: catalog.nodes.map(n => ({type: n.type, text: n.text, element: n.toElement()?.localName ?? null})),
      inner: first.innerHTML, image: first.querySelectorAll('img')[0].attributes.alt,
      missing: catalog.querySelector('.missing'), missingAll: doc.querySelectorAll('.missing'),
      missingId: doc.getElementById('missing'), emptyId: doc.getElementById(''), noId: second.id
    };
  } finally { doc.dispose(); }
})()
''');
      expect(result, {
        'classes': ['comics', 'featured'],
        'id': 'comic:1',
        'tag': 'a',
        'parent': 'catalog',
        'rootParent': null,
        'previous': null,
        'next': 'Two',
        'secondPrevious': 'comic:1',
        'secondNext': null,
        'children': ['a', 'a'],
        'nodes': [
          {'type': 'element', 'text': '漫画 & One', 'element': 'a'},
          {'type': 'text', 'text': 'tail', 'element': null},
          {'type': 'comment', 'text': 'note', 'element': null},
          {'type': 'element', 'text': 'Two', 'element': 'a'},
        ],
        'inner': '漫画 &amp; One<img src="/cover.jpg" alt="封面">',
        'image': '封面',
        'missing': null,
        'missingAll': [],
        'missingId': null,
        'emptyId': null,
        'noId': null,
      });
    },
  );

  test('parses incomplete HTML and keeps documents independent', () async {
    final handle = await _createRuntime('html_source');
    final engine = handle.runtime.engine!;
    engine.evaluate('''
const firstDoc = Hazuki.html.parse('<p>First &amp; One');
const secondDoc = Hazuki.html.parse('<p>Second');
const savedElement = firstDoc.querySelector('p');
''');
    expect(engine.evaluate('savedElement.text'), 'First & One');
    engine.evaluate('firstDoc.dispose(); firstDoc.dispose();');
    expect(
      () => engine.evaluate("firstDoc.querySelector('p')"),
      throwsA(anything),
    );
    expect(() => engine.evaluate('savedElement.text'), throwsA(anything));
    expect(engine.evaluate("secondDoc.querySelector('p').text"), 'Second');
    engine.evaluate('secondDoc.dispose();');
  });

  test(
    'isolates document keys across plugins and clears them on shutdown',
    () async {
      final first = await _createRuntime('first');
      final second = await _createRuntime('second');
      first.runtime.engine!.evaluate(
        "const doc = Hazuki.html.parse('<p>First');",
      );
      second.runtime.engine!.evaluate(
        "const doc = Hazuki.html.parse('<p>Second');",
      );
      expect(first.runtime.engine!.evaluate('doc.key'), 0);
      expect(second.runtime.engine!.evaluate('doc.key'), 0);
      first.runtime.engine!.evaluate('doc.dispose();');
      expect(
        second.runtime.engine!.evaluate("doc.querySelector('p').text"),
        'Second',
      );
      final documents = second.htmlBridge;
      second.requestDispose();
      expect(
        () => documents.handleOperation({
          'function': 'querySelector',
          'key': 0,
          'query': 'p',
        }),
        throwsStateError,
      );
    },
  );

  test(
    'imports HTML sources and preserves documents if reloading fails',
    () async {
      final root = await Directory.systemTemp.createTemp('hazuki_html_test_');
      final manager = SourcePluginManager(
        directory: () async => root,
        legacyDirectories: [],
      );
      final assembly = SourceRuntimeAssembly(
        pluginManager: manager,
        secureSessionStorage: MemorySourceSecureSessionStorage(),
      );
      addTearDown(() async {
        assembly.dispose();
        manager.dispose();
        await root.delete(recursive: true);
      });
      String script(String title, {bool fail = false}) =>
          '''
const doc = Hazuki.html.parse('<h1>$title</h1>');
Hazuki.registerSource({
  id: 'html_source', name: doc.querySelector('h1').text,
  init: () => {${fail ? "throw new Error('init failed');" : ''}},
  search: {load: async () => ({comics: []})},
  comic: {loadInfo: async () => ({title: doc.querySelector('h1').text, chapters: {}}), loadEp: async () => ({images: []})}
});
''';
      await manager.initialize();
      await manager.importPackage(utf8.encode(script('First')));
      await assembly.runtimeRegistry.ensureInitialized(
        sourceKey: 'html_source',
      );
      final handle = assembly.testing.handleFor('html_source');
      final oldEngine = handle.runtime.engine!;
      final oldDocuments = handle.htmlBridge;
      final loader = SourceRuntimeLoader(
        scriptStore: manager,
        catalogResolver: _UnusedCatalogResolver(),
        downloader: const SourceTextDownloader(),
        jsBridge: SourceJsBridgeCookieCapability(activeHandle: () => handle),
        runtimeStateController: SourceRuntimeStateController(),
        bundledInitAssetPath: 'assets/init.js',
        loadAssetText: (path) => File(path).readAsString(),
      );
      final file = await manager.sourceFileFor('html_source');
      await manager.write('html_source', script('Failed', fail: true));
      await expectLater(loader.loadMetadata(handle, file), throwsA(anything));
      expect(handle.runtime.engine, same(oldEngine));
      expect(handle.htmlBridge, same(oldDocuments));
      expect(oldEngine.evaluate("doc.querySelector('h1').text"), 'First');
      await manager.write('html_source', script('Second'));
      await loader.loadMetadata(handle, file);
      expect(
        handle.runtime.engine!.evaluate("doc.querySelector('h1').text"),
        'Second',
      );
      expect(
        () => oldDocuments.handleOperation({
          'function': 'querySelector',
          'key': 0,
          'query': 'h1',
        }),
        throwsStateError,
      );
    },
  );
}

class _HtmlFixtures implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      _html,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnusedCatalogResolver extends Mock implements SourceCatalogResolver {}
