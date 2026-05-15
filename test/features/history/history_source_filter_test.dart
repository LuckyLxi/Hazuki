import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/history/view/history_page.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

void main() {
  group('history source filtering', () {
    test('treats legacy empty sourceKey entries as JM history', () {
      final entry = <String, dynamic>{
        'id': 'legacy-id',
        'title': 'Legacy',
        'cover': 'https://example.test/cover.jpg',
        'subTitle': 'Old',
      };

      expect(
        historyEntryBelongsToSource(entry, hazukiDefaultSourceKey),
        isTrue,
      );
      expect(historyEntryBelongsToSource(entry, 'copy_manga'), isFalse);

      final comic = historyComicFromEntry(
        entry,
        fallbackSourceKey: hazukiDefaultSourceKey,
      );
      expect(comic.sourceKey, hazukiDefaultSourceKey);
      expect(comic.id, 'legacy-id');
    });

    test('matches only the requested source for scoped history entries', () {
      final copyEntry = <String, dynamic>{
        'id': 'same-id',
        'title': 'Copy',
        'sourceKey': 'copy_manga',
      };
      final jmEntry = <String, dynamic>{
        'id': 'same-id',
        'title': 'JM',
        'sourceKey': hazukiDefaultSourceKey,
      };

      expect(historyEntryBelongsToSource(copyEntry, 'copy_manga'), isTrue);
      expect(
        historyEntryBelongsToSource(copyEntry, hazukiDefaultSourceKey),
        isFalse,
      );
      expect(
        historyEntryBelongsToSource(jmEntry, hazukiDefaultSourceKey),
        isTrue,
      );
      expect(historyEntryBelongsToSource(jmEntry, 'copy_manga'), isFalse);
    });
  });
}
