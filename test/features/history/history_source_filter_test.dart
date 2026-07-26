import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
  });

  group('ReadHistoryService source filtering', () {
    test('treats legacy empty sourceKey entries as JM history', () async {
      final service = sl<ReadHistoryService>();

      await service.importJsonList([
        {
          'id': 'legacy-id',
          'title': 'Legacy',
          'cover': 'https://example.test/cover.jpg',
          'subTitle': 'Old',
          'tags': ['Action'],
          'sourceKey': '',
          'timestamp': 12,
        },
      ], replace: true);

      final jmHistory = await service.loadHistory(
        sourceKey: hazukiDefaultSourceKey,
      );
      final copyHistory = await service.loadHistory(sourceKey: 'copy_manga');

      expect(jmHistory, hasLength(1));
      expect(jmHistory.single.id, 'legacy-id');
      expect(jmHistory.single.sourceKey, hazukiDefaultSourceKey);
      expect(jmHistory.single.tags, ['Action']);
      expect(copyHistory, isEmpty);
    });

    test(
      'matches only the requested source for scoped history entries',
      () async {
        final service = sl<ReadHistoryService>();

        await service.importJsonList([
          {
            'id': 'same-id',
            'title': 'Copy',
            'sourceKey': 'copy_manga',
            'timestamp': 2,
          },
          {
            'id': 'same-id',
            'title': 'JM',
            'sourceKey': hazukiDefaultSourceKey,
            'timestamp': 1,
          },
        ], replace: true);

        final copyHistory = await service.loadHistory(sourceKey: 'copy_manga');
        final jmHistory = await service.loadHistory(
          sourceKey: hazukiDefaultSourceKey,
        );

        expect(copyHistory, hasLength(1));
        expect(copyHistory.single.title, 'Copy');
        expect(copyHistory.single.sourceKey, 'copy_manga');
        expect(jmHistory, hasLength(1));
        expect(jmHistory.single.title, 'JM');
        expect(jmHistory.single.sourceKey, hazukiDefaultSourceKey);
      },
    );

    test('replaces only the requested source history', () async {
      final service = sl<ReadHistoryService>();

      await service.importJsonList([
        {
          'id': 'copy-old',
          'title': 'Copy old',
          'sourceKey': 'copy_manga',
          'timestamp': 2,
        },
        {
          'id': 'jm-old',
          'title': 'JM old',
          'sourceKey': hazukiDefaultSourceKey,
          'timestamp': 1,
        },
      ], replace: true);

      await service.replaceSourceHistory(
        sourceKey: 'copy_manga',
        history: const [
          ExploreComic(
            id: 'copy-new',
            title: 'Copy new',
            subTitle: '',
            cover: '',
            sourceKey: 'copy_manga',
          ),
        ],
      );

      final copyHistory = await service.loadHistory(sourceKey: 'copy_manga');
      final jmHistory = await service.loadHistory(
        sourceKey: hazukiDefaultSourceKey,
      );

      expect(copyHistory.map((comic) => comic.id), ['copy-new']);
      expect(jmHistory.map((comic) => comic.id), ['jm-old']);
    });

    test('deletes entries without rewriting remaining timestamps', () async {
      final service = sl<ReadHistoryService>();

      await service.importJsonList([
        {
          'id': 'oldest',
          'title': 'Oldest',
          'sourceKey': hazukiDefaultSourceKey,
          'timestamp': 1,
        },
        {
          'id': 'middle',
          'title': 'Middle',
          'sourceKey': hazukiDefaultSourceKey,
          'timestamp': 2,
        },
        {
          'id': 'newest',
          'title': 'Newest',
          'sourceKey': hazukiDefaultSourceKey,
          'timestamp': 3,
        },
      ], replace: true);

      await service.deleteSourceHistoryEntries(
        sourceKey: hazukiDefaultSourceKey,
        storageKeys: {
          const ExploreComic(
            id: 'middle',
            title: 'Middle',
            subTitle: '',
            cover: '',
            sourceKey: hazukiDefaultSourceKey,
          ).scopedId.storageKey,
        },
      );

      final history = await service.loadHistory(
        sourceKey: hazukiDefaultSourceKey,
      );

      expect(history.map((comic) => comic.id), ['newest', 'oldest']);
    });

    test('exports sourceKey and timestamp metadata', () async {
      final service = sl<ReadHistoryService>();

      await service.importJsonList([
        {
          'id': 'comic-id',
          'title': 'Comic',
          'sourceKey': 'copy_manga',
          'timestamp': 123,
        },
      ], replace: true);

      final exported = await service.exportJsonList();

      expect(exported, hasLength(1));
      expect(exported.single['id'], 'comic-id');
      expect(exported.single['sourceKey'], 'copy_manga');
      expect(exported.single['timestamp'], 123);
    });
  });
}
