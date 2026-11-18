import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:hazuki/services/translation/translation_usage_store.dart';
import 'package:hazuki/features/settings/view/translation/translation_usage_group.dart';

void main() {
  late Directory directory;
  late TranslationUsageStore store;
  var now = DateTime(2026, 1, 1, 23, 59);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'hazuki_translation_usage_',
    );
    now = DateTime(2026, 1, 1, 23, 59);
    store = TranslationUsageStore(
      supportDirectory: () async => directory,
      now: () => now,
    );
  });
  tearDown(() async {
    store.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'aggregates real requests and pages by local date without losing concurrent records',
    () async {
      await Future.wait([
        store.record(
          pages: 1,
          requests: 2,
          usage: const TranslationUsage(inputTokens: 100, outputTokens: 20),
        ),
        store.record(
          pages: 1,
          requests: 1,
          usage: const TranslationUsage(inputTokens: 50, outputTokens: 10),
        ),
      ]);
      var usage = (await store.load())['2026-01-01']!;
      expect(usage.pages, 2);
      expect(usage.requests, 3);
      expect(usage.inputTokens, 150);
      expect(usage.outputTokens, 30);
      now = DateTime(2026, 1, 2);
      await store.record(pages: 1);
      usage = (await store.load())['2026-01-02']!;
      expect(usage.pages, 1);
      expect(usage.requests, 0);
      expect(await store.load(), hasLength(2));
      await store.clear();
      expect(await store.load(), isEmpty);
    },
  );

  test('retains exactly the most recent 400 calendar days', () async {
    await store.record(pages: 1);
    now = DateTime(2026, 1, 2);
    await store.record(pages: 1);
    now = DateTime(2026, 1, 1).add(const Duration(days: 400));
    await store.record(pages: 1);
    final usage = await store.load();
    expect(usage.containsKey('2026-01-01'), isFalse);
    expect(usage.containsKey('2026-01-02'), isTrue);
    expect(usage, hasLength(2));
  });

  test('heatmap assigns zero and four increasing activity levels', () {
    expect(translationHeatmapLevel(0, 0), 0);
    expect(
      [
        1,
        25,
        26,
        50,
        51,
        75,
        76,
        100,
      ].map((pages) => translationHeatmapLevel(pages, 100)),
      [1, 1, 2, 2, 3, 3, 4, 4],
    );
  });
}
