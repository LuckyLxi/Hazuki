import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazuki_models.dart';
import 'hazuki_source_service.dart';
import 'manga_download_models.dart';
import 'manga_download_queue_support.dart';
import 'manga_download_recovery_support.dart';
import 'manga_download_storage_support.dart';

export 'manga_download_models.dart';

class MangaDownloadService extends ChangeNotifier {
  MangaDownloadService._() {
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
      downloadedComicById: downloadedComicById,
      upsertDownloadedComic: _upsertDownloadedComic,
      flushState: _flushState,
      ensureAndroidDownloadsAccess: _ensureAndroidDownloadsAccess,
      ensureRootDir: _ensureRootDir,
      findExistingImagePath: _findExistingImagePath,
      downloadCoverIfNeeded: _downloadCoverIfNeeded,
      writeMetadataFile: _writeMetadataFile,
      chapterDirForTarget: _chapterDirForTarget,
      shouldSuspendDownloads: _shouldSuspendDownloads,
      shouldRecoverTransientNetworkError: _shouldRecoverTransientDownloadError,
    );
  }

  static final MangaDownloadService instance = MangaDownloadService._();

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

  void _logScan(String title, {Object? content, String level = 'info'}) {
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
      content: content,
      source: 'download_scan',
    );
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    final suspendDownloads = state != AppLifecycleState.resumed;
    if (suspendDownloads == _downloadsSuspended &&
        state != AppLifecycleState.resumed) {
      return;
    }

    _downloadsSuspended = suspendDownloads;
    _downloadResumeTimer?.cancel();
    _downloadResumeTimer = null;

    if (suspendDownloads) {
      _downloadResumeGraceDeadline = null;
      _logScan(
        'Downloads suspended for app lifecycle',
        level: 'warning',
        content: {'state': state.name},
      );
      return;
    }

    _downloadResumeGraceDeadline = DateTime.now().add(
      const Duration(seconds: 4),
    );
    _logScan(
      'Downloads resume recovery scheduled',
      content: {'state': state.name},
    );
    _downloadResumeTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_downloadsSuspended) {
        return;
      }
      unawaited(_queueExecutor.processQueue());
    });
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
      ..addAll(result.comics)
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
    for (final item in _downloaded) {
      if (item.comicId == comicId) {
        return item;
      }
    }
    return null;
  }

  MangaDownloadTask? taskByComicId(String comicId) {
    for (final item in _tasks) {
      if (item.comicId == comicId) {
        return item;
      }
    }
    return null;
  }

  Future<void> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    if (chapters.isEmpty) {
      return;
    }

    await ensureInitialized();
    final existingDownloaded = downloadedComicById(details.id);
    final downloadedEpIds = existingDownloaded == null
        ? <String>{}
        : existingDownloaded.chapters.map((e) => e.epId).toSet();

    final normalizedTargets = <MangaChapterDownloadTarget>[];
    final seen = <String>{};
    for (final target in chapters) {
      if (target.epId.isEmpty ||
          downloadedEpIds.contains(target.epId) ||
          !seen.add(target.epId)) {
        continue;
      }
      normalizedTargets.add(target);
    }
    if (normalizedTargets.isEmpty) {
      return;
    }

    final existingTaskIndex = _tasks.indexWhere(
      (task) => task.comicId == details.id,
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
        targets: merged,
        status: MangaDownloadTaskStatus.queued,
        clearErrorMessage: true,
      );
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      _tasks.add(
        MangaDownloadTask(
          comicId: details.id,
          title: details.title,
          subTitle: details.subTitle,
          description: description,
          coverUrl: coverUrl,
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
    for (final comicId in ids) {
      try {
        final dir = Directory('${rootDir.path}/$comicId');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
    _downloaded.removeWhere((item) => ids.contains(item.comicId));
    await _persistState();
    notifyListeners();
  }

  Future<void> pauseTask(String comicId) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.paused,
    );
    await _persistState();
    notifyListeners();
  }

  Future<void> resumeTask(String comicId) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.queued,
      clearErrorMessage: true,
    );
    await _persistState();
    notifyListeners();
    unawaited(_queueExecutor.processQueue());
  }

  Future<void> deleteTask(String comicId) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return;
    }

    final hasAccess = await _ensureAndroidDownloadsAccess();
    if (!hasAccess) {
      return;
    }

    final task = _tasks.removeAt(index);
    final rootDir = await _ensureRootDir();
    final comicDir = Directory('${rootDir.path}/${task.comicId}');
    final downloadedComic = downloadedComicById(task.comicId);
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

  Future<void> _persistState() {
    return _stateStore.persist(
      prefs: _prefs,
      tasks: _tasks,
      downloaded: _downloaded,
    );
  }

  Future<void> _flushState() async {
    await _persistState();
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
    for (final comic in _downloaded) {
      final normalized = _recoveryScanner.sanitizeDownloadedComicState(comic);
      if (normalized != null) {
        sanitized.add(normalized);
      }
    }
    _downloaded
      ..clear()
      ..addAll(sanitized)
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
  }

  bool _replaceTask(String comicId, MangaDownloadTask next) {
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return false;
    }
    _tasks[index] = next;
    return true;
  }

  bool _removeTaskByComicId(String comicId) {
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return false;
    }
    _tasks.removeAt(index);
    return true;
  }

  MangaDownloadTask? _latestTask(String comicId) {
    for (final item in _tasks) {
      if (item.comicId == comicId) {
        return item;
      }
    }
    return null;
  }

  Future<bool> _shouldAbortTask(String comicId) async {
    final latest = _latestTask(comicId);
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
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalized,
        keepInMemory: false,
      );
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  void _upsertDownloadedComic(DownloadedMangaComic comic) {
    final index = _downloaded.indexWhere(
      (item) => item.comicId == comic.comicId,
    );
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
