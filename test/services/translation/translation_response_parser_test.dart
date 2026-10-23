import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:hazuki/services/translation/translation_failure.dart';
import 'package:hazuki/services/translation/translation_prompt.dart';
import 'package:hazuki/services/translation/translation_response_parser.dart';

void main() {
  const parser = TranslationResponseParser();

  Map<String, dynamic> region({
    List<dynamic> box = const [100, 200, 400, 600],
    String kind = 'bubble',
    dynamic dst = '你好',
  }) => {
    'box': box,
    'kind': kind,
    'src': 'Hello',
    'dst': dst,
    'vertical': true,
  };

  String response(List<dynamic> regions) => jsonEncode({
    'regions': regions,
    'terms': [
      {'src': ' Alice ', 'dst': ' 爱丽丝 '},
    ],
  });

  test('parses normalized coordinates, terms, IDs, and usage', () {
    const usage = TranslationUsage(inputTokens: 100, outputTokens: 20);
    final result = parser.parse(
      response([region()]),
      translateSfx: false,
      usage: usage,
    );
    final value = result.regions.single;
    expect(value.id, 'r0');
    expect(value.box, const Rect.fromLTRB(0.1, 0.2, 0.4, 0.6));
    expect(value.kind, TranslationRegionKind.bubble);
    expect(value.sourceText, 'Hello');
    expect(value.translatedText, '你好');
    expect(value.sourceVertical, isTrue);
    expect(value.boxSource, TranslationBoxSource.ai);
    expect(result.usage, same(usage));
    expect(result.terms.single.source, 'Alice');
    expect(result.terms.single.target, '爱丽丝');
  });

  test('accepts fenced JSON and JSON surrounded by explanations', () {
    final json = response([region()]);
    for (final text in [
      json,
      '```json\n$json\n```',
      '```\n$json\n```',
      'Result:\n$json\nDone.',
    ]) {
      expect(parser.parse(text, translateSfx: false).regions, hasLength(1));
    }
  });

  test('clips and reorders coordinates, discarding empty rectangles', () {
    final result = parser.parse(
      response([
        region(box: [1100, 900, -100, 100]),
        region(box: [10, 10, 10, 200]),
        region(box: [100, 1100, 200, 1200]),
      ]),
      translateSfx: false,
    );
    expect(result.regions, hasLength(1));
    expect(result.regions.single.box, const Rect.fromLTRB(0, 0.1, 1, 0.9));
  });

  test('discards malformed regions and preserves stable response IDs', () {
    final result = parser.parse(
      response([
        null,
        region(dst: ''),
        region(dst: '   '),
        region(dst: null),
        region(dst: 42),
        region(box: [1, 2, 3]),
        region(box: ['1', 2, 3, 4]),
        region(),
      ]),
      translateSfx: true,
    );
    expect(result.regions.single.id, 'r7');
    expect(result.regions.single.translatedText, '你好');
  });

  test('filters SFX and scene text including unknown kinds', () {
    final text = response([
      region(),
      region(kind: 'narration'),
      region(kind: 'sfx'),
      region(kind: 'other'),
      region(kind: 'unknown'),
    ]);
    expect(
      parser
          .parse(text, translateSfx: false)
          .regions
          .map((value) => value.kind),
      [TranslationRegionKind.bubble, TranslationRegionKind.narration],
    );
    final all = parser.parse(text, translateSfx: true);
    expect(all.regions, hasLength(5));
    expect(all.regions.last.kind, TranslationRegionKind.other);
  });

  test('accepts empty regions and missing or dirty terms', () {
    expect(parser.parse('{"regions":[]}', translateSfx: true).terms, isEmpty);
    final result = parser.parse(
      jsonEncode({
        'regions': [],
        'terms': [
          null,
          {'src': '', 'dst': 'x'},
          {'src': 'x'},
          {'src': 1, 'dst': 'x'},
          {'src': 'A', 'dst': '甲'},
        ],
      }),
      translateSfx: false,
    );
    expect(result.terms.single.source, 'A');
  });

  test(
    'classifies unparseable JSON and invalid root shapes as badResponse',
    () {
      for (final text in [
        '',
        'no JSON',
        '{bad}',
        '[]',
        '{}',
        '{"regions":null}',
        '{"regions":[],"terms":{}}',
      ]) {
        expect(
          () => parser.parse(text, translateSfx: false),
          throwsA(
            isA<TranslationFailure>().having(
              (error) => error.kind,
              'kind',
              TranslationFailureKind.badResponse,
            ),
          ),
        );
      }
    },
  );

  test('round trips cache models including sampled background color', () {
    final result = PageTranslationResult(
      regions: [
        TranslationRegion(
          id: 'r0',
          box: const Rect.fromLTRB(0.1, 0.2, 0.4, 0.6),
          kind: TranslationRegionKind.bubble,
          sourceText: 'Hello',
          translatedText: '你好',
          sourceVertical: false,
          backgroundColor: const Color(0xfff0e0d0),
        ),
      ],
      terms: const [TranslationTerm(source: 'Alice', target: '爱丽丝')],
      usage: const TranslationUsage(inputTokens: 10, outputTokens: 5),
    );
    final decoded = PageTranslationResult.fromJson(
      jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), result.toJson());
    expect(decoded.regions.single.backgroundColor, const Color(0xfff0e0d0));
    expect(decoded.regions.single.box, result.regions.single.box);
    final withoutColor = parser.parse(
      response([region()]),
      translateSfx: false,
    );
    expect(
      PageTranslationResult.fromJson(
        withoutColor.toJson(),
      ).regions.single.backgroundColor,
      isNull,
    );
  });

  test('prompts use English language names and inject required glossary', () {
    for (final language in TranslationTargetLanguage.values) {
      expect(
        buildTranslationSystemPrompt(
          targetLanguage: language,
          translateSfx: false,
        ),
        contains(language.englishName),
      );
    }
    expect(
      buildTranslationSystemPrompt(
        targetLanguage: TranslationTargetLanguage.english,
        translateSfx: false,
      ),
      contains('Do not output sfx or other regions.'),
    );
    expect(
      buildTranslationSystemPrompt(
        targetLanguage: TranslationTargetLanguage.english,
        translateSfx: true,
      ),
      isNot(contains('Do not output sfx or other regions.')),
    );
    expect(
      buildTranslationUserPrompt(
        glossary: const [TranslationTerm(source: 'Alice', target: '爱丽丝')],
      ),
      contains('Alice => 爱丽丝'),
    );
    expect(buildTranslationUserPrompt(), 'Translate this manga image.');
  });
}
