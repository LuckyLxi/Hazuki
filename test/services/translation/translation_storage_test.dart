import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:hazuki/services/translation/translation_glossary_store.dart';
import 'package:hazuki/services/translation/translation_result_cache.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hazuki_translation_');
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<String> key({
    int image = 1,
    String language = 'zh-Hans',
    String model = 'vision',
    TranslationProviderPreset provider = TranslationProviderPreset.openai,
    bool sfx = false,
  }) => TranslationResultCache.keyFor(
    imageBytes: Uint8List.fromList([image]),
    targetLanguage: language,
    providerPreset: provider,
    model: model,
    translateSfx: sfx,
  );
  PageTranslationResult result() => PageTranslationResult(
    regions: [],
    terms: const [TranslationTerm(source: 'Alice', target: '爱丽丝')],
    usage: const TranslationUsage(inputTokens: 100, outputTokens: 10),
  );

  test(
    'cache keys are stable and include image and translation settings',
    () async {
      final baseline = await key();
      expect(await key(), baseline);
      for (final changed in [
        key(image: 2),
        key(language: 'en'),
        key(model: 'other'),
        key(provider: TranslationProviderPreset.custom),
        key(sfx: true),
      ]) {
        expect(await changed, isNot(baseline));
      }
      final glossary = TranslationGlossaryStore(
        supportDirectory: () async => directory,
      );
      await glossary.merge('source', 'comic', const [
        TranslationTerm(source: 'A', target: '甲'),
      ]);
      expect(await key(), baseline);
    },
  );

  test(
    'cache round trip zeros usage and supports removal and clearing',
    () async {
      final cache = TranslationResultCache(
        supportDirectory: () async => directory,
      );
      final cacheKey = await key();
      expect(await cache.read(cacheKey), isNull);
      await cache.write(cacheKey, result());
      final cached = (await cache.read(cacheKey))!;
      expect(cached.terms.single.source, 'Alice');
      expect(cached.usage.inputTokens, 0);
      expect(cached.usage.outputTokens, 0);
      expect(await cache.sizeBytes(), greaterThan(0));
      await cache.remove(cacheKey);
      expect(await cache.read(cacheKey), isNull);
      await cache.write(cacheKey, result());
      await cache.write(await key(image: 2), result());
      await cache.clear();
      expect(await cache.sizeBytes(), 0);
    },
  );

  test(
    'cache evicts oldest modifications to below the target capacity',
    () async {
      final sampleLength = utf8.encode(jsonEncode(result().toJson())).length;
      final cache = TranslationResultCache(
        supportDirectory: () async => directory,
        maximumBytes: sampleLength * 2 + 1,
        targetBytes: sampleLength + 1,
      );
      final first = await key(image: 1);
      final second = await key(image: 2);
      final third = await key(image: 3);
      await cache.write(first, result());
      await cache.sizeBytes();
      final firstFile = File(
        '${directory.path}/manga_translation/cache/$first.json',
      );
      await firstFile.setLastModified(DateTime(2000));
      await cache.write(second, result());
      await cache.sizeBytes();
      await File(
        '${directory.path}/manga_translation/cache/$second.json',
      ).setLastModified(DateTime(2001));
      await cache.write(third, result());
      expect(await cache.sizeBytes(), lessThan(sampleLength + 1));
      expect(await cache.read(first), isNull);
      expect(await cache.read(second), isNull);
      expect(await cache.read(third), isNotNull);
    },
  );

  test(
    'malformed cached JSON is discarded and cannot escape cache directory',
    () async {
      final cache = TranslationResultCache(
        supportDirectory: () async => directory,
      );
      final cacheKey = await key();
      await cache.write(cacheKey, result());
      await cache.sizeBytes();
      await File(
        '${directory.path}/manga_translation/cache/$cacheKey.json',
      ).writeAsString('{invalid');
      expect(await cache.read(cacheKey), isNull);
      await expectLater(cache.remove('../outside'), throwsArgumentError);
    },
  );

  test('glossary uses first translation and updates lastSeenAt', () async {
    var now = DateTime(2026, 1, 1);
    final store = TranslationGlossaryStore(
      supportDirectory: () async => directory,
      now: () => now,
    );
    await store.merge('source', 'comic', const [
      TranslationTerm(source: 'A', target: '甲'),
    ]);
    now = DateTime(2026, 1, 2);
    await store.merge('source', 'comic', const [
      TranslationTerm(source: 'A', target: '乙'),
    ]);
    final entry = (await store.load('source', 'comic')).single;
    expect(entry.target, '甲');
    expect(entry.addedAt, DateTime(2026, 1, 1));
    expect(entry.lastSeenAt, now);
    expect(await store.load('another-source', 'comic'), isEmpty);
    expect(await store.load('source', 'another-comic'), isEmpty);
  });

  test(
    'concurrent glossary merges preserve entries and first writer',
    () async {
      final store = TranslationGlossaryStore(
        supportDirectory: () async => directory,
      );
      await Future.wait([
        store.merge('source', 'comic', const [
          TranslationTerm(source: 'A', target: '甲'),
          TranslationTerm(source: 'B', target: '乙'),
        ]),
        store.merge('source', 'comic', const [
          TranslationTerm(source: 'A', target: '丙'),
          TranslationTerm(source: 'C', target: '丁'),
        ]),
      ]);
      final entries = {
        for (final entry in await store.load('source', 'comic'))
          entry.source: entry.target,
      };
      expect(entries, {'A': '甲', 'B': '乙', 'C': '丁'});
      await store.removeEntry('source', 'comic', 'B');
      expect(
        (await store.load('source', 'comic')).map((entry) => entry.source),
        isNot(contains('B')),
      );
      await store.clear('source', 'comic');
      expect(await store.load('source', 'comic'), isEmpty);
    },
  );

  test('glossary retains at most 150 recently seen terms', () async {
    var now = DateTime(2026, 1, 1);
    final store = TranslationGlossaryStore(
      supportDirectory: () async => directory,
      now: () => now,
    );
    await store.merge(
      'source',
      'comic',
      List.generate(
        150,
        (index) => TranslationTerm(source: '$index', target: 'term$index'),
      ),
    );
    now = now.add(const Duration(days: 1));
    await store.merge('source', 'comic', const [
      TranslationTerm(source: '0', target: 'changed'),
      TranslationTerm(source: 'new', target: '新'),
    ]);
    final entries = await store.load('source', 'comic');
    expect(entries, hasLength(150));
    expect(
      entries.any((entry) => entry.source == '0' && entry.target == 'term0'),
      isTrue,
    );
    expect(entries.any((entry) => entry.source == 'new'), isTrue);
  });
}
