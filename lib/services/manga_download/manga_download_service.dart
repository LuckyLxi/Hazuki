import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path_util;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hazuki_models.dart';
import '../source/source_capabilities.dart';
import 'manga_download_commands.dart';
import 'manga_download_library.dart';
import 'manga_download_lifecycle_coordinator.dart';
import 'manga_download_state.dart';
import 'manga_download_files.dart';
import 'manga_download_queue_support.dart';
import 'manga_download_recovery_support.dart';
import 'manga_download_storage_support.dart';

export 'manga_download_models.dart';

class MangaDownloadService extends ChangeNotifier
    implements MangaDownloadCommands, MangaDownloadLibrary {
  MangaDownloadService({
    SourceReaderGateway? sourceReader,
    SourceTaskControlGateway? taskControl,
    MangaDownloadFiles? files,
    MangaDownloadAccess? access,
  }) {
    _stateStore = MangaDownloadStateStore(logScan: _logScan);
    _access = access ?? MangaDownloadAccess(logScan: _logScan);
    _files =
        files ??
        MangaDownloadFiles(sourceReader: sourceReader, logScan: _logScan);
    _recoveryScanner = MangaDownloadRecoveryScanner(
      logScan: _logScan,
      taskByComicId: _state.taskByComicId,
      chapterDirForTarget: _files.chapterDirForTarget,
      writeMetadataFile: _files.writeMetadataFile,
    );
    _lifecycle = MangaDownloadLifecycleCoordinator(
      isAndroid: Platform.isAndroid,
      hasActiveDownloads: _hasActiveDownloads,
      startForegroundService: _access.startDownloadForegroundService,
      stopForegroundService: _access.stopDownloadForegroundService,
      processQueue: () => _queueExecutor.processQueue(),
    );
    _queueExecutor = MangaDownloadQueueExecutor(
      logDownload: _logScan,
      state: _state,
      files: _files,
      access: _access,
      flushState: _flushState,
      shouldSuspendDownloads: () => _lifecycle.shouldSuspendDownloads,
      shouldRecoverTransientNetworkError: () =>
          _lifecycle.shouldRecoverTransientNetworkError,
      sourceReader: sourceReader,
      taskControl: taskControl,
    );
  }

  bool _disposed = false;
  Future<void> _persistTail = Future.value();
  Future<void>? _disposeDrain;
  Future<void> get whenDisposed => _disposeDrain ?? Future.value();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  final MangaDownloadState _state = MangaDownloadState();
  late final MangaDownloadFiles _files;
  List<MangaDownloadTask> get _tasks => _state.tasks;
  List<DownloadedMangaComic> get _downloaded => _state.downloadedComics;
  late final MangaDownloadStateStore _stateStore;
  late final MangaDownloadAccess _access;
  late final MangaDownloadRecoveryScanner _recoveryScanner;
  late final MangaDownloadQueueExecutor _queueExecutor;
  late final MangaDownloadLifecycleCoordinator _lifecycle;

  @override
  List<MangaDownloadTask> get tasks => _state.tasks;
  @override
  List<DownloadedMangaComic> get downloadedComics => _state.downloadedComics;

  // 下载扫描日志已禁用，不再写入应用日志
  // ignore: unused_element
  void _logScan(String title, {Object? content, String level = 'info'}) {}

  void handleAppLifecycleState(AppLifecycleState state) {
    _lifecycle.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lifecycle.dispose();
    _disposeDrain = Future.wait([
      _queueExecutor.dispose(),
      _persistTail,
      ?_initFuture,
    ]).then((_) {});
    _disposeDrain!.ignore();
    super.dispose();
  }

  bool _hasActiveDownloads() => _tasks.any(
    (t) =>
        t.status == MangaDownloadTaskStatus.queued ||
        t.status == MangaDownloadTaskStatus.downloading,
  );

  @override
  Future<Set<String>> checkDownloadedIntegrity() async {
    final issueIds = <String>{};
    for (final comic in _downloaded) {
      bool hasIssue = false;
      outer:
      for (final chapter in comic.chapters) {
        for (final imagePath in chapter.imagePaths) {
          if (!await File(imagePath).exists()) {
            hasIssue = true;
            break outer;
          }
        }
      }
      if (hasIssue) {
        issueIds.add(comic.storageKey);
      }
    }
    return issueIds;
  }

  @override
  Future<void> ensureInitialized() async {
    if (_disposed) throw StateError('download_service_disposed');
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _init();
    _initFuture = future;
    await future;
  }

  @override
  Future<MangaDownloadedScanResult> scanDownloadedComics() async {
    await ensureInitialized();
    final hasAccess = await _ensureAndroidDownloadsAccess();
    if (!hasAccess) {
      return const MangaDownloadedScanResult(
        permissionGranted: false,
        scannedDirectories: 0,
        recoveredComics: 0,
      );
    }

    final rootDir = await _ensureRootDir();
    final result = await _recoveryScanner.scanDownloadedFromDisk(rootDir);
    _state.replaceDownloaded(result.comics);
    await _persistState();
    notifyListeners();
    return MangaDownloadedScanResult(
      permissionGranted: true,
      scannedDirectories: result.scannedDirectories,
      recoveredComics: result.recoveredComics,
    );
  }

  DownloadedMangaComic? downloadedComicById(String comicId) {
    return downloadedComicByIdForSource(comicId, sourceKey: '');
  }

  DownloadedMangaComic? downloadedComicByIdForSource(
    String comicId, {
    required String sourceKey,
  }) => _state.downloadedComicByIdForSource(comicId, sourceKey: sourceKey);

  MangaDownloadTask? taskByComicId(String comicId) =>
      _state.taskByComicId(comicId);

  @override
  Future<MangaDownloadConflict> checkDownloadTaskConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    await ensureInitialized();
    final task = _state.taskByStorageKey(details.scopedId.storageKey);
    return MangaDownloadConflict(
      comicTitle: details.title,
      existingChapters: task == null
          ? const <MangaChapterDownloadTarget>[]
          : chapters
                .where(
                  (target) =>
                      task.targets.any((item) => item.epId == target.epId),
                )
                .toList(growable: false),
    );
  }

  @override
  Future<MangaDownloadConflict> checkDownloadConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    await ensureInitialized();
    final downloaded = downloadedComicByIdForSource(
      details.id,
      sourceKey: details.sourceKey.trim(),
    );
    return MangaDownloadConflict(
      comicTitle: details.title,
      existingChapters: downloaded == null
          ? const <MangaChapterDownloadTarget>[]
          : chapters
                .where(
                  (target) => downloaded.chapters.any(
                    (chapter) => MangaDownloadState.chapterMatchesTarget(
                      chapter,
                      target,
                    ),
                  ),
                )
                .toList(growable: false),
    );
  }

  @override
  Future<MangaDownloadEnqueueResult> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
    bool redownloadExisting = false,
  }) async {
    if (chapters.isEmpty) {
      return MangaDownloadEnqueueResult.nothingToQueue;
    }

    await ensureInitialized();
    final priorTask = _state.taskByStorageKey(details.scopedId.storageKey);
    final resumeAfterRedownload =
        redownloadExisting &&
        priorTask != null &&
        priorTask.status != MangaDownloadTaskStatus.paused;
    if (redownloadExisting) {
      await _removeDownloadedChaptersForRedownload(
        details: details,
        chapters: chapters,
      );
    }
    return _queueExecutor.withTaskBarrier(
      details.scopedId.storageKey,
      () async {
        final result = _state.enqueue(
          details: details,
          coverUrl: coverUrl,
          description: description,
          chapters: chapters,
        );
        if (result == MangaDownloadEnqueueResult.queued) {
          if (resumeAfterRedownload) {
            _state.resumeTask(details.scopedId.storageKey);
          }
          await _persistState();
          notifyListeners();
        }
        return result;
      },
      stop: false,
    );
  }

  Future<void> _removeDownloadedChaptersForRedownload({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    final downloaded = downloadedComicByIdForSource(
      details.id,
      sourceKey: details.sourceKey.trim(),
    );
    if (downloaded == null) {
      return;
    }

    final chaptersToRemove = downloaded.chapters
        .where(
          (chapter) => chapters.any(
            (target) =>
                MangaDownloadState.chapterMatchesTarget(chapter, target),
          ),
        )
        .toList(growable: false);
    if (chaptersToRemove.isEmpty) {
      return;
    }

    _state.pauseTask(details.scopedId.storageKey);
    return _queueExecutor.withTaskBarrier(
      details.scopedId.storageKey,
      () async {
        final downloaded = downloadedComicByIdForSource(
          details.id,
          sourceKey: details.sourceKey.trim(),
        );
        if (downloaded == null) return;
        final chaptersToRemove = downloaded.chapters
            .where(
              (chapter) => chapters.any(
                (target) =>
                    MangaDownloadState.chapterMatchesTarget(chapter, target),
              ),
            )
            .toList();
        if (chaptersToRemove.isEmpty) return;
        await _publishState();
        if (!await _ensureAndroidDownloadsAccess()) {
          throw FileSystemException('Android downloads access not granted');
        }
        final rootDir = await _ensureRootDir();
        final comicDir = Directory(
          '${rootDir.path}/${downloaded.downloadDirName}',
        );
        final chapterDirectories = <String>{};
        for (final chapter in chaptersToRemove) {
          final directory = await _recoveryScanner.resolveChapterDirForEpId(
            comicDir: comicDir,
            epId: chapter.epId,
            targets: chapters,
            downloadedComic: downloaded,
          );
          if (directory != null && _isPathWithin(directory, comicDir)) {
            chapterDirectories.add(directory.path);
          }
        }
        for (final path in chapterDirectories) {
          final directory = Directory(path);
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        }

        final remainingChapters = downloaded.chapters
            .where(
              (chapter) => !chapters.any(
                (target) =>
                    MangaDownloadState.chapterMatchesTarget(chapter, target),
              ),
            )
            .toList(growable: false);
        if (remainingChapters.isEmpty) {
          _state.removeDownloaded({downloaded.storageKey});
          await _files.deleteMetadataFiles(comicDir);
        } else {
          final updated = downloaded.copyWith(chapters: remainingChapters);
          _state.upsertDownloadedComic(updated);
          await _files.writeMetadataFile(comicDir, updated);
        }
        await _persistState();
        notifyListeners();
      },
      reason: SourceTaskStopReason.superseded,
    );
  }

  bool _isPathWithin(Directory child, Directory parent) {
    String normalize(String path) {
      final absolute = path_util
          .normalize(path_util.absolute(path))
          .replaceAll('\\', '/');
      final trimmed = absolute.endsWith('/')
          ? absolute.substring(0, absolute.length - 1)
          : absolute;
      return Platform.isWindows ? trimmed.toLowerCase() : trimmed;
    }

    final childPath = normalize(child.path);
    final parentPath = normalize(parent.path);
    return childPath.startsWith('$parentPath/');
  }

  Set<Directory> _downloadedComicDirectoriesWithinRoot(
    DownloadedMangaComic comic,
    Directory rootDir,
  ) {
    final paths = <String>[
      if (comic.localCoverPath != null) comic.localCoverPath!,
      for (final chapter in comic.chapters) ...chapter.imagePaths,
    ];
    final directories = <Directory>{};
    for (final path in paths) {
      final directory = _topLevelDirectoryWithinRoot(path, rootDir);
      if (directory != null) {
        directories.add(directory);
      }
    }
    return directories;
  }

  Directory? _topLevelDirectoryWithinRoot(String path, Directory rootDir) {
    String normalize(String value) {
      final absolute = path_util
          .normalize(path_util.absolute(value))
          .replaceAll('\\', '/');
      final trimmed = absolute.endsWith('/')
          ? absolute.substring(0, absolute.length - 1)
          : absolute;
      return Platform.isWindows ? trimmed.toLowerCase() : trimmed;
    }

    final rootPath = normalize(rootDir.path);
    final filePath = normalize(path);
    if (!filePath.startsWith('$rootPath/')) {
      return null;
    }
    final relativeParts = filePath
        .substring(rootPath.length + 1)
        .split('/')
        .where((part) => part.isNotEmpty);
    if (relativeParts.isEmpty) {
      return null;
    }
    return Directory('${rootDir.path}/${relativeParts.first}');
  }

  @override
  Future<void> deleteDownloadedComics(Iterable<String> comicIds) async {
    await ensureInitialized();
    final ids = comicIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (ids.isEmpty || !await _ensureAndroidDownloadsAccess()) return;
    await Future.wait(
      ids.map((key) async {
        final scoped = SourceScopedComicId.fromStorageKey(key);
        final affected = {
          key,
          if (scoped.sourceKey.isEmpty || isHazukiJmSourceKey(scoped.sourceKey))
            for (final task in _tasks)
              if (task.comicId == scoped.comicId &&
                  (task.sourceKey.isEmpty ||
                      isHazukiJmSourceKey(task.sourceKey)))
                task.storageKey,
        };
        for (final storageKey in affected) {
          _state.pauseTask(storageKey);
        }
        await _queueExecutor.withTaskBarriers(affected, () async {
          for (final storageKey in affected) {
            _state.pauseTask(storageKey);
          }
          await _publishState();
          final rootDir = await _ensureRootDir();
          final comic = _state.downloadedComicByStorageKey(key);
          final scopedId = SourceScopedComicId.fromStorageKey(key);
          final removesLegacy =
              scopedId.sourceKey.isEmpty ||
              isHazukiJmSourceKey(scopedId.sourceKey);
          final names = <String>{
            comic?.downloadDirName ?? scopedId.downloadDirName,
            scopedId.downloadDirName,
            if (removesLegacy && comic != null) comic.comicId,
            if (removesLegacy) scopedId.comicId,
          };
          final directories = <Directory>{
            for (final name in names) Directory('${rootDir.path}/$name'),
            if (comic != null)
              ..._downloadedComicDirectoriesWithinRoot(comic, rootDir),
          };
          for (final dir in directories) {
            if (!_isPathWithin(dir, rootDir)) {
              throw FileSystemException('download_path_outside_root', dir.path);
            }
            if (await dir.exists()) await dir.delete(recursive: true);
          }
          _state.removeDownloaded({key, if (comic != null) comic.storageKey});
          for (final storageKey in affected) {
            _state.resetTaskProgress(storageKey);
          }
          await _persistState();
          notifyListeners();
        }, reason: SourceTaskStopReason.downloadPaused);
      }),
    );
  }

  Future<void> _publishState() async {
    await _persistState();
    notifyListeners();
  }

  @override
  Future<void> pauseTask(String storageKey) async {
    await ensureInitialized();
    if (!_state.pauseTask(storageKey)) return;
    final drain = _queueExecutor.withTaskBarrier(storageKey, () async {
      if (_state.pauseTask(storageKey)) await _publishState();
    }, reason: SourceTaskStopReason.downloadPaused);
    final published = _publishState();
    await Future.wait([published, drain]);
  }

  @override
  Future<void> resumeTask(String storageKey) async {
    await ensureInitialized();
    await _queueExecutor.withTaskBarrier(storageKey, () async {
      if (_state.resumeTask(storageKey)) await _publishState();
    }, stop: false);
  }

  @override
  Future<void> pauseAllTasks() async {
    await ensureInitialized();
    await Future.wait(_tasks.map((task) => pauseTask(task.storageKey)));
  }

  @override
  Future<void> resumeAllTasks() async {
    await ensureInitialized();
    await Future.wait(
      _tasks
          .where(
            (task) =>
                task.status == MangaDownloadTaskStatus.paused ||
                task.status == MangaDownloadTaskStatus.failed,
          )
          .map((task) => resumeTask(task.storageKey)),
    );
  }

  @override
  Future<void> deleteTask(String storageKey) async {
    await ensureInitialized();
    if (!await _ensureAndroidDownloadsAccess()) return;
    final task = _state.removeTask(storageKey);
    if (task == null) return;
    await _queueExecutor.withTaskBarrier(task.storageKey, () async {
      try {
        final rootDir = await _ensureRootDir();
        final comicDir = Directory('${rootDir.path}/${task.downloadDirName}');
        if (!_isPathWithin(comicDir, rootDir)) {
          throw FileSystemException(
            'download_path_outside_root',
            comicDir.path,
          );
        }
        final downloadedComic = _state.downloadedComicByStorageKey(
          task.storageKey,
        );
        if (task.currentChapterEpId?.isNotEmpty == true &&
            downloadedComic?.chapters.any(
                  (chapter) => chapter.epId == task.currentChapterEpId,
                ) !=
                true) {
          final chapterDir = await _recoveryScanner.resolveChapterDirForEpId(
            comicDir: comicDir,
            epId: task.currentChapterEpId!,
            targets: task.targets,
            downloadedComic: downloadedComic,
          );
          if (chapterDir != null) {
            if (!_isPathWithin(chapterDir, comicDir)) {
              throw FileSystemException(
                'download_path_outside_root',
                chapterDir.path,
              );
            }
            if (await chapterDir.exists()) {
              await chapterDir.delete(recursive: true);
            }
          }
        }
        if (downloadedComic == null && await comicDir.exists()) {
          await comicDir.delete(recursive: true);
        }
        await _publishState();
      } catch (_) {
        // The captured instance stays retryable; a future enqueue is admitted
        // only after this barrier releases.
        if (_state.taskByStorageKey(task.storageKey) == null) {
          _state.restoreTasks([
            ..._tasks,
            task.copyWith(status: MangaDownloadTaskStatus.paused),
          ]);
        }
        await _publishState();
        rethrow;
      }
    }, reason: SourceTaskStopReason.user);
  }

  Future<void> changeDownloadsRootPath(
    String path, {
    bool rescan = true,
  }) async {
    await ensureInitialized();
    _state.pauseAllTasks();
    await _queueExecutor.withAllBarrier(() async {
      _state.pauseAllTasks();
      await _publishState();
      final normalized = MangaDownloadAccess.normalizeDownloadsRootPath(path);
      final previous = await MangaDownloadAccess.loadDownloadsRootPath();
      final directory = Directory(normalized);
      await directory.create(recursive: true);
      await File('${directory.path}/.nomedia').writeAsString('', flush: true);
      try {
        await MangaDownloadAccess.saveDownloadsRootPath(normalized);
        await _reloadRoot(rescan: rescan);
      } catch (_) {
        await MangaDownloadAccess.saveDownloadsRootPath(previous);
        rethrow;
      }
    });
  }

  Future<void> handleRootPathChanged({bool rescan = true}) async {
    await ensureInitialized();
    _state.pauseAllTasks();
    await _queueExecutor.withAllBarrier(() async {
      _state.pauseAllTasks();
      await _publishState();
      await _reloadRoot(rescan: rescan);
    });
  }

  Future<void> _reloadRoot({required bool rescan}) async {
    var comics = const <DownloadedMangaComic>[];
    if (rescan) {
      final hasAccess = await _ensureAndroidDownloadsAccess();
      if (!hasAccess) {
        throw FileSystemException('Android downloads access not granted');
      }
      final rootDir = await _ensureRootDir();
      final result = await _recoveryScanner.scanDownloadedFromDisk(rootDir);
      comics = result.comics;
    }
    for (final task in _tasks) {
      _state.resetTaskProgress(task.storageKey);
    }
    _state.replaceDownloaded(comics);
    await _publishState();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final restored = await _stateStore.restore(_prefs);
    if (_disposed) return;
    _state.restoreTasks(restored.tasks);
    _sanitizeRestoredDownloadedState(restored.downloaded);
    await _persistState();
  }

  Future<bool> _ensureAndroidDownloadsAccess() {
    return _access.ensureAndroidDownloadsAccess();
  }

  Future<Directory> _ensureRootDir() {
    return _access.ensureRootDir();
  }

  Future<void> _persistState() {
    final tasks = _tasks;
    final downloaded = _downloaded;
    final result = _persistTail.then(
      (_) => _stateStore.persist(
        prefs: _prefs,
        tasks: tasks,
        downloaded: downloaded,
      ),
    );
    _persistTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _flushState() async {
    await _persistState();
    if (_tasks.isEmpty) {
      unawaited(_access.stopDownloadForegroundService());
    }
    notifyListeners();
  }

  void _sanitizeRestoredDownloadedState(Iterable<DownloadedMangaComic> comics) {
    final sanitized = <DownloadedMangaComic>[];
    final droppedIds = <String>[];
    for (final comic in comics) {
      final normalized = _recoveryScanner.sanitizeDownloadedComicState(comic);
      if (normalized != null) {
        sanitized.add(normalized);
      } else {
        droppedIds.add(comic.comicId);
      }
    }
    if (droppedIds.isNotEmpty) {
      _logScan(
        'Dropped invalid downloaded comic entries on restore',
        level: 'warning',
        content: {'droppedIds': droppedIds},
      );
    }
    _state.replaceDownloaded(sanitized);
  }
}
