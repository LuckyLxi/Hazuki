import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/state/downloads_page_controller.dart';
import 'package:hazuki/services/download_groups/download_groups_repository.dart';
import 'package:hazuki/services/manga_download/manga_download_library.dart';
import 'package:mocktail/mocktail.dart';

class _Downloads extends Mock implements MangaDownloadLibrary {}

class _Groups extends Mock implements DownloadGroupsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(() {}));

  late _Downloads downloads;
  late _Groups groups;
  late DownloadsPageController controller;

  setUp(() {
    downloads = _Downloads();
    groups = _Groups();
    when(() => downloads.tasks).thenReturn(const []);
    when(() => downloads.downloadedComics).thenReturn(const [_comic]);
    when(() => downloads.ensureInitialized()).thenAnswer((_) async {});
    when(
      () => groups.initialize(
        any(),
        migratedComicKeys: any(named: 'migratedComicKeys'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => groups.reconcileDownloadedComics(
        any(),
        migratedComicKeys: any(named: 'migratedComicKeys'),
      ),
    ).thenAnswer((_) async {});
    controller = DownloadsPageController(
      downloadService: downloads,
      downloadGroupsService: groups,
    );
  });

  test(
    'initializes groups after downloads and preserves legacy keys',
    () async {
      addTearDown(controller.dispose);
      final ready = Completer<void>();
      when(() => downloads.ensureInitialized()).thenAnswer((_) => ready.future);

      final initialization = controller.initialize();
      verifyNever(
        () => groups.initialize(
          any(),
          migratedComicKeys: any(named: 'migratedComicKeys'),
        ),
      );
      ready.complete();
      await initialization;

      final arguments = verify(
        () => groups.initialize(
          captureAny(),
          migratedComicKeys: captureAny(named: 'migratedComicKeys'),
        ),
      ).captured;
      expect(arguments[0], [_comic.storageKey]);
      expect(arguments[1], {'comic': _comic.storageKey});
    },
  );

  test(
    'forwards state changes and removes both subscriptions on dispose',
    () async {
      final downloadChanged =
          verify(() => downloads.addListener(captureAny())).captured.single
              as VoidCallback;
      final groupsChanged =
          verify(() => groups.addListener(captureAny())).captured.single
              as VoidCallback;
      var notifications = 0;
      controller.addListener(() => notifications++);

      final previousTasks = controller.tasks;
      when(() => downloads.tasks).thenReturn([_task]);
      downloadChanged();
      expect(notifications, 1);
      expect(controller.tasks, [_task]);
      expect(previousTasks, isEmpty);
      expect(() => controller.tasks.clear(), throwsUnsupportedError);
      await Future<void>.delayed(Duration.zero);

      groupsChanged();
      expect(notifications, 2);
      controller.dispose();
      verify(() => downloads.removeListener(downloadChanged)).called(1);
      verify(() => groups.removeListener(groupsChanged)).called(1);
      verifyNever(() => downloads.addListener(any()));
      verifyNever(() => groups.addListener(any()));
    },
  );

  test('filters the library using group membership from the contract', () {
    addTearDown(controller.dispose);
    when(
      () => groups.comicKeysForGroup('custom'),
    ).thenReturn({_comic.storageKey});
    controller.selectGroup('custom');
    expect(controller.filteredDownloadedComics, [_comic]);
    expect(controller.comicCountForGroup('custom'), 1);

    when(() => groups.comicKeysForGroup('custom')).thenReturn({'remote-only'});
    expect(controller.filteredDownloadedComics, isEmpty);
    expect(controller.comicCountForGroup('custom'), 0);
  });

  test('manages tasks through the library contract', () async {
    addTearDown(controller.dispose);
    when(() => downloads.pauseTask(any())).thenAnswer((_) async {});
    when(() => downloads.resumeTask(any())).thenAnswer((_) async {});
    when(() => downloads.pauseAllTasks()).thenAnswer((_) async {});
    when(() => downloads.resumeAllTasks()).thenAnswer((_) async {});
    when(
      () => downloads.checkDownloadedIntegrity(),
    ).thenAnswer((_) async => {_comic.storageKey});

    await controller.pauseTask(_task.storageKey);
    await controller.resumeTask(_task.storageKey);
    await controller.pauseAllTasks();
    await controller.resumeAllTasks();
    await controller.runIntegrityCheck();

    verifyInOrder([
      () => downloads.pauseTask(_task.storageKey),
      () => downloads.resumeTask(_task.storageKey),
      () => downloads.pauseAllTasks(),
      () => downloads.resumeAllTasks(),
      () => downloads.checkDownloadedIntegrity(),
    ]);
    expect(controller.comicsWithIntegrityIssues, {_comic.storageKey});
  });
}

const _comic = DownloadedMangaComic(
  comicId: 'comic',
  sourceKey: 'jm',
  title: 'Comic',
  subTitle: '',
  description: '',
  coverUrl: '',
  localCoverPath: null,
  chapters: [],
  updatedAtMillis: 0,
);

const _task = MangaDownloadTask(
  comicId: 'comic',
  sourceKey: 'jm',
  title: 'Comic',
  subTitle: '',
  description: '',
  coverUrl: '',
  targets: [],
  completedEpIds: {},
  status: MangaDownloadTaskStatus.paused,
  createdAtMillis: 0,
  updatedAtMillis: 0,
);
