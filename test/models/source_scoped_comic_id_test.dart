import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  group('SourceScopedComicId', () {
    test('keeps legacy ids unprefixed when source key is empty', () {
      const id = SourceScopedComicId(sourceKey: '', comicId: 'jm123');

      expect(id.storageKey, 'jm123');
    });

    test('separates the same comic id across sources', () {
      const first = SourceScopedComicId(sourceKey: 'jm', comicId: '123');
      const second = SourceScopedComicId(sourceKey: 'other', comicId: '123');

      expect(first.storageKey, isNot(second.storageKey));
      expect(first.storageKey, 'jm::123');
      expect(second.storageKey, 'other::123');
    });

    test('parses legacy storage keys with fallback source key', () {
      final parsed = SourceScopedComicId.fromStorageKey(
        '123',
        fallbackSourceKey: 'jm',
      );

      expect(parsed.sourceKey, 'jm');
      expect(parsed.comicId, '123');
      expect(parsed.storageKey, 'jm::123');
    });

    test('uses the same scoped value for image cache keys', () {
      const id = SourceScopedComicId(
        sourceKey: 'jm',
        comicId: 'https://example.test/cover.jpg',
      );

      expect(id.imageCacheKey, 'jm::https://example.test/cover.jpg');
    });

    test('builds filesystem-safe download directory names', () {
      const id = SourceScopedComicId(sourceKey: 'jm', comicId: '12:3/4');

      expect(id.downloadDirName, 'jm__12_3_4');
    });

    test('matches legacy unscoped keys only for legacy identities', () {
      const legacy = SourceScopedComicId(sourceKey: '', comicId: '123');
      const scoped = SourceScopedComicId(sourceKey: 'jm', comicId: '123');

      expect(legacy.matchesStorageKey('123'), isTrue);
      expect(scoped.matchesStorageKey('jm::123'), isTrue);
      expect(scoped.matchesStorageKey('123'), isFalse);
    });
  });
}
