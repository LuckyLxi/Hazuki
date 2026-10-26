import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_detail_tabs.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:shared_preferences/shared_preferences.dart';

Matcher _throwsCode(String code) =>
    throwsA(isA<SourcePluginException>().having((e) => e.code, 'code', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SourceDetailTab.parseList', () {
    test('keeps declaration order and localized titles', () {
      final tabs = SourceDetailTab.parseList([
        {
          'id': 'gallery',
          'title': {'zh_CN': '画廊', 'en_US': 'Gallery'},
        },
        {'id': 'notes', 'title': '说明'},
      ]);
      expect(tabs.map((tab) => tab.id), ['gallery', 'notes']);
      expect(tabs.last.title, '说明');
      expect(SourceDetailTab.parseList(null), isEmpty);
    });

    test('rejects malformed, duplicate and excessive declarations', () {
      for (final value in [
        'gallery',
        [
          {'id': 'gallery'},
        ],
        [
          {'id': '', 'title': 'A'},
        ],
        [
          {'id': 'has space', 'title': 'A'},
        ],
        [
          {'id': 'a', 'title': '  '},
        ],
        [
          {'id': 'a', 'title': 'A'},
          {'id': 'a', 'title': 'B'},
        ],
        [
          for (var i = 0; i <= SourceDetailTab.maxCount; i++)
            {'id': 'tab$i', 'title': 'Tab $i'},
        ],
      ]) {
        expect(
          () => SourceDetailTab.parseList(value),
          _throwsCode('plugin_invalid_detail_tabs'),
          reason: '$value',
        );
      }
    });

    test('manifest validation covers detailTabs', () {
      expect(
        () => SourcePluginManifest.fromJson({
          'id': 'tabs',
          'name': 'Tabs',
          'version': '1.0.0',
          'entry': 'main.js',
          'presentation': {
            'detailTabs': [
              {'id': 'a'},
            ],
          },
        }),
        _throwsCode('plugin_invalid_detail_tabs'),
      );
    });
  });

  group('SourceDetailTabBlock.parseList', () {
    test('parses text and image blocks and skips unknown types', () {
      final blocks = SourceDetailTabBlock.parseList([
        {'type': 'text', 'title': ' 简介 ', 'text': 'Hello'},
        {'type': 'future', 'data': 1},
        {
          'type': 'images',
          'urls': [' https://a/1.jpg ', 'https://a/2.jpg'],
        },
      ]);
      expect(blocks, hasLength(2));
      final text = blocks.first as SourceDetailTextBlock;
      expect(text.title, '简介');
      expect(text.text, 'Hello');
      final images = blocks.last as SourceDetailImagesBlock;
      expect(images.title, isEmpty);
      expect(images.urls, ['https://a/1.jpg', 'https://a/2.jpg']);
      expect(SourceDetailTabBlock.parseList(null), isEmpty);
      expect(SourceDetailTabBlock.parseList(const []), isEmpty);
    });

    test('rejects malformed known blocks', () {
      for (final value in [
        {'type': 'text'},
        [
          {'type': 'text'},
        ],
        [
          {'type': 'text', 'text': 1},
        ],
        [
          {'type': 'text', 'title': 1, 'text': 'a'},
        ],
        [
          {'type': 'images', 'urls': 'a'},
        ],
        [
          {
            'type': 'images',
            'urls': ['a', ''],
          },
        ],
        [1],
      ]) {
        expect(
          () => SourceDetailTabBlock.parseList(value),
          _throwsCode('plugin_invalid_detail_tab_content'),
          reason: '$value',
        );
      }
    });
  });

  group('inspection', () {
    String script({required bool callback}) =>
        '''
Hazuki.registerSource({
  id: 'detail_tabs',
  search: {load: async () => ({comics: []})},
  comic: {
    loadInfo: async () => ({}),
    loadEp: async () => ({images: []}),
    ${callback ? 'loadDetailTab: async () => [],' : ''}
  },
  presentation: {detailTabs: [{id: 'gallery', title: {zh_CN: '画廊', en_US: 'Gallery'}}]},
});
''';

    test('declared tabs survive manifest serialization', () async {
      final manifest = await SourcePluginScriptInspector().inspect(
        script(callback: true),
      );
      final restored = SourcePluginManifest.fromJson(manifest.toJson());
      expect(
        SourceDetailTab.forPresentation(
          restored.presentation,
        ).map((tab) => tab.id),
        ['gallery'],
      );
    });

    test('declared tabs require comic.loadDetailTab', () async {
      await expectLater(
        SourcePluginScriptInspector().inspect(script(callback: false)),
        _throwsCode('plugin_detail_tab_callback_missing'),
      );
    });
  });
}
