import 'dart:io';

import '../network/hazuki_network.dart';
import '../source/source_capabilities.dart';
import 'manga_download_models.dart';
import 'manga_download_state.dart';
import 'manga_download_files.dart';
import 'manga_download_storage_support.dart';

class MangaDownloadQueueExecutor {
  MangaDownloadQueueExecutor({
    required MangaDownloadLogCallback logDownload,
    required MangaDownloadState state,
    required MangaDownloadFiles files,
    required MangaDownloadAccess access,
    required Future<void> Function() flushState,
    required bool Function() shouldSuspendDownloads,
    required bool Function() shouldRecoverTransientNetworkError,
    required SourceReaderGateway? sourceReader,
  }) : _state = state,
       _files = files,
       _access = access,
       _logDownload = logDownload,
       _flushState = flushState,
       _shouldSuspendDownloads = shouldSuspendDownloads,
       _shouldRecoverTransientNetworkError = shouldRecoverTransientNetworkError,
       _sourceReader = sourceReader;

  final MangaDownloadState _state;
  final MangaDownloadFiles _files;
  final MangaDownloadAccess _access;
  final SourceReaderGateway? _sourceReader;
  final MangaDownloadLogCallback _logDownload;
  final Future<void> Function() _flushState;
  final bool Function() _shouldSuspendDownloads;
  final bool Function() _shouldRecoverTransientNetworkError;

  static const int _maxTransientRetries = 5;

  bool _processing = false;

  Future<void> processQueue() async {
    if (_processing) {
      return;
    }
    _processing = true;
    try {
      while (true) {
        if (_shouldSuspendDownloads()) {
          break;
        }
        final task = _state.nextQueuedTask;
        if (task == null) break;
        await _runTask(task);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _runTask(MangaDownloadTask selected) async {
    var task = selected.copyWith(
      status: MangaDownloadTaskStatus.downloading,
      clearErrorMessage: true,
    );
    if (!_state.updateTask(task.storageKey, task)) {
      return;
    }
    await _flushState();

    if (_shouldSuspendDownloads()) {
      await _requeueTaskForRetry(
        task,
        reason: 'downloads_suspended_before_run',
      );
      return;
    }

    try {
      if (!await _access.ensureAndroidDownloadsAccess()) {
        final rootPath = await MangaDownloadAccess.loadDownloadsRootPath();
        throw FileSystemException(
          'Android downloads access not granted',
          rootPath,
        );
      }
      final rootDir = await _access.ensureRootDir();
      final comicDir = await _files.ensureComicDirectory(rootDir, task);

      var downloadedComic =
          _state.downloadedComicByStorageKey(task.storageKey) ??
          DownloadedMangaComic(
            comicId: task.comicId,
            sourceKey: task.sourceKey,
            title: task.title,
            subTitle: task.subTitle,
            description: task.description,
            coverUrl: task.coverUrl,
            tags: task.tags,
            uploader: task.uploader,
            updateTime: task.updateTime,
            pageCount: task.pageCount,
            localCoverPath: null,
            chapters: const <DownloadedMangaChapter>[],
            updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
          );
      if (downloadedComic.sourceKey.isEmpty && task.sourceKey.isNotEmpty) {
        downloadedComic = downloadedComic.copyWith(sourceKey: task.sourceKey);
      }
      downloadedComic = downloadedComic.mergeTaskMetadata(task);

      final localCoverPath = await _files.downloadCoverIfNeeded(
        task: task,
        comicDir: comicDir,
      );
      downloadedComic = downloadedComic.copyWith(
        localCoverPath: localCoverPath,
      );

      final downloadedChapters = <DownloadedMangaChapter>[
        ...downloadedComic.chapters,
      ];
      final existingChapterIds = downloadedChapters.map((e) => e.epId).toSet();
      final sourceReader = _sourceReader;
      if (sourceReader == null) {
        throw StateError('manga_download_source_reader_not_configured');
      }
      for (final target in task.targets) {
        if (_state.shouldAbortTask(task.storageKey)) {
          return;
        }
        if (_shouldSuspendDownloads()) {
          await _requeueTaskForRetry(
            task,
            reason: 'downloads_suspended_before_chapter',
          );
          return;
        }
        if (existingChapterIds.contains(target.epId)) {
          task = task.copyWith(
            completedEpIds: {...task.completedEpIds, target.epId},
          );
          if (!_state.updateTask(task.storageKey, task)) {
            return;
          }
          continue;
        }

        final imageUrls = await sourceReader.loadChapterImages(
          comicId: task.comicId,
          epId: target.epId,
          sourceKey: task.sourceKey,
        );
        if (_state.shouldAbortTask(task.storageKey)) {
          return;
        }
        final chapterDir = await _files.ensureChapterDirectory(
          comicDir,
          target,
        );

        final savedPaths = <String>[];
        for (var i = 0; i < imageUrls.length; i++) {
          final existingPath = await _files.findExistingImagePath(
            chapterDir,
            i + 1,
          );
          if (existingPath != null) {
            savedPaths.add(existingPath);
          }
        }
        task = task.copyWith(
          currentChapterEpId: target.epId,
          currentChapterTitle: target.title,
          currentImageIndex: savedPaths.length,
          currentImageTotal: imageUrls.length,
        );
        if (!_state.updateTask(task.storageKey, task)) {
          return;
        }
        await _flushState();

        for (var i = savedPaths.length; i < imageUrls.length; i++) {
          if (_state.shouldAbortTask(task.storageKey)) {
            return;
          }
          if (_shouldSuspendDownloads()) {
            await _requeueTaskForRetry(
              task,
              reason: 'downloads_suspended_before_image',
            );
            return;
          }
          final imageUrl = imageUrls[i];
          final prepared = await sourceReader.prepareChapterImageData(
            imageUrl,
            comicId: task.comicId,
            epId: target.epId,
            sourceKey: task.sourceKey,
          );
          if (_state.shouldAbortTask(task.storageKey)) {
            return;
          }
          final path = await _files.writeChapterImage(
            chapterDir,
            i + 1,
            prepared,
          );
          savedPaths.add(path);
          task = task.copyWith(
            currentChapterEpId: target.epId,
            currentChapterTitle: target.title,
            currentImageIndex: i + 1,
            currentImageTotal: imageUrls.length,
          );
          if (!_state.updateTask(task.storageKey, task)) {
            return;
          }
          await _flushState();
        }

        downloadedChapters.add(
          DownloadedMangaChapter(
            epId: target.epId,
            title: target.title,
            index: target.index,
            imagePaths: savedPaths,
          ),
        );
        downloadedChapters.sort((a, b) => a.index.compareTo(b.index));

        task = task.copyWith(
          completedEpIds: {...task.completedEpIds, target.epId},
          clearCurrentChapterEpId: true,
          clearCurrentChapterTitle: true,
          currentImageIndex: 0,
          currentImageTotal: 0,
        );
        if (!_state.updateTask(task.storageKey, task)) {
          return;
        }

        downloadedComic = downloadedComic.copyWith(
          chapters: downloadedChapters,
          updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
        );
        _state.upsertDownloadedComic(downloadedComic);
        await _files.writeMetadataFile(comicDir, downloadedComic);
        await _flushState();
      }

      final latest = _state.taskByStorageKey(task.storageKey);
      final hasPendingTargets =
          latest?.targets.any(
            (target) => !latest.completedEpIds.contains(target.epId),
          ) ??
          false;
      if (latest != null && hasPendingTargets) {
        _state.updateTask(
          task.storageKey,
          latest.copyWith(
            status: MangaDownloadTaskStatus.queued,
            clearCurrentChapterEpId: true,
            clearCurrentChapterTitle: true,
            currentImageIndex: 0,
            currentImageTotal: 0,
          ),
        );
        await _flushState();
        return;
      }

      _state.removeTask(task.storageKey);
      _state.upsertDownloadedComic(downloadedComic);
      await _files.writeMetadataFile(comicDir, downloadedComic);
      await _flushState();
    } catch (e) {
      if (_isTransientDownloadError(e) &&
          _shouldRecoverTransientNetworkError()) {
        await _requeueTaskForRetry(
          task,
          reason: 'transient_network_error',
          error: e,
          countAsRetry: true,
        );
        return;
      }
      final latest = _state.taskByStorageKey(task.storageKey);
      if (latest == null) {
        _logDownload(
          'Download task vanished during error handling',
          level: 'warning',
          content: {'comicId': task.comicId, 'error': e.toString()},
        );
        return;
      }
      _state.updateTask(
        task.storageKey,
        latest.copyWith(
          status: MangaDownloadTaskStatus.failed,
          clearCurrentChapterEpId: true,
          clearCurrentChapterTitle: true,
          currentImageIndex: 0,
          currentImageTotal: 0,
          errorMessage: e.toString(),
          retryCount: 0,
        ),
      );
      await _flushState();
    }
  }

  Future<void> _requeueTaskForRetry(
    MangaDownloadTask task, {
    required String reason,
    Object? error,
    bool countAsRetry = false,
  }) async {
    final latest = _state.taskByStorageKey(task.storageKey);
    if (latest == null) {
      return;
    }
    _logDownload(
      'Deferred manga download task',
      level: 'warning',
      content: {
        'comicId': task.comicId,
        'title': task.title,
        'reason': reason,
        if (error != null) 'error': error.toString(),
      },
    );
    if (countAsRetry) {
      final newRetryCount = latest.retryCount + 1;
      if (newRetryCount >= _maxTransientRetries) {
        _state.updateTask(
          task.storageKey,
          latest.copyWith(
            status: MangaDownloadTaskStatus.failed,
            clearCurrentChapterEpId: true,
            clearCurrentChapterTitle: true,
            currentImageIndex: 0,
            currentImageTotal: 0,
            errorMessage: error?.toString() ?? reason,
            retryCount: 0,
          ),
        );
        await _flushState();
        return;
      }
      _state.updateTask(
        task.storageKey,
        latest.copyWith(
          status: MangaDownloadTaskStatus.queued,
          clearErrorMessage: true,
          retryCount: newRetryCount,
        ),
      );
    } else {
      _state.updateTask(
        task.storageKey,
        latest.copyWith(
          status: MangaDownloadTaskStatus.queued,
          clearErrorMessage: true,
        ),
      );
    }
    await _flushState();
  }

  bool _isTransientDownloadError(Object error) {
    if (isHazukiTransientNetworkFailure(error)) {
      return true;
    }

    final text = error.toString().toLowerCase();
    return text.contains('failed host lookup') ||
        text.contains('socketexception') ||
        text.contains('connection error');
  }
}
