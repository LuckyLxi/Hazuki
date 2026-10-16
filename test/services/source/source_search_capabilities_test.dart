import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

SourcePluginManifest manifest(Map<String, dynamic> presentation) =>
    SourcePluginManifest.fromJson({
      'id': 'arbitrary',
      'name': 'Example',
      'version': '1.0.0',
      'apiVersion': 1,
      'entry': 'main.js',
      'presentation': presentation,
    });

void main() {
  test('plugin recommendation mode needs no author search ordering', () {
    final plugin = manifest({
      'dailyRecommendation': {'mode': 'plugin'},
    });
    final config = DailyRecommendationConfig.parse(
      plugin.presentation['dailyRecommendation'],
    )!;
    expect(config.mode, DailyRecommendationMode.plugin);
    expect(config.searchOrder, isEmpty);
    expect(config.cacheKey, 'plugin');
  });
  test('new declarations work with an arbitrary plugin identity', () {
    final plugin = manifest({
      'directComicIdRules': {
        'patterns': [r'book-(\d+)'],
        'extractDigits': false,
      },
      'dailyRecommendation': {'searchOrder': 'popular'},
    });
    expect(
      DirectComicIdRules.parse(
        plugin.presentation['directComicIdRules'],
      )!.match('BOOK-123'),
      '123',
    );
    expect(
      DailyRecommendationConfig.parse(
        plugin.presentation['dailyRecommendation'],
      )!.searchOrder,
      'popular',
    );
  });

  test(
    'legacy boolean alone does not enable ID matching or recommendations',
    () {
      final plugin = manifest({'directComicId': true});
      expect(
        DirectComicIdRules.parse(plugin.presentation['directComicIdRules']),
        isNull,
      );
      expect(
        DailyRecommendationConfig.parse(
          plugin.presentation['dailyRecommendation'],
        ),
        isNull,
      );
    },
  );

  for (final invalid in <Object>[
    true,
    {'patterns': [], 'extractDigits': true},
    {
      'patterns': ['('],
      'extractDigits': true,
    },
    {
      'patterns': [r'\d+'],
      'extractDigits': true,
    },
    {
      'patterns': [r'(?:\d+)'],
      'extractDigits': true,
    },
    {
      'patterns': [r'[(]'],
      'extractDigits': true,
    },
    {
      'patterns': [r'\(123\)'],
      'extractDigits': true,
    },
    {
      'patterns': [r'(?=123)123'],
      'extractDigits': true,
    },
    {
      'patterns': [123],
      'extractDigits': true,
    },
    {
      'patterns': [r'(\d+)'],
      'extractDigits': 'true',
    },
    {
      'patterns': [r'(\d+)'],
    },
  ]) {
    test('manifest rejects invalid ID rules: $invalid', () {
      expect(
        () => manifest({'directComicIdRules': invalid}),
        throwsA(isA<SourcePluginException>()),
      );
    });
  }

  test('captures inside non-capturing groups remain valid', () {
    expect(
      DirectComicIdRules.parse({
        'patterns': [r'(?:book-(\d+))'],
        'extractDigits': false,
      })!.match('book-123'),
      '123',
    );
  });

  for (final invalid in <Object>[
    true,
    {},
    {'searchOrder': ''},
    {'searchOrder': ' '},
    {'searchOrder': 1},
    {'mode': 'unknown'},
    {'mode': 'plugin', 'searchOrder': 'mr'},
    {'mode': 'authors'},
  ]) {
    test('manifest rejects invalid recommendation config: $invalid', () {
      expect(
        () => manifest({'dailyRecommendation': invalid}),
        throwsA(isA<SourcePluginException>()),
      );
    });
  }
}
