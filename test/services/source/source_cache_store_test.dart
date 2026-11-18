import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:hazuki/services/source/runtime/source_cache_store.dart';

void main() {
  test('explore cache owns its snapshot and expires at the existing TTL', () {
    var now = DateTime(2026);
    final cache = SourceCacheStore(now: () => now);
    final sections = <ExploreSection>[];
    expect(cache.getExploreSections(), isNull);
    cache.putExploreSections(sections);
    expect(cache.getExploreSections(), isNot(same(sections)));
    expect(() => cache.getExploreSections()!.clear(), throwsUnsupportedError);
    now = now.add(SourcePrefsKeys.discoverCacheTtl);
    expect(cache.getExploreSections(), isNotNull);
    now = now.add(const Duration(microseconds: 1));
    expect(cache.getExploreSections(), isNull);
    cache.putExploreSections(sections);
    expect(cache.getExploreSections(), isNotNull);
    cache.clearExploreSections();
    expect(cache.getExploreSections(), isNull);
  });

  test(
    'initialization clears explore and category caches and the old directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hazuki_explore_cache_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      await File('${directory.path}/old.json').writeAsString('{}');
      final cache = SourceCacheStore()
        ..putExploreSections([])
        ..putCategoryTagGroupsInMemoryCache([])
        ..discoverCacheDir = directory;
      await cache.initializeExploreCache();
      expect(cache.getExploreSections(), isNull);
      expect(
        cache.getCategoryTagGroupsFromMemoryCache(const Duration(minutes: 1)),
        isNull,
      );
      expect(cache.discoverCacheDir, isNull);
      expect(await directory.exists(), isFalse);
    },
  );
}
