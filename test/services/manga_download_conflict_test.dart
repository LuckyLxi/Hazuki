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

  test('deleting a migrated download removes its legacy directory', () async {
    final root = await Directory.systemTemp.createTemp(
      'hazuki-delete-legacy-download-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    const comicId = 'comic-id';
    final legacyComicDir = Directory('${root.path}/$comicId');
    final chapterDir = Directory('${legacyComicDir.path}/MangaChapter001');
    await chapterDir.create(recursive: true);
    final image = File('${chapterDir.path}/0001.jpg');
    await image.writeAsString('downloaded image');
    final downloaded = DownloadedMangaComic(
      comicId: comicId,
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

    await service.deleteDownloadedComics([downloaded.storageKey]);

    expect(await legacyComicDir.exists(), isFalse);
    expect(service.downloadedComics, isEmpty);
  });

  test(
    'deleting a scanned download removes its directory from image paths',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'hazuki-delete-scanned-download-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final comicDir = Directory('${root.path}/jm__comic-id');
      final chapterDir = Directory('${comicDir.path}/MangaChapter001');
      await chapterDir.create(recursive: true);
      final image = File('${chapterDir.path}/0001.jpg');
      await image.writeAsString('downloaded image');
      final scanned = DownloadedMangaComic(
        // Older versions can restore an ID that no longer matches the folder
        // name, while retaining the correct paths to the downloaded images.
        comicId: 'old-scan-id',
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
          'downloaded': [scanned.toJson()],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);
      await service.ensureInitialized();

      await service.deleteDownloadedComics([scanned.storageKey]);

      expect(await comicDir.exists(), isFalse);
      expect(service.downloadedComics, isEmpty);
    },
  );

  test(
    'deleting another source does not remove a legacy JM directory',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'hazuki-preserve-legacy-download-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      const comicId = 'comic-id';
      final legacyComicDir = Directory('${root.path}/$comicId');
      final otherSource = DownloadedMangaComic(
        comicId: comicId,
        sourceKey: 'copy_manga',
        title: 'Other source',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: const [],
        updatedAtMillis: 2,
      );
      final otherSourceDir = Directory(
        '${root.path}/${otherSource.downloadDirName}',
      );
      final legacyChapterDir = Directory(
        '${legacyComicDir.path}/MangaChapter001',
      );
      await legacyChapterDir.create(recursive: true);
      final legacyImage = File('${legacyChapterDir.path}/0001.jpg');
      await legacyImage.writeAsString('downloaded image');
      await otherSourceDir.create();
      final migratedJm = DownloadedMangaComic(
        comicId: comicId,
        sourceKey: 'jm',
        title: 'JM',
        subTitle: '',
        description: '',
        coverUrl: '',
        localCoverPath: null,
        chapters: [
          DownloadedMangaChapter(
            epId: 'ep-1',
            title: 'Chapter 1',
            index: 0,
            imagePaths: [legacyImage.path],
          ),
        ],
        updatedAtMillis: 1,
      );
      SharedPreferences.setMockInitialValues({
        'manga_download_root_path_v1': root.path,
        'manga_download_service_state_v2': jsonEncode({
          'tasks': const [],
          'downloaded': [migratedJm.toJson(), otherSource.toJson()],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);
      await service.ensureInitialized();

      await service.deleteDownloadedComics([otherSource.storageKey]);

      expect(await legacyComicDir.exists(), isTrue);
      expect(await otherSourceDir.exists(), isFalse);
      expect(service.downloadedComics.single.storageKey, migratedJm.storageKey);
    },
  );

  test('redownload tolerates the existing task being removed', () async {
    final root = await Directory.systemTemp.createTemp(
      'hazuki-redownload-task-race-',
    );
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
        MangaChapterDownloadTarget(epId: 'ep-0', title: 'Chapter 0', index: 0),
      ],
      completedEpIds: {},
      status: MangaDownloadTaskStatus.paused,
      createdAtMillis: 1,
      updatedAtMillis: 1,
    );
    final comicDir = Directory('${root.path}/${task.downloadDirName}');
    final chapterDir = Directory('${comicDir.path}/MangaChapter002');
    await chapterDir.create(recursive: true);
    final imagePaths = <String>[];
    for (var index = 0; index < 100; index++) {
      final image = File('${chapterDir.path}/$index.jpg');
      await image.writeAsString('old image');
      imagePaths.add(image.path);
    }
    final downloaded = DownloadedMangaComic(
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
          index: 1,
          imagePaths: imagePaths,
        ),
      ],
      updatedAtMillis: 1,
    );
    SharedPreferences.setMockInitialValues({
      'manga_download_root_path_v1': root.path,
      'manga_download_service_state_v2': jsonEncode({
        'tasks': [task.toJson()],
        'downloaded': [downloaded.toJson()],
      }),
    });
    final service = MangaDownloadService();
    addTearDown(service.dispose);
    await service.ensureInitialized();
    service.handleAppLifecycleState(AppLifecycleState.detached);

    final enqueueFuture = service.enqueueDownload(
      details: _details(sourceKey: 'jm'),
      coverUrl: '',
      description: '',
      chapters: const [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 1),
      ],
      redownloadExisting: true,
    );
    await Future<void>.delayed(Duration.zero);
    await service.deleteTask(task.storageKey);
    final result = await enqueueFuture;

    expect(result, MangaDownloadEnqueueResult.queued);
    expect(service.tasks, hasLength(1));
    expect(service.tasks.single.targets.map((target) => target.epId), ['ep-1']);
  });

  test('enqueue rejects a chapter that is already in download tasks', () async {
    const existingTask = MangaDownloadTask(
      comicId: 'comic-id',
      sourceKey: 'jm',
      title: 'Hazuki',
      subTitle: '',
      description: '',
      coverUrl: '',
      targets: [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
      ],
      completedEpIds: {},
      status: MangaDownloadTaskStatus.paused,
      createdAtMillis: 1,
      updatedAtMillis: 1,
    );
    SharedPreferences.setMockInitialValues({
      'manga_download_service_state_v2': jsonEncode({
        'tasks': [existingTask.toJson()],
        'downloaded': const [],
      }),
    });
    final service = MangaDownloadService();
    addTearDown(service.dispose);

    final conflict = await service.checkDownloadTaskConflict(
      details: _details(sourceKey: 'jm'),
      chapters: const [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
        MangaChapterDownloadTarget(epId: 'ep-2', title: 'Chapter 2', index: 1),
      ],
    );
    final result = await service.enqueueDownload(
      details: _details(sourceKey: 'jm'),
      coverUrl: 'new-cover',
      description: 'new-description',
      chapters: const [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
      ],
    );

    expect(conflict.existingChapters.map((target) => target.epId), ['ep-1']);
    expect(result, MangaDownloadEnqueueResult.alreadyQueued);
    expect(service.tasks, hasLength(1));
    expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
    expect(service.tasks.single.targets.map((target) => target.epId), ['ep-1']);
    expect(service.tasks.single.coverUrl, isEmpty);
  });

  test(
    'enqueue appends a different chapter to the existing comic task',
    () async {
      const existingTask = MangaDownloadTask(
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
        ],
        completedEpIds: {},
        status: MangaDownloadTaskStatus.paused,
        createdAtMillis: 1,
        updatedAtMillis: 1,
      );
      SharedPreferences.setMockInitialValues({
        'manga_download_service_state_v2': jsonEncode({
          'tasks': [existingTask.toJson()],
          'downloaded': const [],
        }),
      });
      final service = MangaDownloadService();
      addTearDown(service.dispose);

      final result = await service.enqueueDownload(
        details: _details(sourceKey: 'jm'),
        coverUrl: '',
        description: '',
        chapters: const [
          MangaChapterDownloadTarget(
            epId: 'ep-2',
            title: 'Chapter 2',
            index: 1,
          ),
        ],
      );

      expect(result, MangaDownloadEnqueueResult.queued);
      expect(service.tasks, hasLength(1));
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(service.tasks.single.targets.map((target) => target.epId), [
        'ep-1',
        'ep-2',
      ]);
    },
  );

  test('concurrent enqueue calls create only one task per comic', () async {
    SharedPreferences.setMockInitialValues({
      'manga_download_service_state_v2': jsonEncode({
        'tasks': const [],
        'downloaded': const [],
      }),
    });
    final service = MangaDownloadService();
    addTearDown(service.dispose);
    await service.ensureInitialized();
    service.handleAppLifecycleState(AppLifecycleState.detached);

    final results = await Future.wait([
      service.enqueueDownload(
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
      ),
      service.enqueueDownload(
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
      ),
    ]);

    expect(results, contains(MangaDownloadEnqueueResult.queued));
    expect(results, contains(MangaDownloadEnqueueResult.alreadyQueued));
    expect(service.tasks, hasLength(1));
    expect(service.tasks.single.targets, hasLength(1));
  });

  test('restore merges duplicate tasks for the same comic', () async {
    const firstTask = MangaDownloadTask(
      comicId: 'comic-id',
      sourceKey: 'jm',
      title: 'Hazuki',
      subTitle: '',
      description: '',
      coverUrl: '',
      targets: [
        MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
      ],
      completedEpIds: {'ep-1'},
      status: MangaDownloadTaskStatus.paused,
      createdAtMillis: 1,
      updatedAtMillis: 1,
    );
    const secondTask = MangaDownloadTask(
      comicId: 'comic-id',
      sourceKey: 'jm',
      title: 'Hazuki',
      subTitle: '',
      description: '',
      coverUrl: '',
      targets: [
        MangaChapterDownloadTarget(epId: 'ep-2', title: 'Chapter 2', index: 1),
      ],
      completedEpIds: {},
      status: MangaDownloadTaskStatus.paused,
      createdAtMillis: 2,
      updatedAtMillis: 2,
    );
    SharedPreferences.setMockInitialValues({
      'manga_download_service_state_v2': jsonEncode({
        'tasks': [firstTask.toJson(), secondTask.toJson()],
        'downloaded': const [],
      }),
    });
    final service = MangaDownloadService();
    addTearDown(service.dispose);

    await service.ensureInitialized();

    expect(service.tasks, hasLength(1));
    expect(service.tasks.single.targets.map((target) => target.epId), [
      'ep-1',
      'ep-2',
    ]);
    expect(service.tasks.single.completedEpIds, {'ep-1'});
  });

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
