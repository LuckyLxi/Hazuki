import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_menu.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';

SourcePluginManifest _manifest(Object? menus) => SourcePluginManifest.fromJson({
  'id': 'custom',
  'name': 'Custom',
  'version': '1',
  'entry': 'main.js',
  'presentation': {'menus': menus},
});

void main() {
  test(
    'arbitrary menu IDs and generic value/action declarations round trip',
    () {
      final menus = {
        'my.custom.menu': [
          {
            'id': 'nested',
            'title': 'Nested',
            'children': [
              {'value': 'first'},
              {'action': 'refresh', 'title': 'Refresh'},
            ],
          },
        ],
        'favorites.local.sort': [
          {'value': 'savedOldest'},
        ],
      };
      final manifest = _manifest(menus);
      final reloaded = SourcePluginManifest.fromJson(manifest.toJson());
      expect(reloaded.presentation['menus'], menus);
      final parsed = SourceMenuEntry.forLocation(
        reloaded.presentation,
        'my.custom.menu',
      );
      expect(parsed.single.children.first.value, 'first');
      expect(parsed.single.children.last.action, 'refresh');
      expect(
        SourceMenuEntry.forLocation(reloaded.presentation, 'not.declared'),
        isEmpty,
      );
    },
  );

  test(
    'explicit generic cloud declaration overrides the legacy favoriteMenu including empty lists',
    () {
      final presentation = <String, dynamic>{
        'favoriteMenu': [
          {'order': 'old'},
        ],
      };
      expect(
        SourceMenuEntry.forLocation(
          presentation,
          'favorites.cloud.sort',
        ).single.value,
        'old',
      );
      presentation['menus'] = {'favorites.cloud.sort': []};
      expect(
        SourceMenuEntry.forLocation(presentation, 'favorites.cloud.sort'),
        isEmpty,
      );
      expect(
        SourceMenuEntry.forLocation(presentation, 'favorites.local.sort'),
        isEmpty,
      );
    },
  );

  test(
    'generic values preserve an empty host value while legacy order IDs remain nonempty',
    () {
      final menus = SourceMenuEntry.parseMenus({
        'filter': [
          {'value': '', 'title': 'All'},
        ],
      });
      expect(menus['filter']!.single.value, '');
      expect(
        () => SourceMenuEntry.parseList([
          {'order': ''},
        ]),
        throwsA(isA<SourcePluginException>()),
      );
    },
  );

  test('rejects malformed maps, value conflicts and duplicate leaves', () {
    for (final invalid in [
      [],
      {'': []},
      {' padded ': []},
      {'menu': null},
      {'menu': {}},
      {
        'menu': [
          {'value': 2},
        ],
      },
      {
        'menu': [
          {'value': 'a', 'order': 'b'},
        ],
      },
      {
        'menu': [
          {'value': 'a', 'action': 'run'},
        ],
      },
      {
        'menu': [
          {'value': 'a'},
          {'value': 'a'},
        ],
      },
    ]) {
      expect(() => _manifest(invalid), throwsA(isA<SourcePluginException>()));
    }
  });
}
