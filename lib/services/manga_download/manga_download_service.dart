import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hazuki_models.dart';
import '../source/source_capabilities.dart';
import 'manga_download_commands.dart';
import 'manga_download_lifecycle_coordinator.dart';
import 'manga_download_state.dart';
import 'manga_download_files.dart';
import 'manga_download_queue_support.dart';
import 'manga_download_recovery_support.dart';
import 'manga_download_storage_support.dart';

export 'manga_download_models.dart';

class MangaDownloadService extends ChangeNotifier
    implements MangaDownloadCommands {
  MangaDownloadService({SourceReaderGateway? sourceReader}) {
    _stateStore = MangaDownloadStateStore(logScan: _logScan);
    _access = MangaDownloadAccess(logScan: _logScan);
    _files = MangaDownloadFiles(sourceReader: sourceReader, logScan: _logScan);
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
    );
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

  List<MangaDownloadTask> get tasks => _state.tasks;
  List<DownloadedMangaComic> get downloadedComics => _state.downloadedComics;

  // 下载扫描日志已禁用，不再写入应用日志
  // ignore: unused_element
  void _logScan(String title, {Object? content, String level = 'info'}) {}

  void handleAppLifecycleState(AppLifecycleState state) {
    _lifecycle.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool _hasActiveDownloads() => _tasks.any(
    (t) =>
        t.status == MangaDownloadTaskStatus.queued ||
        t.status == MangaDownloadTaskStatus.downloading,
  );

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

  Future<void> ensureInitialized() async {
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _init();
    _initFuture = future;
    await future;
  }

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
    if (redownloadExisting) {
      await _removeDownloadedChaptersForRedownload(
        details: details,
        chapters: chapters,
      );
    }
    final result = _state.enqueue(
      details: details,
      coverUrl: coverUrl,
      description: description,
      chapters: chapters,
    );
    if (result != MangaDownloadEnqueueResult.queued) return result;

    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
    return MangaDownloadEnqueueResult.queued;
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

    if (!await _ensureAndroidDownloadsAccess()) {
      throw FileSystemException('Android downloads access not granted');
    }
    final rootDir = await _ensureRootDir();
    final comicDir = Directory('${rootDir.path}/${downloaded.downloadDirName}');
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
  }

  bool _isPathWithin(Directory child, Directory parent) {
    String normalize(String path) {
      final absolute = Directory(path).absolute.path.replaceAll('\\', '/');
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
      final absolute = File(value).absolute.path.replaceAll('\\', '/');
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

  Future<void> deleteDownloadedComics(Iterable<String> comicIds) async {
    await ensureInitialized();
    final ids = comicIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (ids.isEmpty) {
      return;
    }

    final hasAccess = await _ensureAndroidDownloadsAccess();
    if (!hasAccess) {
      return;
    }

    final rootDir = await _ensureRootDir();
    for (final storageKey in ids) {
      try {
        final comic = _state.downloadedComicByStorageKey(storageKey);
        final scopedId = SourceScopedComicId.fromStorageKey(storageKey);
        final removesLegacyDirectory =
            scopedId.sourceKey.isEmpty ||
            isHazukiJmSourceKey(scopedId.sourceKey);
        final dirNames = <String>{
          comic?.downloadDirName ?? scopedId.downloadDirName,
          scopedId.downloadDirName,
          // Downloads created before source-scoped IDs used the raw comic ID
          // as their directory name. Keep deleting that legacy directory so a
          // migrated download does not remain on disk after deletion.
          if (removesLegacyDirectory && comic != null) comic.comicId,
          if (removesLegacyDirectory) scopedId.comicId,
        };
        final directories = <Directory>{
          for (final dirName in dirNames) Directory('${rootDir.path}/$dirName'),
          if (comic != null)
            ..._downloadedComicDirectoriesWithinRoot(comic, rootDir),
        };
        for (final dir in directories) {
          if (_isPathWithin(dir, rootDir) && await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
      } catch (_) {}
    }
    _state.removeDownloaded(ids);
    await _persistState();
    notifyListeners();
  }

  Future<void> pauseTask(String storageKey) async {
    await ensureInitialized();
    if (!_state.pauseTask(storageKey)) return;
    await _persistState();
    notifyListeners();
  }

  Future<void> resumeTask(String storageKey) async {
    await ensureInitialized();
    if (!_state.resumeTask(storageKey)) return;
    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
  }

  Future<void> pauseAllTasks() async {
    await ensureInitialized();
    if (!_state.pauseAllTasks()) return;
    await _persistState();
    notifyListeners();
  }

  Future<void> resumeAllTasks() async {
    await ensureInitialized();
    if (!_state.resumeAllTasks()) return;
    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
  }

  Future<void> deleteTask(String storageKey) async {
    await ensureInitialized();
    if (_state.taskByStorageKey(storageKey) == null) {
      return;
    }

    final hasAccess = await _ensureAndroidDownloadsAccess();
    if (!hasAccess) {
      return;
    }

    final task = _state.removeTask(storageKey);
    if (task == null) return;
    final rootDir = await _ensureRootDir();
    final comicDir = Directory('${rootDir.path}/${task.downloadDirName}');
    final downloadedComic = _state.downloadedComicByStorageKey(task.storageKey);
    if (task.currentChapterEpId?.isNotEmpty == true) {
      try {
        final chapterDir = await _recoveryScanner.resolveChapterDirForEpId(
          comicDir: comicDir,
          epId: task.currentChapterEpId!,
          targets: task.targets,
          downloadedComic: downloadedComic,
        );
        if (chapterDir != null && await chapterDir.exists()) {
          await chapterDir.delete(recursive: true);
        }
      } catch (_) {}
    }
    if (downloadedComic == null) {
      try {
        if (await comicDir.exists()) {
          await comicDir.delete(recursive: true);
        }
      } catch (_) {}
    }
    await _persistState();
    notifyListeners();
  }

  Future<void> handleRootPathChanged({bool rescan = true}) async {
    await ensureInitialized();
    _state.replaceDownloaded(const []);

    if (rescan) {
      final hasAccess = await _ensureAndroidDownloadsAccess();
      if (hasAccess) {
        final rootDir = await _ensureRootDir();
        final result = await _recoveryScanner.scanDownloadedFromDisk(rootDir);
        _state.replaceDownloaded(result.comics);
      }
    }

    await _persistState();
    notifyListeners();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final restored = await _stateStore.restore(_prefs);
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
    return _stateStore.persist(
      prefs: _prefs,
      tasks: _tasks,
      downloaded: _downloaded,
    );
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
