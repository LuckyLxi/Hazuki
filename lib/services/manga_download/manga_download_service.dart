import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/service_locator.dart';
import '../../models/hazuki_models.dart';
import '../hazuki_source_service.dart';
import 'manga_download_models.dart';
import 'manga_download_queue_support.dart';
import 'manga_download_recovery_support.dart';
import 'manga_download_storage_support.dart';

export 'manga_download_models.dart';

class MangaDownloadService extends ChangeNotifier {
  MangaDownloadService() {
    _stateStore = MangaDownloadStateStore(logScan: _logScan);
    _access = MangaDownloadAccess(logScan: _logScan);
    _recoveryScanner = MangaDownloadRecoveryScanner(
      logScan: _logScan,
      taskByComicId: taskByComicId,
      chapterDirForTarget: _chapterDirForTarget,
      writeMetadataFile: _writeMetadataFile,
    );
    _queueExecutor = MangaDownloadQueueExecutor(
      logDownload: _logScan,
      tasks: _tasks,
      replaceTask: _replaceTask,
      removeTaskByComicId: _removeTaskByComicId,
      latestTask: _latestTask,
      shouldAbortTask: _shouldAbortTask,
      downloadedComicById: _downloadedComicByStorageKey,
      upsertDownloadedComic: _upsertDownloadedComic,
      flushState: _flushState,
      ensureAndroidDownloadsAccess: _ensureAndroidDownloadsAccess,
      ensureRootDir: _ensureRootDir,
      loadDownloadsRootPath: _loadDownloadsRootPath,
      findExistingImagePath: _findExistingImagePath,
      downloadCoverIfNeeded: _downloadCoverIfNeeded,
      writeMetadataFile: _writeMetadataFile,
      chapterDirForTarget: _chapterDirForTarget,
      shouldSuspendDownloads: _shouldSuspendDownloads,
      shouldRecoverTransientNetworkError: _shouldRecoverTransientDownloadError,
    );
  }

  static const String _metadataFileName = 'comic.json';
  static const String _legacyMetadataFileName = 'metadata.json';

  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  final List<MangaDownloadTask> _tasks = <MangaDownloadTask>[];
  final List<DownloadedMangaComic> _downloaded = <DownloadedMangaComic>[];
  late final MangaDownloadStateStore _stateStore;
  late final MangaDownloadAccess _access;
  late final MangaDownloadRecoveryScanner _recoveryScanner;
  late final MangaDownloadQueueExecutor _queueExecutor;
  bool _downloadsSuspended = false;
  DateTime? _downloadResumeGraceDeadline;
  Timer? _downloadResumeTimer;

  List<MangaDownloadTask> get tasks =>
      List<MangaDownloadTask>.unmodifiable(_tasks);
  List<DownloadedMangaComic> get downloadedComics =>
      List<DownloadedMangaComic>.unmodifiable(_downloaded);

  // 下载扫描日志已禁用，不再写入应用日志
  // ignore: unused_element
  void _logScan(String title, {Object? content, String level = 'info'}) {}

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _downloadsSuspended = false;
      _downloadResumeTimer?.cancel();
      _downloadResumeTimer = null;
      unawaited(_access.stopDownloadForegroundService());
      _downloadResumeGraceDeadline = DateTime.now().add(
        const Duration(seconds: 4),
      );
      _downloadResumeTimer = Timer(const Duration(milliseconds: 1200), () {
        if (_downloadsSuspended) return;
        unawaited(_queueExecutor.processQueue());
      });
      return;
    }

    if (Platform.isAndroid) {
      // Android: only suspend when the engine is fully detached (process dying).
      // inactive/paused/hidden are all transient background states — keep downloads
      // running and hold the process alive with a foreground service.
      if (state == AppLifecycleState.paused && _hasActiveDownloads()) {
        unawaited(_access.startDownloadForegroundService());
      }
      if (state != AppLifecycleState.detached) return;
    }

    if (_downloadsSuspended) return;
    _downloadsSuspended = true;
    _downloadResumeTimer?.cancel();
    _downloadResumeTimer = null;
    _downloadResumeGraceDeadline = null;
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
    _downloaded
      ..clear()
      ..addAll(_mergeLegacyJmAliases(result.comics))
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
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
  }) {
    final storageKey = SourceScopedComicId(
      sourceKey: sourceKey,
      comicId: comicId,
    ).storageKey;
    for (final item in _downloaded) {
      if (item.storageKey == storageKey ||
          (sourceKey.isEmpty && item.comicId == comicId)) {
        return item;
      }
    }
    if (isHazukiJmSourceKey(sourceKey)) {
      for (final item in _downloaded) {
        if (item.sourceKey.isEmpty && item.comicId == comicId) {
          return item;
        }
      }
    }
    return null;
  }

  DownloadedMangaComic? _downloadedComicByStorageKey(String storageKey) {
    for (final item in _downloaded) {
      if (item.storageKey == storageKey ||
          (item.sourceKey.isEmpty && item.comicId == storageKey)) {
        return item;
      }
    }
    final scopedId = SourceScopedComicId.fromStorageKey(storageKey);
    if (isHazukiJmSourceKey(scopedId.sourceKey)) {
      for (final item in _downloaded) {
        if (item.sourceKey.isEmpty && item.comicId == scopedId.comicId) {
          return item;
        }
      }
    }
    return null;
  }

  MangaDownloadTask? taskByComicId(String comicId) {
    for (final item in _tasks) {
      if (item.comicId == comicId ||
          item.storageKey == comicId ||
          item.downloadDirName == comicId) {
        return item;
      }
    }
    return null;
  }

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
                    (chapter) =>
                        _downloadedChapterMatchesTarget(chapter, target),
                  ),
                )
                .toList(growable: false),
    );
  }

  Future<void> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
    bool redownloadExisting = false,
  }) async {
    if (chapters.isEmpty) {
      return;
    }

    await ensureInitialized();
    final sourceKey = details.sourceKey.trim();
    if (redownloadExisting) {
      await _removeDownloadedChaptersForRedownload(
        details: details,
        chapters: chapters,
      );
    }
    final existingDownloaded = downloadedComicByIdForSource(
      details.id,
      sourceKey: sourceKey,
    );
    final normalizedTargets = <MangaChapterDownloadTarget>[];
    final seen = <String>{};
    for (final target in chapters) {
      if (target.epId.isEmpty ||
          (existingDownloaded?.chapters.any(
                (chapter) => _downloadedChapterMatchesTarget(chapter, target),
              ) ??
              false) ||
          !seen.add(target.epId)) {
        continue;
      }
      normalizedTargets.add(target);
    }
    if (normalizedTargets.isEmpty) {
      return;
    }

    final existingTaskIndex = _tasks.indexWhere(
      (task) => task.storageKey == details.scopedId.storageKey,
    );
    if (existingTaskIndex >= 0) {
      final task = _tasks[existingTaskIndex];
      final merged = <MangaChapterDownloadTarget>[
        ...task.targets,
        ...normalizedTargets.where(
          (target) => !task.targets.any((item) => item.epId == target.epId),
        ),
      ]..sort((a, b) => a.index.compareTo(b.index));
      _tasks[existingTaskIndex] = task.copyWith(
        title: details.title,
        subTitle: details.subTitle,
        description: description,
        coverUrl: coverUrl,
        tags: details.tags,
        uploader: details.uploader,
        updateTime: details.updateTime,
        pageCount: details.pageCount,
        targets: merged,
        status: MangaDownloadTaskStatus.queued,
        clearErrorMessage: true,
        retryCount: 0,
      );
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      _tasks.add(
        MangaDownloadTask(
          comicId: details.id,
          sourceKey: sourceKey,
          title: details.title,
          subTitle: details.subTitle,
          description: description,
          coverUrl: coverUrl,
          tags: details.tags,
          uploader: details.uploader,
          updateTime: details.updateTime,
          pageCount: details.pageCount,
          targets: normalizedTargets
            ..sort((a, b) => a.index.compareTo(b.index)),
          completedEpIds: <String>{},
          status: MangaDownloadTaskStatus.queued,
          createdAtMillis: now,
          updatedAtMillis: now,
        ),
      );
    }

    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
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
            (target) => _downloadedChapterMatchesTarget(chapter, target),
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
            (target) => _downloadedChapterMatchesTarget(chapter, target),
          ),
        )
        .toList(growable: false);
    if (remainingChapters.isEmpty) {
      _downloaded.removeWhere(
        (comic) => comic.storageKey == downloaded.storageKey,
      );
      await _deleteMetadataFiles(comicDir);
    } else {
      final updated = downloaded.copyWith(chapters: remainingChapters);
      _upsertDownloadedComic(updated);
      await _writeMetadataFile(comicDir, updated);
    }
    await _persistState();
    notifyListeners();
  }

  bool _downloadedChapterMatchesTarget(
    DownloadedMangaChapter downloaded,
    MangaChapterDownloadTarget target,
  ) {
    if (downloaded.epId == target.epId) {
      return true;
    }
    return RegExp(r'^local_\d+$').hasMatch(downloaded.epId.trim()) &&
        downloaded.index == target.index;
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

  Future<void> _deleteMetadataFiles(Directory comicDir) async {
    for (final name in const [_metadataFileName, _legacyMetadataFileName]) {
      final file = File('${comicDir.path}/$name');
      if (await file.exists()) {
        await file.delete();
      }
    }
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
        final comic = _downloadedComicByStorageKey(storageKey);
        final dirName =
            comic?.downloadDirName ??
            SourceScopedComicId.fromStorageKey(storageKey).downloadDirName;
        final dir = Directory('${rootDir.path}/$dirName');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
    _downloaded.removeWhere((item) => ids.contains(item.storageKey));
    await _persistState();
    notifyListeners();
  }

  Future<void> pauseTask(String storageKey) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.storageKey == storageKey);
    if (index < 0) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.paused,
    );
    await _persistState();
    notifyListeners();
  }

  Future<void> resumeTask(String storageKey) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.storageKey == storageKey);
    if (index < 0) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.queued,
      clearErrorMessage: true,
      retryCount: 0,
    );
    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
  }

  /// 暂停所有未完成的下载任务
  Future<void> pauseAllTasks() async {
    await ensureInitialized();
    // 找出所有非暂停状态的任务并将其设为暂停
    bool changed = false;
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status != MangaDownloadTaskStatus.paused) {
        _tasks[i] = task.copyWith(status: MangaDownloadTaskStatus.paused);
        changed = true;
      }
    }
    if (!changed) return;
    await _persistState();
    notifyListeners();
  }

  /// 恢复所有已暂停或失败的下载任务
  Future<void> resumeAllTasks() async {
    await ensureInitialized();
    // 找出所有暂停或失败状态的任务并将其设为排队等待
    bool changed = false;
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status == MangaDownloadTaskStatus.paused ||
          task.status == MangaDownloadTaskStatus.failed) {
        _tasks[i] = task.copyWith(
          status: MangaDownloadTaskStatus.queued,
          clearErrorMessage: true,
          retryCount: 0,
        );
        changed = true;
      }
    }
    if (!changed) return;
    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
  }

  Future<void> deleteTask(String storageKey) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.storageKey == storageKey);
    if (index < 0) {
      return;
    }

    final hasAccess = await _ensureAndroidDownloadsAccess();
    if (!hasAccess) {
      return;
    }

    final task = _tasks.removeAt(index);
    final rootDir = await _ensureRootDir();
    final comicDir = Directory('${rootDir.path}/${task.downloadDirName}');
    final downloadedComic = _downloadedComicByStorageKey(task.storageKey);
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
    _downloaded.clear();

    if (rescan) {
      final hasAccess = await _ensureAndroidDownloadsAccess();
      if (hasAccess) {
        final rootDir = await _ensureRootDir();
        final result = await _recoveryScanner.scanDownloadedFromDisk(rootDir);
        _downloaded.addAll(_mergeLegacyJmAliases(result.comics));
        _downloaded.sort(
          (a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis),
        );
      }
    }

    await _persistState();
    notifyListeners();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final restored = await _stateStore.restore(_prefs);
    _tasks
      ..clear()
      ..addAll(restored.tasks);
    _downloaded
      ..clear()
      ..addAll(restored.downloaded);
    _sanitizeRestoredDownloadedState();
    await _persistState();
  }

  Future<bool> _ensureAndroidDownloadsAccess() {
    return _access.ensureAndroidDownloadsAccess();
  }

  Future<Directory> _ensureRootDir() {
    return _access.ensureRootDir();
  }

  Future<String> _loadDownloadsRootPath() {
    return MangaDownloadAccess.loadDownloadsRootPath(prefs: _prefs);
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

  bool _shouldSuspendDownloads() => _downloadsSuspended;

  bool _shouldRecoverTransientDownloadError() {
    if (_downloadsSuspended) {
      return true;
    }
    final deadline = _downloadResumeGraceDeadline;
    if (deadline == null) {
      return false;
    }
    return DateTime.now().isBefore(deadline);
  }

  void _sanitizeRestoredDownloadedState() {
    final sanitized = <DownloadedMangaComic>[];
    final droppedIds = <String>[];
    for (final comic in _downloaded) {
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
    _downloaded
      ..clear()
      ..addAll(_mergeLegacyJmAliases(sanitized))
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
  }

  List<DownloadedMangaComic> _mergeLegacyJmAliases(
    Iterable<DownloadedMangaComic> comics,
  ) {
    final merged = <DownloadedMangaComic>[];
    for (final comic in comics) {
      final aliasIndex = merged.indexWhere(
        (item) =>
            item.comicId == comic.comicId &&
            ((item.sourceKey.isEmpty && isHazukiJmSourceKey(comic.sourceKey)) ||
                (comic.sourceKey.isEmpty &&
                    isHazukiJmSourceKey(item.sourceKey))),
      );
      if (aliasIndex < 0) {
        merged.add(comic);
        continue;
      }
      merged[aliasIndex] = _mergeDownloadedComicAliases(
        merged[aliasIndex],
        comic,
      );
    }
    return merged;
  }

  DownloadedMangaComic _mergeDownloadedComicAliases(
    DownloadedMangaComic first,
    DownloadedMangaComic second,
  ) {
    final scoped = first.sourceKey.isNotEmpty ? first : second;
    final legacy = identical(scoped, first) ? second : first;
    final chaptersByIndex = <int, DownloadedMangaChapter>{
      for (final chapter in legacy.chapters) chapter.index: chapter,
      for (final chapter in scoped.chapters) chapter.index: chapter,
    };
    final chapters = chaptersByIndex.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    String preferScoped(String scopedValue, String legacyValue) =>
        scopedValue.trim().isNotEmpty ? scopedValue : legacyValue;

    return DownloadedMangaComic(
      comicId: scoped.comicId,
      sourceKey: scoped.sourceKey,
      title: preferScoped(scoped.title, legacy.title),
      subTitle: preferScoped(scoped.subTitle, legacy.subTitle),
      description: preferScoped(scoped.description, legacy.description),
      coverUrl: preferScoped(scoped.coverUrl, legacy.coverUrl),
      tags: scoped.tags.isNotEmpty ? scoped.tags : legacy.tags,
      uploader: preferScoped(scoped.uploader, legacy.uploader),
      updateTime: preferScoped(scoped.updateTime, legacy.updateTime),
      pageCount: preferScoped(scoped.pageCount, legacy.pageCount),
      localCoverPath: scoped.localCoverPath ?? legacy.localCoverPath,
      chapters: chapters,
      updatedAtMillis: scoped.updatedAtMillis > legacy.updatedAtMillis
          ? scoped.updatedAtMillis
          : legacy.updatedAtMillis,
    );
  }

  bool _replaceTask(String storageKey, MangaDownloadTask next) {
    final index = _tasks.indexWhere(
      (item) =>
          item.storageKey == storageKey || item.storageKey == next.storageKey,
    );
    if (index < 0) {
      return false;
    }
    _tasks[index] = next;
    return true;
  }

  bool _removeTaskByComicId(String storageKey) {
    final index = _tasks.indexWhere(
      (item) =>
          item.storageKey == storageKey ||
          (item.sourceKey.isEmpty && item.comicId == storageKey),
    );
    if (index < 0) {
      return false;
    }
    _tasks.removeAt(index);
    return true;
  }

  MangaDownloadTask? _latestTask(String storageKey) {
    for (final item in _tasks) {
      if (item.storageKey == storageKey ||
          (item.sourceKey.isEmpty && item.comicId == storageKey)) {
        return item;
      }
    }
    return null;
  }

  Future<bool> _shouldAbortTask(String storageKey) async {
    final latest = _latestTask(storageKey);
    if (latest == null) {
      return true;
    }
    return latest.status == MangaDownloadTaskStatus.paused;
  }

  Directory _chapterDirForTarget(
    Directory comicDir,
    MangaChapterDownloadTarget target,
  ) {
    final chapterNumber = (target.index + 1).toString().padLeft(3, '0');
    return Directory('${comicDir.path}/MangaChapter$chapterNumber');
  }

  Future<String?> _findExistingImagePath(
    Directory chapterDir,
    int imageIndex,
  ) async {
    final prefix = '${imageIndex.toString().padLeft(4, '0')}.';
    try {
      await for (final entity in chapterDir.list()) {
        if (entity is! File) {
          continue;
        }
        if (_entityBaseName(entity).startsWith(prefix)) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _downloadCoverIfNeeded({
    required MangaDownloadTask task,
    required Directory comicDir,
  }) async {
    final normalized = task.coverUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final existing = await _recoveryScanner.findLocalCoverFile(comicDir);
    if (existing != null) {
      return existing.path;
    }
    final target = File('${comicDir.path}/cover.jpg');
    try {
      final bytes = await sl<HazukiSourceService>().downloadImageBytes(
        normalized,
        keepInMemory: false,
        sourceKey: task.sourceKey,
      );
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  void _upsertDownloadedComic(DownloadedMangaComic comic) {
    var index = _downloaded.indexWhere(
      (item) => item.storageKey == comic.storageKey,
    );
    if (index < 0 && isHazukiJmSourceKey(comic.sourceKey)) {
      index = _downloaded.indexWhere(
        (item) => item.sourceKey.isEmpty && item.comicId == comic.comicId,
      );
    }
    if (index >= 0) {
      _downloaded[index] = comic;
    } else {
      _downloaded.add(comic);
    }
    _downloaded.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
  }

  Future<void> _writeMetadataFile(
    Directory comicDir,
    DownloadedMangaComic comic,
  ) async {
    final file = File('${comicDir.path}/$_metadataFileName');
    await file.writeAsString(jsonEncode(comic.toJson()), flush: true);
    final legacy = File('${comicDir.path}/$_legacyMetadataFileName');
    if (await legacy.exists()) {
      try {
        await legacy.delete();
      } catch (_) {}
    }
  }

  String _entityBaseName(FileSystemEntity entity) {
    return _baseNameFromPath(entity.path);
  }

  String _baseNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }
}
