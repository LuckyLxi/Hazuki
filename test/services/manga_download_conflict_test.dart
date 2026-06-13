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
