import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:hazuki/services/translation/translation_failure.dart';
import 'package:hazuki/services/translation/translation_prompt.dart';
import 'package:hazuki/services/translation/translation_response_parser.dart';

void main() {
  test(
    'caption type overrides a vertical flag and retains all source columns',
    () {
      final result = const TranslationResponseParser()
          .parse(
            jsonEncode({
              'regions': [
                {
                  'box': [100, 100, 140, 200],
                  'boxes': [
                    [100, 100, 140, 200],
                    [160, 100, 200, 200],
                  ],
                  'kind': 'caption',
                  'src': '具體講了什麼呢？',
                  'dst': '具体的にどんな話？',
                  'vertical': true,
                },
              ],
            }),
            translateSfx: false,
          )
          .regions
          .single;
      expect(result.kind, TranslationRegionKind.caption);
      expect(result.sourceVertical, isFalse);
      expect(result.sourceBoxes, hasLength(2));
      expect(result.box, const Rect.fromLTRB(.1, .1, .2, .2));
      expect(
        TranslationRegion.fromJson(result.toJson()).sourceBoxes,
        result.sourceBoxes,
      );
    },
  );

  test(
    'only explicitly justified ignored ids are excluded from completion',
    () {
      const boxes = {
        'a': Rect.fromLTWH(.1, .1, .1, .1),
        'b': Rect.fromLTWH(.7, .7, .1, .1),
      };
      final parsed = const TranslationResponseParser().parseNumberedWithPending(
        jsonEncode({
          'regions': [
            {
              'ids': ['a'],
              'kind': 'caption',
              'dst': '待ってね',
              'vertical': true,
            },
          ],
          'ignored': [
            {
              'ids': ['b'],
              'reason': 'non_text',
            },
          ],
        }),
        boxes: boxes,
        translateSfx: false,
      );
      expect(parsed.pending, isEmpty);
      expect(parsed.result.regions.single.sourceVertical, isFalse);
      final invalid = const TranslationResponseParser()
          .parseNumberedWithPending(
            jsonEncode({
              'regions': [],
              'ignored': [
                {
                  'ids': ['b'],
                  'reason': 'too_close',
                },
              ],
            }),
            boxes: boxes,
            translateSfx: false,
          );
      expect(invalid.pending.keys, unorderedEquals(['a', 'b']));
    },
  );
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
          layoutBox: const Rect.fromLTRB(0.05, 0.15, 0.5, 0.7),
          textPatches: const [
            TranslationTextPatch(
              Rect.fromLTRB(0.12, 0.22, 0.15, 0.28),
              Color(0xfff0e0d0),
            ),
          ],
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
    expect(decoded.regions.single.layoutBox, result.regions.single.layoutBox);
    expect(
      decoded.regions.single.textPatches!.single.box,
      result.regions.single.textPatches!.single.box,
    );
    expect(
      decoded.regions.single.textPatches!.single.color,
      result.regions.single.textPatches!.single.color,
    );
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

  test(
    'custom system instructions keep the JSON, coordinates, and glossary contract',
    () {
      final prompt = buildTranslationSystemPrompt(
        targetLanguage: TranslationTargetLanguage.simplifiedChinese,
        translateSfx: false,
        customInstructions: 'Use informal dialogue and preserve honorifics.',
      );
      expect(
        prompt,
        contains('Use informal dialogue and preserve honorifics.'),
      );
      expect(prompt, contains('"regions":[{"box":[x1,y1,x2,y2]'));
      expect(prompt, contains('Simplified Chinese'));
      expect(prompt, contains('Do not output sfx or other regions.'));
      expect(
        prompt,
        contains('Always preserve the JSON schema, normalized box coordinates'),
      );
      expect(prompt, contains('required glossary translations'));
      expect(prompt, isNot(contains(kDefaultTranslationStyle)));
      expect(
        buildTranslationSystemPrompt(
          targetLanguage: TranslationTargetLanguage.english,
          translateSfx: false,
        ),
        contains(kDefaultTranslationStyle),
      );
      expect(
        buildTranslationSystemPrompt(
          targetLanguage: TranslationTargetLanguage.english,
          translateSfx: false,
          customInstructions: '  ',
        ),
        buildTranslationSystemPrompt(
          targetLanguage: TranslationTargetLanguage.english,
          translateSfx: false,
        ),
      );
    },
  );

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

  group('numbered detector responses', () {
    test(
      'rejects nearby staggered passages but retains normal parallel columns',
      () {
        for (final staggered in [true, false]) {
          final parsed = parser.parseNumberedWithPending(
            jsonEncode({
              'regions': [
                {
                  'ids': ['a', 'b'],
                  'kind': 'bubble',
                  'src': '効率が悪いと言えば',
                  'dst': '说到效率低',
                  'vertical': true,
                },
              ],
            }),
            boxes: {
              'a': const Rect.fromLTRB(.40, .20, .44, .36),
              'b': Rect.fromLTRB(
                .46,
                staggered ? .35 : .20,
                .50,
                staggered ? .51 : .36,
              ),
            },
            translateSfx: false,
          );
          expect(parsed.pending.length, staggered ? 2 : 0);
          expect(parsed.result.regions.length, staggered ? 0 : 1);
        }
      },
    );
    const boxes = {
      '0-0': Rect.fromLTRB(0.1, 0.1, 0.3, 0.2),
      '0-1': Rect.fromLTRB(0.1, 0.2, 0.4, 0.3),
      '0-2': Rect.fromLTRB(0.6, 0.6, 0.8, 0.7),
      '0-3': Rect.fromLTRB(0.5, 0.8, 0.9, 0.9),
    };

    PageTranslationResult parseNumbered(
      Object regions, {
      bool translateSfx = false,
    }) => parser.parseNumbered(
      jsonEncode({
        'regions': regions,
        'terms': [
          {'src': 'Alice', 'dst': '爱丽丝'},
        ],
      }),
      boxes: boxes,
      translateSfx: translateSfx,
    );

    test('unions grouped ids and keeps the first claim of each id', () {
      final result = parseNumbered([
        {
          'ids': ['0-0', '0-1'],
          'kind': 'bubble',
          'src': 'Hi there',
          'dst': '你好',
          'vertical': true,
        },
        {
          'ids': ['0-1', '0-2'],
          'kind': 'narration',
          'dst': '旁白',
        },
        {
          'ids': ['0-1'],
          'kind': 'bubble',
          'dst': '重复',
        },
      ]);
      expect(result.regions, hasLength(2));
      final first = result.regions[0];
      expect(first.box, const Rect.fromLTRB(0.1, 0.1, 0.4, 0.3));
      expect(first.sourceVertical, isTrue);
      expect(first.boxSource, TranslationBoxSource.detector);
      expect(first.sourceBoxes, [boxes['0-0'], boxes['0-1']]);
      expect(first.sourceIds, ['0-0', '0-1']);
      expect(result.regions[1].box, boxes['0-2']);
      expect(result.regions[1].kind, TranslationRegionKind.narration);
      expect(result.terms.single.target, '爱丽丝');
    });

    test(
      'keeps disconnected passages pending instead of discarding a cluster',
      () {
        final parsed = parser.parseNumberedWithPending(
          jsonEncode({
            'regions': [
              {
                'ids': ['a', 'b', 'c'],
                'kind': 'bubble',
                'dst': '跨气泡',
              },
              {
                'ids': ['c'],
                'kind': 'bubble',
                'dst': '右上',
              },
            ],
          }),
          boxes: const {
            // a、b 为同一气泡内上下相邻的两行。
            'a': Rect.fromLTRB(0.05, 0.80, 0.30, 0.84),
            'b': Rect.fromLTRB(0.05, 0.86, 0.28, 0.90),
            // c 在右上角，与前两行相距很远。
            'c': Rect.fromLTRB(0.75, 0.05, 0.95, 0.09),
          },
          translateSfx: false,
        );
        final scattered = parsed.result;
        expect(scattered.regions, hasLength(1));
        expect(scattered.regions.single.translatedText, '右上');
        expect(
          scattered.regions.single.box,
          const Rect.fromLTRB(0.75, 0.05, 0.95, 0.09),
        );
        expect(parsed.pending.keys, unorderedEquals(['a', 'b']));
      },
    );

    test('drops unknown ids, empty translations and unclaimed boxes', () {
      final result = parseNumbered([
        {
          'ids': ['9-9'],
          'dst': '未知',
        },
        {
          'ids': ['0-0', 'x', 7],
          'kind': 'bubble',
          'dst': '保留',
        },
        {
          'ids': ['0-1'],
          'dst': '  ',
        },
        {'ids': 'bad', 'dst': '格式错误'},
        'not a region',
      ]);
      expect(result.regions.single.translatedText, '保留');
      expect(result.regions.single.box, boxes['0-0']);
    });

    test('filters scene text unless enabled', () {
      final regions = [
        {
          'ids': ['0-3'],
          'kind': 'sfx',
          'dst': '砰',
        },
      ];
      expect(parseNumbered(regions).regions, isEmpty);
      expect(parseNumbered(regions, translateSfx: true).regions, hasLength(1));
    });

    test('only malformed JSON is a bad response', () {
      expect(
        () =>
            parser.parseNumbered('not json', boxes: boxes, translateSfx: false),
        throwsA(
          isA<TranslationFailure>().having(
            (error) => error.kind,
            'kind',
            TranslationFailureKind.badResponse,
          ),
        ),
      );
      final fenced = parser.parseNumbered(
        '```json\n{"regions":[{"ids":["0-0"],"kind":"bubble","dst":"好"}],"terms":"bad"}\n```',
        boxes: boxes,
        translateSfx: false,
      );
      expect(fenced.regions, hasLength(1));
      expect(fenced.terms, isEmpty);
    });

    test('detector prompts carry ids, coordinates and the custom tail', () {
      final user = buildDetectorTranslationUserPrompt(
        boxes: boxes,
        glossary: const [TranslationTerm(source: 'Alice', target: '爱丽丝')],
      );
      expect(user, contains('0-0: [100,100,300,200]'));
      expect(user, contains('0-3: [500,800,900,900]'));
      expect(user, contains('Alice => 爱丽丝'));
      final system = buildDetectorTranslationSystemPrompt(
        targetLanguage: TranslationTargetLanguage.simplifiedChinese,
        translateSfx: false,
        customInstructions: 'Keep honorifics.',
      );
      expect(system, contains('"ids"'));
      expect(system, contains('false detections'));
      expect(system, contains('Keep honorifics.'));
      expect(system, contains('box ids and grouping rules'));
      expect(system, isNot(contains(kDefaultTranslationStyle)));
      expect(system, isNot(contains('normalized box coordinates')));
    });
  });
}
