import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_files.dart';
import 'package:hazuki/services/manga_download/manga_download_run.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/manga_download/manga_download_storage_support.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _log(String title, {Object? content, String level = 'info'}) {}

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  while (!predicate() && clock.elapsed < const Duration(seconds: 5)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(predicate(), isTrue);
}

const _details = ComicDetailsData(
  id: 'comic',
  sourceKey: 'one',
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
const _chapter = MangaChapterDownloadTarget(
  epId: 'ep',
  title: 'Chapter',
  index: 0,
);
PreparedChapterImageData _image() => PreparedChapterImageData(
  bytes: Uint8List.fromList([1, 2, 3]),
  extension: 'png',
  wasProcessed: false,
);

class _Reader extends Fake
    implements SourceReaderGateway, SourceDownloadSessionGateway {
  final origins = <SourceTaskOrigin>[];
  final sessions = <SourceDownloadSession>[];
  Future<void> Function(SourceTaskOrigin)? beforeImage;
  Future<void> Function(SourceTaskOrigin)? beforeChapter;
  Future<void> Function(SourceTaskOrigin)? beforeCover;
  int imageCalls = 0;
  @override
  SourceDownloadSession acquireDownloadSession(String sourceKey) {
    final session = SourceDownloadSession(sourceKey, () {});
    sessions.add(session);
    return session;
  }

  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async {
    origins.add(taskOrigin!);
    await beforeChapter?.call(taskOrigin);
    return ['https://fixture/image'];
  }

  @override
  Future<PreparedChapterImageData> prepareChapterImageData(
    String url, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async {
    imageCalls++;
    origins.add(taskOrigin!);
    await beforeImage?.call(taskOrigin);
    return _image();
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
    SourceTaskOrigin? taskOrigin,
  }) async {
    origins.add(taskOrigin!);
    await beforeCover?.call(taskOrigin);
    return Uint8List.fromList([4, 5, 6]);
  }
}

class _Access extends MangaDownloadAccess {
  _Access(this.root) : super(logScan: _log);
  final Directory root;
  Object? rootError;
  @override
  Future<bool> ensureAndroidDownloadsAccess() async => true;
  @override
  Future<Directory> ensureRootDir() async {
    if (rootError case final error?) throw error;
    return root;
  }
}

class _Control extends Fake implements SourceTaskControlGateway {
  final groups = <String>[];
  Future<void> drain = Future.value();
  @override
  Future<SourceTaskCancelReceipt> cancelGroup({
    required String ownerId,
    required String groupId,
    String? pluginId,
    required SourceTaskStopReason reason,
  }) async {
    groups.add(groupId);
    return SourceTaskCancelReceipt(SourceTaskCancelStatus.accepted, drain);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _Reader reader;
  late _Control control;
  late _Access access;
  late MangaDownloadService service;
  Future<void> Function(File)? beforePublish;
  final key = _details.scopedId.storageKey;

  Future<void> enqueue({String cover = ''}) async {
    await service.enqueueDownload(
      details: _details,
      coverUrl: cover,
      description: '',
      chapters: [_chapter],
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hazuki-download-lifetime-');
    SharedPreferences.setMockInitialValues({
      'manga_download_root_path_v1': root.path,
    });
    reader = _Reader();
    control = _Control();
    access = _Access(root);
    beforePublish = null;
    service = MangaDownloadService(
      sourceReader: reader,
      taskControl: control,
      access: access,
      files: MangaDownloadFiles(
        sourceReader: reader,
        logScan: _log,
        beforePublish: (file) async => beforePublish?.call(file),
      ),
    );
  });
  tearDown(() async {
    service.dispose();
    await service.whenDisposed;
    await root.delete(recursive: true);
  });

  test(
    'pause stops the source subscription and awaits its resource drain',
    () async {
      final entered = Completer<void>();
      final drained = Completer<void>();
      control.drain = drained.future;
      reader.beforeImage = (origin) async {
        entered.complete();
        await origin.cancellation!.whenStopped;
        throw SourceTaskCancelled('image', origin.cancellation!.reason!);
      };
      await enqueue();
      await entered.future;
      var done = false;
      final paused = service.pauseTask(key).then((_) => done = true);
      await _until(() => reader.origins.last.cancellation!.reason != null);
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(done, isFalse);
      drained.complete();
      await paused;
      expect(control.groups, contains(reader.origins.last.groupId));
      expect(service.downloadedComics, isEmpty);
      expect(reader.sessions.single.cancellation.reason, isNotNull);
    },
  );

  test(
    'rapid pause and resume uses a fresh group only after old IO settles',
    () async {
      final entered = Completer<void>();
      final write = Completer<void>();
      var blocked = false;
      beforePublish = (file) async {
        if (!blocked && file.path.endsWith('.part')) {
          blocked = true;
          entered.complete();
          await write.future;
        }
      };
      await enqueue();
      await entered.future;
      final old = reader.origins.last;
      final pause = service.pauseTask(key);
      final resume = service.resumeTask(key);
      await _until(() => old.cancellation!.reason != null);
      expect(reader.imageCalls, 1);
      write.complete();
      await Future.wait([pause, resume]);
      await _until(
        () => service.tasks.isEmpty && service.downloadedComics.isNotEmpty,
      );
      expect(reader.imageCalls, 2);
      expect(reader.origins.last.groupId, isNot(old.groupId));
      expect(
        reader.origins.last.downloadSession,
        isNot(same(old.downloadSession)),
      );
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.part'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'delete waits for admitted image IO and leaves no recreated directory',
    () async {
      final entered = Completer<void>();
      final write = Completer<void>();
      beforePublish = (_) async {
        entered.complete();
        await write.future;
      };
      await enqueue();
      await entered.future;
      var deleted = false;
      final deletion = service.deleteTask(key).then((_) => deleted = true);
      await _until(() => reader.origins.last.cancellation!.reason != null);
      expect(deleted, isFalse);
      write.complete();
      await deletion;
      expect(service.tasks, isEmpty);
      expect(await root.list().isEmpty, isTrue);
    },
  );

  test(
    'delete and same-key enqueue cannot let old completion remove the new task',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      reader.beforeImage = (_) async {
        entered.complete();
        await release.future;
      };
      await enqueue();
      await entered.future;
      final deletion = service.deleteTask(key);
      await _until(() => reader.origins.last.cancellation!.reason != null);
      final next = enqueue();
      reader.beforeImage = null;
      release.complete();
      await Future.wait([deletion, next]);
      await _until(
        () => service.tasks.isEmpty && service.downloadedComics.isNotEmpty,
      );
      expect(reader.imageCalls, 2);
      expect(
        await File(
          service.downloadedComics.single.chapters.single.imagePaths.single,
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'catalog cancellation pauses without retrying and preserves complete files',
    () async {
      final entered = Completer<void>();
      reader.beforeImage = (origin) async {
        entered.complete();
        await origin.downloadSession!.cancellation.whenStopped;
        throw SourceTaskCancelled('image', SourceTaskStopReason.pluginUpdated);
      };
      await enqueue(cover: 'https://fixture/cover');
      await entered.future;
      reader.sessions.single.close(SourceTaskStopReason.pluginUpdated);
      await _until(
        () =>
            reader.sessions.single.cancellation.reason != null &&
            control.groups.isNotEmpty,
      );
      await service.pauseTask(key);
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(service.tasks.single.retryCount, 0);
      expect(reader.imageCalls, 1);
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('cover.jpg'))
            .isEmpty,
        isFalse,
      );
    },
  );

  test(
    'a runtime failure while preparing images pauses without retry or replay',
    () async {
      reader.beforeImage = (_) async => throw const SourceRuntimeFailed(
        'runtime',
        SourceRuntimeFailureKind.internalJob,
      );
      await enqueue();
      await _until(
        () => service.tasks.single.status == MangaDownloadTaskStatus.paused,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(service.tasks.single.retryCount, 0);
      expect(reader.imageCalls, 1);
      expect(control.groups, isNotEmpty);
    },
  );

  test('a runtime failure while loading a chapter pauses the task', () async {
    reader.beforeChapter = (_) async => throw const SourceRuntimeFailed(
      'runtime',
      SourceRuntimeFailureKind.workerError,
    );
    await enqueue();
    await _until(
      () => service.tasks.single.status == MangaDownloadTaskStatus.paused,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
    expect(service.tasks.single.retryCount, 0);
    expect(reader.imageCalls, 0);
  });

  test('cover cancellation bypasses optional-cover failure fallback', () async {
    final entered = Completer<void>();
    reader.beforeCover = (origin) async {
      entered.complete();
      await origin.cancellation!.whenStopped;
      throw SourceTaskCancelled('cover', SourceTaskStopReason.downloadPaused);
    };
    await enqueue(cover: 'https://fixture/cover');
    await entered.future;
    await service.pauseTask(key);
    expect(reader.origins, hasLength(1));
    expect(reader.imageCalls, 0);
    expect(service.tasks.single.errorMessage, isNull);
  });

  test('chapter cancellation is silent and does not submit images', () async {
    final entered = Completer<void>();
    reader.beforeChapter = (origin) async {
      entered.complete();
      await origin.cancellation!.whenStopped;
      throw SourceTaskCancelled('chapter', SourceTaskStopReason.downloadPaused);
    };
    await enqueue();
    await entered.future;
    await service.pauseTask(key);
    expect(reader.imageCalls, 0);
    expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
  });

  test(
    'deleting library pauses a pending task and resets completion for resume',
    () async {
      await enqueue();
      await _until(
        () => service.tasks.isEmpty && service.downloadedComics.isNotEmpty,
      );
      final first = service.downloadedComics.single;
      final second = MangaChapterDownloadTarget(
        epId: 'ep2',
        title: 'Next',
        index: 1,
      );
      final entered = Completer<void>();
      reader.beforeImage = (origin) async {
        entered.complete();
        await origin.cancellation!.whenStopped;
        throw SourceTaskCancelled('image', SourceTaskStopReason.downloadPaused);
      };
      await service.enqueueDownload(
        details: _details,
        coverUrl: '',
        description: '',
        chapters: [_chapter, second],
      );
      await entered.future;
      await service.deleteDownloadedComics([key]);
      expect(
        await File(first.chapters.single.imagePaths.single).exists(),
        isFalse,
      );
      expect(service.downloadedComics, isEmpty);
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(service.tasks.single.completedEpIds, isEmpty);
      reader.beforeImage = null;
      await service.resumeTask(key);
      await _until(
        () => service.tasks.isEmpty && service.downloadedComics.isNotEmpty,
      );
      expect(service.downloadedComics.single.chapters, hasLength(1));
      expect(service.downloadedComics.single.chapters.single.epId, 'ep2');
    },
  );

  test(
    'service disposal waits admitted IO and suppresses late notifications',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforePublish = (_) async {
        entered.complete();
        await release.future;
      };
      var notifications = 0;
      service.addListener(() => notifications++);
      await enqueue();
      await entered.future;
      service.dispose();
      final count = notifications;
      var settled = false;
      final drain = service.whenDisposed.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      release.complete();
      await drain;
      expect(notifications, count);
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.part'))
            .isEmpty,
        isTrue,
      );
      await expectLater(enqueue(), throwsStateError);
    },
  );

  test(
    'cancel before atomic publication discards the temporary file',
    () async {
      final run = MangaDownloadRun(
        ownerId: 'owner',
        isCurrent: () => true,
        control: null,
      );
      final files = MangaDownloadFiles(
        sourceReader: null,
        logScan: _log,
        beforePublish: (_) async =>
            run.stop(SourceTaskStopReason.downloadPaused),
      );
      await expectLater(
        run.commit(() => files.writeChapterImage(root, 1, _image(), run: run)),
        throwsA(isA<SourceTaskCancelled>()),
      );
      await run.finish();
      expect(await root.list().isEmpty, isTrue);
    },
  );

  test(
    'temporary and missing-prefix images are not treated as completed pages',
    () async {
      final chapter = Directory('${root.path}/one__comic/MangaChapter001');
      await chapter.create(recursive: true);
      await File(
        '${chapter.path}/.hazuki-interrupted.part',
      ).writeAsString('partial');
      await File('${chapter.path}/0002.png').writeAsString('later page');
      await File('${chapter.path}/0001.png.part').writeAsString('partial page');
      await enqueue();
      await _until(
        () => service.tasks.isEmpty && service.downloadedComics.isNotEmpty,
      );
      expect(reader.imageCalls, 1);
      expect(
        service.downloadedComics.single.chapters.single.imagePaths.single,
        endsWith('0001.png'),
      );
    },
  );

  test(
    'root change waits old writes before saving and leaves downloads paused',
    () async {
      final entered = Completer<void>();
      final write = Completer<void>();
      beforePublish = (_) async {
        entered.complete();
        await write.future;
      };
      await enqueue();
      await entered.future;
      final newRoot = Directory('${root.path}/new-root');
      final changed = service.changeDownloadsRootPath(
        newRoot.path,
        rescan: false,
      );
      await _until(() => reader.origins.last.cancellation!.reason != null);
      expect(
        await MangaDownloadAccess.loadDownloadsRootPath(),
        root.path.replaceAll(r'\', '/'),
      );
      expect(await newRoot.exists(), isFalse);
      write.complete();
      await changed;
      expect(
        await MangaDownloadAccess.loadDownloadsRootPath(),
        newRoot.path.replaceAll(r'\', '/'),
      );
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(service.tasks.single.completedEpIds, isEmpty);
      expect(await File('${newRoot.path}/.nomedia').exists(), isTrue);
      expect(reader.imageCalls, 1);
    },
  );

  test('root preparation failure keeps old path and paused task', () async {
    final entered = Completer<void>();
    reader.beforeImage = (origin) async {
      entered.complete();
      await origin.cancellation!.whenStopped;
      throw SourceTaskCancelled('image', SourceTaskStopReason.downloadPaused);
    };
    await enqueue();
    await entered.future;
    final invalid = File('${root.path}/file');
    await invalid.writeAsString('not a directory');
    await expectLater(
      service.changeDownloadsRootPath(invalid.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      await MangaDownloadAccess.loadDownloadsRootPath(),
      root.path.replaceAll(r'\', '/'),
    );
    expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
  });

  test(
    'pause during metadata publication drains and preserves previous metadata',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforePublish = (temporary) async {
        final bytes = await temporary.readAsBytes();
        if (bytes.isNotEmpty && bytes.first == 123) {
          entered.complete();
          await release.future;
        }
      };
      await enqueue();
      await entered.future;
      var done = false;
      final pause = service.pauseTask(key).then((_) => done = true);
      await _until(() => reader.origins.last.cancellation!.reason != null);
      expect(done, isFalse);
      release.complete();
      await pause;
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.part'))
            .isEmpty,
        isTrue,
      );
      final images = root
          .list(recursive: true)
          .where((e) => e.path.endsWith('.png'));
      expect(await images.isEmpty, isFalse);
    },
  );

  test(
    'failed task deletion restores a paused task and reports the failure',
    () async {
      final entered = Completer<void>();
      reader.beforeImage = (origin) async {
        entered.complete();
        await origin.cancellation!.whenStopped;
        throw SourceTaskCancelled('image', SourceTaskStopReason.user);
      };
      await enqueue();
      await entered.future;
      access.rootError = const FileSystemException('root unavailable');
      await expectLater(
        service.deleteTask(key),
        throwsA(isA<FileSystemException>()),
      );
      expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
      final prefs = await SharedPreferences.getInstance();
      final state =
          jsonDecode(prefs.getString('manga_download_service_state_v2')!)
              as Map;
      expect((state['tasks'] as List).single['status'], 'paused');
    },
  );

  test('pause after a pending resume wins when the old write drains', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    beforePublish = (_) async {
      entered.complete();
      await release.future;
    };
    await enqueue();
    await entered.future;
    final firstPause = service.pauseTask(key);
    final resume = service.resumeTask(key);
    final finalPause = service.pauseTask(key);
    await _until(() => reader.origins.last.cancellation!.reason != null);
    release.complete();
    await Future.wait([firstPause, resume, finalPause]);
    expect(service.tasks.single.status, MangaDownloadTaskStatus.paused);
    expect(reader.imageCalls, 1);
  });

  test(
    'plugin interaction cancellation leaves a paused task rather than a running task',
    () async {
      reader.beforeChapter = (_) async =>
          throw const SourceTaskCancelled('chapter', SourceTaskStopReason.user);
      await enqueue();
      await _until(
        () => service.tasks.single.status == MangaDownloadTaskStatus.paused,
      );
      await service.pauseTask(key);
      expect(service.tasks.single.errorMessage, isNull);
      expect(reader.imageCalls, 0);
    },
  );

  test('serialized state persistence ends with paused state', () async {
    final entered = Completer<void>();
    reader.beforeImage = (origin) async {
      entered.complete();
      await origin.cancellation!.whenStopped;
      throw SourceTaskCancelled('image', SourceTaskStopReason.downloadPaused);
    };
    await enqueue();
    await entered.future;
    await service.pauseTask(key);
    final prefs = await SharedPreferences.getInstance();
    final state =
        jsonDecode(prefs.getString('manga_download_service_state_v2')!) as Map;
    expect((state['tasks'] as List).single['status'], 'paused');
  });
}
