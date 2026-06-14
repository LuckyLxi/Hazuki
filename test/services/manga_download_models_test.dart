import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

void main() {
  group('Manga download source identity', () {
    test('task json roundtrips sourceKey', () {
      const task = MangaDownloadTask(
        comicId: '123',
        sourceKey: 'jm',
        title: 'Title',
        subTitle: '',
        description: '',
        coverUrl: '',
        tags: {
          '作者': ['Hazuki'],
          'views': ['100'],
          '点赞量': ['42'],
        },
        uploader: 'Uploader',
        updateTime: '2026-06-14',
        pageCount: '128',
        targets: [],
        completedEpIds: {},
        status: MangaDownloadTaskStatus.queued,
        createdAtMillis: 1,
        updatedAtMillis: 2,
      );

      final restored = MangaDownloadTask.fromJson(task.toJson());

      expect(restored.sourceKey, 'jm');
      expect(restored.storageKey, 'jm::123');
      expect(restored.downloadDirName, 'jm__123');
      expect(restored.tags['作者'], ['Hazuki']);
      expect(restored.tags, isNot(contains('views')));
      expect(restored.tags, isNot(contains('点赞量')));
      expect(restored.uploader, 'Uploader');
      expect(restored.updateTime, '2026-06-14');
      expect(restored.pageCount, '128');
    });

    test('legacy task json defaults sourceKey to empty', () {
      final restored = MangaDownloadTask.fromJson({
        'comicId': '123',
        'title': 'Legacy',
        'targets': const [],
        'completedEpIds': const [],
      });

      expect(restored.sourceKey, isEmpty);
      expect(restored.storageKey, '123');
      expect(restored.downloadDirName, '123');
    });

    test('downloaded comic json roundtrips source and detail metadata', () {
      const comic = DownloadedMangaComic(
        comicId: '123',
        sourceKey: 'jm',
        title: 'Title',
        subTitle: '',
        description: '',
        coverUrl: '',
        tags: {
          '作者': ['Hazuki'],
          '标签': ['治愈', '日常'],
          '浏览量': ['100'],
          'likes': ['42'],
        },
        uploader: 'Uploader',
        updateTime: '2026-06-14',
        pageCount: '128',
        localCoverPath: null,
        chapters: [],
        updatedAtMillis: 1,
      );

      final restored = DownloadedMangaComic.fromJson(comic.toJson());

      expect(restored.sourceKey, 'jm');
      expect(restored.storageKey, 'jm::123');
      expect(restored.downloadDirName, 'jm__123');
      expect(restored.comicId, '123');
      expect(restored.tags['作者'], ['Hazuki']);
      expect(restored.tags['标签'], ['治愈', '日常']);
      expect(restored.tags, isNot(contains('浏览量')));
      expect(restored.tags, isNot(contains('likes')));
      expect(restored.uploader, 'Uploader');
      expect(restored.updateTime, '2026-06-14');
      expect(restored.pageCount, '128');
      expect(comic.toJson(), isNot(contains('likesCount')));
    });

    test('legacy downloaded comic json defaults detail metadata', () {
      final restored = DownloadedMangaComic.fromJson({
        'comicId': '123',
        'title': 'Legacy',
        'chapters': const [],
      });

      expect(restored.tags, isEmpty);
      expect(restored.uploader, isEmpty);
      expect(restored.updateTime, isEmpty);
      expect(restored.pageCount, isEmpty);
    });

    test(
      'task metadata merge preserves existing values when task is empty',
      () {
        const comic = DownloadedMangaComic(
          comicId: '123',
          sourceKey: 'jm',
          title: 'Existing title',
          subTitle: 'Existing subtitle',
          description: 'Existing description',
          coverUrl: 'existing-cover',
          tags: {
            '作者': ['Hazuki'],
          },
          uploader: 'Existing uploader',
          updateTime: 'Existing update time',
          pageCount: '128',
          localCoverPath: null,
          chapters: [],
          updatedAtMillis: 1,
        );
        const task = MangaDownloadTask(
          comicId: '123',
          sourceKey: 'jm',
          title: '',
          subTitle: ' ',
          description: '',
          coverUrl: '',
          tags: {
            'views': ['100'],
            '点赞量': ['42'],
          },
          targets: [],
          completedEpIds: {},
          status: MangaDownloadTaskStatus.queued,
          createdAtMillis: 1,
          updatedAtMillis: 1,
        );

        final merged = comic.mergeTaskMetadata(task);

        expect(merged.title, comic.title);
        expect(merged.subTitle, comic.subTitle);
        expect(merged.description, comic.description);
        expect(merged.coverUrl, comic.coverUrl);
        expect(merged.tags, comic.tags);
        expect(merged.uploader, comic.uploader);
        expect(merged.updateTime, comic.updateTime);
        expect(merged.pageCount, comic.pageCount);
      },
    );

    test(
      'task metadata merge replaces existing values with useful details',
      () {
        const comic = DownloadedMangaComic(
          comicId: '123',
          title: 'Existing title',
          subTitle: '',
          description: '',
          coverUrl: '',
          tags: {},
          localCoverPath: null,
          chapters: [],
          updatedAtMillis: 1,
        );
        const task = MangaDownloadTask(
          comicId: '123',
          title: 'Updated title',
          subTitle: 'Updated subtitle',
          description: 'Updated description',
          coverUrl: 'updated-cover',
          tags: {
            '作者': ['Hazuki'],
            'views': ['100'],
          },
          uploader: 'Uploader',
          updateTime: '2026-06-14',
          pageCount: '256',
          targets: [],
          completedEpIds: {},
          status: MangaDownloadTaskStatus.queued,
          createdAtMillis: 1,
          updatedAtMillis: 1,
        );

        final merged = comic.mergeTaskMetadata(task);

        expect(merged.title, task.title);
        expect(merged.subTitle, task.subTitle);
        expect(merged.description, task.description);
        expect(merged.coverUrl, task.coverUrl);
        expect(merged.tags, {
          '作者': ['Hazuki'],
        });
        expect(merged.uploader, task.uploader);
        expect(merged.updateTime, task.updateTime);
        expect(merged.pageCount, task.pageCount);
      },
    );

    test('uses storageKey to distinguish duplicate comic ids', () {
      const first = MangaDownloadTask(
        comicId: '123',
        sourceKey: 'jm',
        title: 'JM',
        subTitle: '',
        description: '',
        coverUrl: '',
        targets: [],
        completedEpIds: {},
        status: MangaDownloadTaskStatus.queued,
        createdAtMillis: 1,
        updatedAtMillis: 1,
      );
      const second = MangaDownloadTask(
        comicId: '123',
        sourceKey: 'other',
        title: 'Other',
        subTitle: '',
        description: '',
        coverUrl: '',
        targets: [],
        completedEpIds: {},
        status: MangaDownloadTaskStatus.queued,
        createdAtMillis: 1,
        updatedAtMillis: 1,
      );

      final tasksByStorageKey = {
        for (final task in [first, second]) task.storageKey: task,
      };

      expect(tasksByStorageKey, hasLength(2));
      expect(tasksByStorageKey['jm::123']?.title, 'JM');
      expect(tasksByStorageKey['other::123']?.title, 'Other');
    });
  });
}
