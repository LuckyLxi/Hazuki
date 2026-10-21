import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_favorite_menu.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';

SourcePluginManifest _manifest(Object? menu) => SourcePluginManifest.fromJson({
  'id': 'custom',
  'name': 'Custom',
  'version': '1.0',
  'entry': 'main.js',
  'presentation': {'favoriteMenu': menu},
});

void main() {
  test('optional declarations round trip with nested orders and actions', () {
    final menu = [
      {
        'id': 'saved',
        'title': {'zh': '收藏时间', 'en': 'Saved'},
        'children': [
          {'order': 'dd'},
          {'order': 'da', 'title': 'Oldest'},
          {'action': 'export', 'title': 'Export'},
        ],
      },
    ];
    final manifest = _manifest(menu);
    final parsed = SourceFavoriteMenuEntry.parseList(
      manifest.presentation['favoriteMenu'],
    );
    expect(parsed.single.children.map((e) => e.order), ['dd', 'da', null]);
    expect(parsed.single.children.last.action, 'export');
    expect(
      SourcePluginManifest.fromJson(
        manifest.toJson(),
      ).presentation['favoriteMenu'],
      menu,
    );
    final copied = SourceFavoriteMenuEntry.parseList(menu);
    expect(parsed, copied);
    expect(parsed.single.hashCode, copied.single.hashCode);
    expect(SourceFavoriteMenuEntry.parseList(null), isEmpty);
    expect(SourceFavoriteMenuEntry.parseList([]), isEmpty);
  });

  test(
    'rejects malformed declarations, duplicate siblings and excessive trees',
    () {
      Object deep(Object leaf) => [
        {'id': 'group', 'title': 'Group', 'children': leaf},
      ];
      for (final invalid in [
        {},
        ['a'],
        [{}],
        [
          {'order': ''},
        ],
        [
          {'order': ' dd '},
        ],
        [
          {'order': 'dd', 'action': 'export'},
        ],
        [
          {'action': 'export'},
        ],
        [
          {'action': 'export', 'title': 1},
        ],
        [
          {'action': 'export', 'title': {}},
        ],
        [
          {
            'action': 'export',
            'title': {'en': false},
          },
        ],
        [
          {'id': 'group', 'title': 'Group', 'children': []},
        ],
        [
          {
            'title': 'Group',
            'children': [
              {'order': 'dd'},
            ],
          },
        ],
        [
          {'order': 'dd'},
          {'order': 'dd'},
        ],
        deep(
          deep(
            deep(
              deep([
                {'order': 'dd'},
              ]),
            ),
          ),
        ),
        List.generate(101, (i) => {'order': '$i'}),
      ]) {
        expect(
          () => _manifest(invalid),
          throwsA(isA<SourcePluginException>()),
          reason: '$invalid',
        );
      }
    },
  );
}
