import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_files.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';
import 'package:hazuki/services/manga_download/manga_download_queue_support.dart';
import 'package:hazuki/services/manga_download/manga_download_state.dart';
import 'package:hazuki/services/manga_download/manga_download_storage_support.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  late Directory root;
  late MangaDownloadState state;
  late MangaDownloadFiles files;
  late MangaDownloadQueueExecutor queue;
  late _Reader reader;
  late bool suspended;
  late bool recoverTransient;
  late List<List<MangaDownloadTask>> flushedTasks;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hazuki-download-queue-');
    state = MangaDownloadState();
    reader = _Reader();
    files = MangaDownloadFiles(sourceReader: reader, logScan: _log);
    suspended = false;
    recoverTransient = false;
    flushedTasks = [];
    queue = MangaDownloadQueueExecutor(
      state: state,
      files: files,
      access: _Access(root),
      sourceReader: reader,
      logDownload: _log,
      flushState: () async {
        flushedTasks.add(state.tasks);
      },
      shouldSuspendDownloads: () => suspended,
      shouldRecoverTransientNetworkError: () => recoverTransient,
    );
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'queue writes source-scoped chapters and metadata and reuses its cover',
    () async {
      final task = _task();
      state.restoreTasks([task]);
      await queue.processQueue();
      expect(state.tasks, isEmpty);
      final comic = state.downloadedComics.single;
      expect(comic.sourceKey, 'jm');
      expect(comic.chapters.single.epId, 'ep-1');
      final image = File(comic.chapters.single.imagePaths.single);
      expect(
        image.path.replaceAll('\\', '/'),
        endsWith('/MangaChapter001/0001.png'),
      );
      expect(await image.readAsBytes(), [1, 2, 3]);
      expect(reader.scopes, everyElement('jm'));
      final metadata = File('${root.path}/${task.downloadDirName}/comic.json');
      expect(jsonDecode(await metadata.readAsString())['sourceKey'], 'jm');
      expect(
        flushedTasks.first.single.status,
        MangaDownloadTaskStatus.downloading,
      );
      expect(flushedTasks.last, isEmpty);

      state.enqueue(
        details: _details(),
        coverUrl: 'cover',
        description: '',
        chapters: [_target(2)],
      );
      await queue.processQueue();
      expect(reader.coverDownloads, 1);
      expect(state.downloadedComics.single.chapters.map((c) => c.epId), [
        'ep-1',
        'ep-2',
      ]);
    },
  );

  test(
    'same comic ID in two sources stays separate on disk and in state',
    () async {
      state.restoreTasks([_task(), _task(sourceKey: 'copy_manga')]);
      await queue.processQueue();
      expect(state.downloadedComics.map((c) => c.storageKey).toSet(), {
        'jm::comic',
        'copy_manga::comic',
      });
      final paths = state.downloadedComics
          .map((c) => c.chapters.single.imagePaths.single)
          .toSet();
      expect(paths.length, 2);
      for (final path in paths) {
        expect(await File(path).exists(), isTrue);
      }
    },
  );

  test(
    'appending a chapter during download survives older progress updates',
    () async {
      state.restoreTasks([_task()]);
      final entered = Completer<void>();
      final release = Completer<List<String>>();
      reader.load = (epId) {
        if (epId == 'ep-1') {
          entered.complete();
          return release.future;
        }
        return Future.value(['second']);
      };
      final running = queue.processQueue();
      await entered.future;
      await queue.processQueue();
      expect(reader.chapters, ['ep-1']);
      state.enqueue(
        details: _details(),
        coverUrl: 'cover',
        description: '',
        chapters: [_target(2)],
      );
      release.complete(['first']);
      await running;
      expect(reader.chapters, ['ep-1', 'ep-2']);
      expect(state.tasks, isEmpty);
      expect(state.downloadedComics.single.chapters.map((c) => c.epId), [
        'ep-1',
        'ep-2',
      ]);
    },
  );

  test(
    'pausing an in-flight image prevents further work and permits resume',
    () async {
      final task = _task();
      state.restoreTasks([task]);
      final entered = Completer<void>();
      final image = Completer<PreparedChapterImageData>();
      reader.prepare = (_) {
        entered.complete();
        return image.future;
      };
      final running = queue.processQueue();
      await entered.future;
      state.pauseTask(task.storageKey);
      image.complete(_image());
      await running;
      expect(state.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(state.downloadedComics, isEmpty);
      reader.prepare = null;
      state.resumeTask(task.storageKey);
      await queue.processQueue();
      expect(state.tasks, isEmpty);
      expect(state.downloadedComics.single.chapters.length, 1);
    },
  );

  test('removing a task during an image request cannot resurrect it', () async {
    final task = _task();
    state.restoreTasks([task]);
    final entered = Completer<void>();
    final image = Completer<PreparedChapterImageData>();
    reader.prepare = (_) {
      entered.complete();
      return image.future;
    };
    final running = queue.processQueue();
    await entered.future;
    state.removeTask(task.storageKey);
    image.complete(_image());
    await running;
    expect(state.tasks, isEmpty);
    expect(state.downloadedComics, isEmpty);
  });

  test(
    'suspension requeues progress and resumes using the saved image',
    () async {
      state.restoreTasks([_task()]);
      reader.load = (_) async => ['first', 'second'];
      reader.prepare = (_) async {
        suspended = true;
        return _image();
      };
      await queue.processQueue();
      expect(state.tasks.single.status, MangaDownloadTaskStatus.queued);
      expect(state.tasks.single.currentImageIndex, 1);
      suspended = false;
      reader.prepare = null;
      await queue.processQueue();
      expect(reader.images, ['first', 'second']);
      expect(
        state.downloadedComics.single.chapters.single.imagePaths.length,
        2,
      );
    },
  );

  test(
    'transient errors retry only during recovery and stop after five attempts',
    () async {
      state.restoreTasks([_task()]);
      recoverTransient = true;
      reader.load = (_) async =>
          throw const SocketException('connection error');
      await queue.processQueue();
      expect(reader.chapters.length, 5);
      expect(state.tasks.single.status, MangaDownloadTaskStatus.failed);
      expect(state.tasks.single.retryCount, 0);
      expect(state.tasks.single.errorMessage, contains('connection error'));
      reader.chapters.clear();
      recoverTransient = false;
      state.resumeAllTasks();
      await queue.processQueue();
      expect(reader.chapters.length, 1);
      expect(state.tasks.single.status, MangaDownloadTaskStatus.failed);
    },
  );

  test('file writes preserve naming and replace legacy metadata', () async {
    final task = _task();
    final comicDir = await files.ensureComicDirectory(root, task);
    final chapterDir = await files.ensureChapterDirectory(comicDir, _target(3));
    expect(chapterDir.path, endsWith('MangaChapter003'));
    final path = await files.writeChapterImage(chapterDir, 12, _image());
    expect(path, endsWith('0012.png'));
    final existingPath = await files.findExistingImagePath(chapterDir, 12);
    expect(existingPath?.replaceAll('\\', '/'), path.replaceAll('\\', '/'));
    final legacy = File('${comicDir.path}/metadata.json');
    await legacy.writeAsString('{}');
    state.restoreTasks([task]);
    await queue.processQueue();
    expect(await legacy.exists(), isFalse);
    final metadata = File('${comicDir.path}/comic.json');
    expect(await metadata.exists(), isTrue);
    await files.deleteMetadataFiles(comicDir);
    expect(await metadata.exists(), isFalse);
  });

  test(
    'task snapshots cannot be mutated and stale updates cannot undo pause or delete',
    () {
      final task = _task();
      state.restoreTasks([task]);
      final snapshot = state.tasks;
      expect(() => snapshot.clear(), throwsUnsupportedError);
      state.pauseTask(task.storageKey);
      expect(snapshot.single.status, MangaDownloadTaskStatus.queued);
      expect(
        state.updateTask(
          task.storageKey,
          task.copyWith(status: MangaDownloadTaskStatus.downloading),
        ),
        isFalse,
      );
      expect(state.tasks.single.status, MangaDownloadTaskStatus.paused);
      state.removeTask(task.storageKey);
      expect(state.updateTask(task.storageKey, task), isFalse);
      expect(state.tasks, isEmpty);
    },
  );
}

void _log(String title, {Object? content, String level = 'info'}) {}

MangaChapterDownloadTarget _target(int number) => MangaChapterDownloadTarget(
  epId: 'ep-$number',
  title: 'Chapter $number',
  index: number - 1,
);

MangaDownloadTask _task({String sourceKey = 'jm'}) => MangaDownloadTask(
  comicId: 'comic',
  sourceKey: sourceKey,
  title: 'Comic',
  subTitle: '',
  description: '',
  coverUrl: 'cover',
  targets: [_target(1)],
  completedEpIds: {},
  status: MangaDownloadTaskStatus.queued,
  createdAtMillis: 1,
  updatedAtMillis: 1,
);

ComicDetailsData _details() => const ComicDetailsData(
  id: 'comic',
  sourceKey: 'jm',
  title: 'Comic',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: {},
  tags: {},
  recommend: [],
  isFavorite: false,
  subId: '',
);

PreparedChapterImageData _image() => PreparedChapterImageData(
  bytes: Uint8List.fromList([1, 2, 3]),
  extension: 'png',
  wasProcessed: true,
);

class _Access extends MangaDownloadAccess {
  _Access(this.root) : super(logScan: _log);
  final Directory root;
  @override
  Future<bool> ensureAndroidDownloadsAccess() async => true;
  @override
  Future<Directory> ensureRootDir() async => root;
}

class _Reader extends Fake implements SourceReaderGateway {
  Future<List<String>> Function(String epId)? load;
  Future<PreparedChapterImageData> Function(String url)? prepare;
  final chapters = <String>[];
  final images = <String>[];
  final scopes = <String>[];
  int coverDownloads = 0;

  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) async {
    chapters.add(epId);
    scopes.add(sourceKey);
    return load == null ? ['$epId-image'] : await load!(epId);
  }

  @override
  Future<PreparedChapterImageData> prepareChapterImageData(
    String url, {
    String comicId = '',
    String epId = '',
    String sourceKey = '',
    bool useDiskCache = true,
    bool priority = false,
  }) async {
    images.add(url);
    scopes.add(sourceKey);
    return prepare == null ? _image() : await prepare!(url);
  }

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    coverDownloads++;
    scopes.add(sourceKey);
    return Uint8List.fromList([4, 5, 6]);
  }
}
