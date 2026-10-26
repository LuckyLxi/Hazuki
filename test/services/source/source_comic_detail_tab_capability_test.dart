import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/comic/comic_detail_tab_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceComicDetailTabCapability capability;
  late SourceScriptEngine target;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'active', name: 'Active', fileName: 'a.js'),
        SourceCatalogEntry(key: 'target', name: 'Target', fileName: 't.js'),
      ],
      defaultSourceKey: 'active',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    capability = SourceComicDetailTabCapability(runtimeHost: host);
    target = SourceScriptEngine(hostPromiseRejectionHandler: (_) {});
    host.handleFor('target').runtime.engine = target;
    await target.evaluate('''
      globalThis.calls = [];
      globalThis.__hazuki_source = {comic: {
        loadDetailTab: async (comicId, tabId) => {
          calls.push([comicId, tabId]);
          if (tabId === 'empty') return [];
          if (tabId === 'bad') return [{type: 'images', urls: 'x'}];
          return [
            {type: 'text', title: 'Intro', text: 'Hello'},
            {type: 'images', urls: ['https://a/1.jpg']},
          ];
        },
      }};
    ''');
    addTearDown(host.dispose);
  });

  test('passes comic and tab ids and parses returned blocks', () async {
    final blocks = await capability.loadDetailTab(
      comicId: 'comic"id',
      tabId: 'gallery',
      sourceKey: 'target',
    );
    expect(blocks, hasLength(2));
    expect((blocks.first as SourceDetailTextBlock).text, 'Hello');
    expect((blocks.last as SourceDetailImagesBlock).urls, ['https://a/1.jpg']);
    expect(
      await target.evaluate('JSON.stringify(calls)'),
      '[["comic\\"id","gallery"]]',
    );
  });

  test('empty results stay empty and malformed results fail', () async {
    expect(
      await capability.loadDetailTab(
        comicId: 'c',
        tabId: 'empty',
        sourceKey: 'target',
      ),
      isEmpty,
    );
    await expectLater(
      capability.loadDetailTab(comicId: 'c', tabId: 'bad', sourceKey: 'target'),
      throwsA(
        isA<SourcePluginException>().having(
          (e) => e.code,
          'code',
          'plugin_invalid_detail_tab_content',
        ),
      ),
    );
  });
}
