import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/manga_download_models.dart';

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

    test('downloaded comic json roundtrips sourceKey', () {
      const comic = DownloadedMangaComic(
        comicId: '123',
        sourceKey: 'jm',
        title: 'Title',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [],
        updatedAtMillis: 1,
      );

      final restored = DownloadedMangaComic.fromJson(comic.toJson());

      expect(restored.sourceKey, 'jm');
      expect(restored.storageKey, 'jm::123');
      expect(restored.downloadDirName, 'jm__123');
    });

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
