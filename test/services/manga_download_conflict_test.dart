import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_recovery_rules_support.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'download conflict only includes locally downloaded selected chapters',
    () async {
      const downloaded = DownloadedMangaComic(
        comicId: 'comic-id',
        sourceKey: 'jm',
        title: 'Hazuki',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [
          DownloadedMangaChapter(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
            imagePaths: ['C:/downloads/Hazuki/MangaChapter001/0001.jpg'],
          ),
        ],
        updatedAtMillis: 1,
      );
      SharedPreferences.setMockInitialValues({
        'manga_download_service_state_v2': jsonEncode({
          'tasks': const [],
          'downloaded': [downloaded.toJson()],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);

      final conflict = await service.checkDownloadConflict(
        details: _details(sourceKey: 'jm'),
        chapters: const [
          MangaChapterDownloadTarget(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
          ),
          MangaChapterDownloadTarget(
            epId: 'ep-2',
            title: 'Chapter 2',
            index: 1,
          ),
        ],
      );
      final otherSourceConflict = await service.checkDownloadConflict(
        details: _details(sourceKey: 'copy_manga'),
        chapters: const [
          MangaChapterDownloadTarget(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
          ),
        ],
      );

      expect(conflict.hasConflict, isTrue);
      expect(conflict.existingChapters.map((chapter) => chapter.epId), [
        'ep-1',
      ]);
      expect(otherSourceConflict.hasConflict, isFalse);
    },
  );

  test('legacy JM download matches by comic id and chapter index', () async {
    const downloaded = DownloadedMangaComic(
      comicId: 'comic-id',
      title: 'Hazuki',
      subTitle: '',
      description: '',
      coverUrl: '',
      localCoverPath: null,
      chapters: [
        DownloadedMangaChapter(
          epId: 'local_1',
          title: 'Chapter 1',
          index: 0,
          imagePaths: ['C:/downloads/Hazuki/MangaChapter001/0001.jpg'],
        ),
      ],
      updatedAtMillis: 1,
    );
    SharedPreferences.setMockInitialValues({
      'manga_download_service_state_v2': jsonEncode({
        'tasks': const [],
        'downloaded': [downloaded.toJson()],
      }),
    });
    final service = MangaDownloadService();
    addTearDown(service.dispose);

    final jmConflict = await service.checkDownloadConflict(
      details: _details(sourceKey: 'jm'),
      chapters: const [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
      ],
    );
    final otherSourceConflict = await service.checkDownloadConflict(
      details: _details(sourceKey: 'copy_manga'),
      chapters: const [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
      ],
    );

    expect(jmConflict.hasConflict, isTrue);
    expect(otherSourceConflict.hasConflict, isFalse);
  });

  test(
    'restoring merges legacy and scoped JM chapters into one comic',
    () async {
      const legacy = DownloadedMangaComic(
        comicId: 'comic-id',
        title: 'Hazuki',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [
          DownloadedMangaChapter(
            epId: 'local_1',
            title: 'Chapter 1',
            index: 0,
            imagePaths: ['C:/downloads/Hazuki/MangaChapter001/0001.jpg'],
          ),
        ],
        updatedAtMillis: 1,
      );
      const scoped = DownloadedMangaComic(
        comicId: 'comic-id',
        sourceKey: 'jm',
        title: 'Hazuki',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [
          DownloadedMangaChapter(
            epId: 'ep-2',
            title: 'Chapter 2',
            index: 1,
            imagePaths: ['C:/downloads/Hazuki/MangaChapter002/0001.jpg'],
          ),
        ],
        updatedAtMillis: 2,
      );
      SharedPreferences.setMockInitialValues({
        'manga_download_service_state_v2': jsonEncode({
          'tasks': const [],
          'downloaded': [legacy.toJson(), scoped.toJson()],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);

      await service.ensureInitialized();

      expect(service.downloadedComics, hasLength(1));
      expect(service.downloadedComics.single.storageKey, 'jm::comic-id');
      expect(
        service.downloadedComics.single.chapters.map(
          (chapter) => chapter.index,
        ),
        [0, 1],
      );
    },
  );

  test(
    'legacy redownload removes the old chapter and queues it again',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'hazuki-download-conflict-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final comicDir = Directory('${root.path}/comic-id');
      final chapterDir = Directory('${comicDir.path}/MangaChapter001');
      await chapterDir.create(recursive: true);
      final image = File('${chapterDir.path}/0001.jpg');
      await image.writeAsString('old image');
      final metadata = File('${comicDir.path}/comic.json');
      await metadata.writeAsString('{}');
      final downloaded = DownloadedMangaComic(
        comicId: 'comic-id',
        title: 'Hazuki',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [
          DownloadedMangaChapter(
            epId: 'local_1',
            title: 'Chapter 1',
            index: 0,
            imagePaths: [image.path],
          ),
        ],
        updatedAtMillis: 1,
      );
      SharedPreferences.setMockInitialValues({
        'manga_download_root_path_v1': root.path,
        'manga_download_service_state_v2': jsonEncode({
          'tasks': const [],
          'downloaded': [downloaded.toJson()],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);
      await service.ensureInitialized();
      service.handleAppLifecycleState(AppLifecycleState.detached);

      await service.enqueueDownload(
        details: _details(sourceKey: 'jm'),
        coverUrl: '',
        description: '',
        chapters: const [
          MangaChapterDownloadTarget(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
          ),
        ],
        redownloadExisting: true,
      );

      expect(await chapterDir.exists(), isFalse);
      expect(await metadata.exists(), isFalse);
      expect(service.downloadedComics, isEmpty);
      expect(service.tasks, hasLength(1));
      expect(service.tasks.single.targets.single.epId, 'ep-1');
    },
  );

  test('metadata recovery preserves source key', () {
    final rules = MangaDownloadRecoveryRules(
      taskByComicId: (_) => null,
      chapterDirForTarget: (comicDir, target) => comicDir,
    );

    final recovered = rules.sanitizeRecoveredComic(
      comicId: 'comic-id',
      comic: const DownloadedMangaComic(
        comicId: 'comic-id',
        sourceKey: 'copy_manga',
        title: 'Hazuki',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [],
        updatedAtMillis: 1,
      ),
      localCoverPath: null,
      chapters: const [],
      updatedAtMillis: 2,
    );

    expect(recovered.sourceKey, 'copy_manga');
  });

  test(
    'scan skips a source-scoped comic directory while downloading',
    () async {
      final root = await Directory.systemTemp.createTemp('hazuki-active-scan-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      const task = MangaDownloadTask(
        comicId: 'comic-id',
        sourceKey: 'jm',
        title: 'Hazuki',
        subTitle: '',
        description: '',
        coverUrl: '',
        targets: [
          MangaChapterDownloadTarget(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
          ),
          MangaChapterDownloadTarget(
            epId: 'ep-2',
            title: 'Chapter 2',
            index: 1,
          ),
        ],
        completedEpIds: {'ep-1'},
        status: MangaDownloadTaskStatus.paused,
        createdAtMillis: 1,
        updatedAtMillis: 1,
      );
      final comicDir = Directory('${root.path}/${task.downloadDirName}');
      final chapterDir = Directory('${comicDir.path}/MangaChapter001');
      await chapterDir.create(recursive: true);
      final image = File('${chapterDir.path}/0001.jpg');
      await image.writeAsString('image');
      final partialComic = DownloadedMangaComic(
        comicId: task.comicId,
        sourceKey: task.sourceKey,
        title: task.title,
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [
          DownloadedMangaChapter(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
            imagePaths: [image.path],
          ),
        ],
        updatedAtMillis: 1,
      );
      await File(
        '${comicDir.path}/comic.json',
      ).writeAsString(jsonEncode(partialComic.toJson()));
      SharedPreferences.setMockInitialValues({
        'manga_download_root_path_v1': root.path,
        'manga_download_service_state_v2': jsonEncode({
          'tasks': [task.toJson()],
          'downloaded': const [],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);

      final result = await service.scanDownloadedComics();

      expect(result.scannedDirectories, 1);
      expect(result.recoveredComics, 0);
      expect(service.downloadedComics, isEmpty);
    },
  );

  test('integrity check only reports missing chapter images', () async {
    final root = await Directory.systemTemp.createTemp('hazuki-integrity-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final chapterDir = Directory('${root.path}/jm__comic-id/MangaChapter001');
    await chapterDir.create(recursive: true);
    final image = File('${chapterDir.path}/0001.jpg');
    await image.writeAsString('image');
    final downloaded = DownloadedMangaComic(
      comicId: 'comic-id',
      sourceKey: 'jm',
      title: 'Hazuki',
      subTitle: '',
      description: '',
      coverUrl: 'https://example.com/cover.jpg',
      localCoverPath: '${root.path}/jm__comic-id/cover.jpg',
      chapters: [
        DownloadedMangaChapter(
          epId: 'ep-1',
          title: 'Chapter 1',
          index: 0,
          imagePaths: [image.path],
        ),
      ],
      updatedAtMillis: 1,
    );
    SharedPreferences.setMockInitialValues({
      'manga_download_root_path_v1': root.path,
      'manga_download_service_state_v2': jsonEncode({
        'tasks': const [],
        'downloaded': [downloaded.toJson()],
      }),
    });
    final service = MangaDownloadService();
    addTearDown(service.dispose);
    await service.ensureInitialized();

    expect(await service.checkDownloadedIntegrity(), isEmpty);

    await image.delete();
    expect(await service.checkDownloadedIntegrity(), {'jm::comic-id'});
  });
}

ComicDetailsData _details({required String sourceKey}) {
  return ComicDetailsData(
    id: 'comic-id',
    sourceKey: sourceKey,
    title: 'Hazuki',
    subTitle: '',
    cover: '',
    description: '',
    updateTime: '',
    likesCount: '',
    chapters: const {'ep-1': 'Chapter 1', 'ep-2': 'Chapter 2'},
    tags: const {},
    recommend: const [],
    isFavorite: false,
    subId: '',
  );
}
