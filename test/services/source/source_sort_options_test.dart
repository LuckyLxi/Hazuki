import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';

void main() {
  test('comment order defaults normalize without host-provided codes', () {
    final options = SourceCommentSortOptions.fromPresentation({
      'commentOrders': {
        'custom': {'zh': '自定义', 'en': 'Custom'},
        'next': 'Next',
      },
      'commentDefaultOrder': 'missing',
    });
    expect(options.normalize(''), 'custom');
    expect(options.normalize(' next '), 'next');
    expect(const SourceCommentSortOptions().normalize('custom'), '');
    expect(
      SourceCommentSortOptions.fromPresentation({
        'commentOrders': {'custom': 'Custom', 'next': 'Next'},
        'commentDefaultOrder': 'next',
      }).normalize('invalid'),
      'next',
    );
  });

  test(
    'comment declarations survive serialization and reject malformed values',
    () {
      SourcePluginManifest manifest(Map<String, dynamic> presentation) =>
          SourcePluginManifest.fromJson({
            'id': 'custom',
            'name': 'Custom',
            'version': '1.0',
            'entry': 'main.js',
            'presentation': presentation,
          });
      final original = manifest({
        'commentOrders': {
          'new': {'zh': '最新', 'en': 'Newest'},
        },
        'commentDefaultOrder': 'new',
      });
      expect(
        SourcePluginManifest.fromJson(original.toJson()).presentation,
        original.presentation,
      );
      for (final invalid in [
        {
          'commentOrders': ['new'],
        },
        {
          'commentOrders': {'': 'Empty'},
        },
        {
          'commentOrders': {' new ': 'Whitespace'},
        },
        {
          'commentOrders': {'new': 1},
        },
        {
          'commentOrders': {
            'new': {'en': 1},
          },
        },
        {'commentDefaultOrder': 1},
      ]) {
        expect(() => manifest(invalid), throwsA(isA<SourcePluginException>()));
      }
    },
  );

  test('invalid defaults fall back to the first declared search order', () {
    final presentation = {
      'searchOrders': {'score': 'Score', 'recent': 'Recent'},
      'searchDefaultOrder': 'missing',
    };
    expect(normalizeSourceSearchOrder('', presentation), 'score');
    expect(normalizeSourceSearchOrder(' recent ', presentation), 'recent');
    expect(normalizeSourceSearchOrder('mr', {}), '');
    expect(normalizeSourceSearchOrder('mr', {'searchOrders': {}}), '');
  });

  test('favorite sort labels survive manifest serialization', () {
    final manifest = SourcePluginManifest.fromJson({
      'id': 'custom',
      'name': 'Custom',
      'version': '1.0',
      'entry': 'main.js',
      'presentation': {
        'favoriteOrders': ['score'],
        'favoriteOrderLabels': {
          'score': {'zh': '评分', 'en': 'Score'},
        },
      },
    });
    final labels =
        SourcePluginManifest.fromJson(
              manifest.toJson(),
            ).presentation['favoriteOrderLabels']
            as Map;
    expect(sourceOrderLabel(labels['score'], 'zh', 'score'), '评分');
    expect(sourceOrderLabel(labels['score'], 'fr', 'score'), 'Score');
  });

  test('rejects malformed favorite order labels', () {
    for (final labels in [
      [],
      {'score': 2},
      {
        'score': {'en': false},
      },
    ]) {
      expect(
        () => SourcePluginManifest.fromJson({
          'id': 'custom',
          'name': 'Custom',
          'version': '1.0',
          'entry': 'main.js',
          'presentation': {'favoriteOrderLabels': labels},
        }),
        throwsA(isA<SourcePluginException>()),
      );
    }
  });

  test('sort labels use the SDK locale fallbacks including region keys', () {
    expect(
      sourceOrderLabel({'zh_CN': '排序', 'en_US': 'Sort'}, 'zh', 'raw'),
      '排序',
    );
    expect(sourceOrderLabel({'en_US': 'Sort', 'fr': ''}, 'fr', 'raw'), 'Sort');
    expect(sourceOrderLabel({'zh': ''}, 'zh', 'raw'), 'raw');
  });
}
