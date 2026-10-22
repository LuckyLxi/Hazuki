import 'dart:async';
import 'dart:io';

import '../network/hazuki_network.dart';
import '../source/source_capabilities.dart';
import '../source/interaction/source_ui_scope.dart';
import 'manga_download_run.dart';
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
    SourceTaskControlGateway? taskControl,
  }) : _state = state,
       _files = files,
       _access = access,
       _logDownload = logDownload,
       _flushState = flushState,
       _shouldSuspendDownloads = shouldSuspendDownloads,
       _shouldRecoverTransientNetworkError = shouldRecoverTransientNetworkError,
       _sourceReader = sourceReader,
       _taskControl = taskControl;

  final MangaDownloadState _state;
  final MangaDownloadFiles _files;
  final MangaDownloadAccess _access;
  final SourceReaderGateway? _sourceReader;
  final SourceTaskControlGateway? _taskControl;
  final MangaDownloadLogCallback _logDownload;
  final Future<void> Function() _flushState;
  final bool Function() _shouldSuspendDownloads;
  final bool Function() _shouldRecoverTransientNetworkError;

  static const int _maxTransientRetries = 5;

  final String _ownerId = createSourceTaskId();
  final Map<String, MangaDownloadRun> _runs = {};
  final Map<String, Future<void>> _barriers = {};
  final Map<String, int> _blocked = {};
  Future<void> _allTail = Future.value();
  int _allBlocked = 0;
  bool _disposed = false;
  bool _processing = false;

  Future<void> stopTask(String key, SourceTaskStopReason reason) {
    final run = _runs[key];
    if (run == null) return Future.value();
    run.stop(reason);
    return run.whenSettled;
  }

  Future<T> withTaskBarrier<T>(
    String key,
    Future<T> Function() operation, {
    bool stop = true,
    SourceTaskStopReason reason = SourceTaskStopReason.superseded,
  }) => withTaskBarriers([key], operation, stop: stop, reason: reason);

  Future<T> withTaskBarriers<T>(
    Iterable<String> keys,
    Future<T> Function() operation, {
    bool stop = true,
    SourceTaskStopReason reason = SourceTaskStopReason.superseded,
  }) {
    final affected = keys.toSet();
    final prior = <Future<void>>[_allTail];
    for (final key in affected) {
      _blocked[key] = (_blocked[key] ?? 0) + 1;
      if (_barriers[key] case final pending?) prior.add(pending);
      if (stop) prior.add(stopTask(key, reason));
    }
    final result = () async {
      try {
        await Future.wait(prior);
        if (_disposed) throw StateError('download_service_disposed');
        return await operation();
      } finally {
        for (final key in affected) {
          final remaining = _blocked[key]! - 1;
          if (remaining == 0) {
            _blocked.remove(key);
          } else {
            _blocked[key] = remaining;
          }
        }
      }
    }();
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    for (final key in affected) {
      _barriers[key] = tail;
    }
    tail.whenComplete(() {
      for (final key in affected) {
        if (identical(_barriers[key], tail)) _barriers.remove(key);
      }
      if (!_disposed) unawaited(processQueue());
    });
    return result;
  }

  Future<T> withAllBarrier<T>(Future<T> Function() operation) {
    _allBlocked++;
    final prior = _allTail;
    final pending = _barriers.values.toList();
    final drains = _runs.keys
        .toList()
        .map((key) => stopTask(key, SourceTaskStopReason.downloadPaused))
        .toList();
    final result = () async {
      try {
        await prior;
        await Future.wait([...pending, ...drains]);
        if (_disposed) throw StateError('download_service_disposed');
        return await operation();
      } finally {
        _allBlocked--;
      }
    }();
    _allTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _allTail.whenComplete(() {
      if (!_disposed) unawaited(processQueue());
    });
    return result;
  }

  Future<void> dispose() async {
    _disposed = true;
    final drains = _runs.keys
        .toList()
        .map((key) => stopTask(key, SourceTaskStopReason.ownerDisposed))
        .toList();
    await Future.wait([...drains, ..._barriers.values, _allTail]);
  }

  Future<void> processQueue() =>
      SourceUiScope.withoutInteraction(_processQueue);

  Future<void> _processQueue() async {
    if (_processing || _disposed || _allBlocked > 0) {
      return;
    }
    _processing = true;
    try {
      while (true) {
        if (_disposed || _allBlocked > 0 || _shouldSuspendDownloads()) {
          break;
        }
        final task = _state.tasks
            .where(
              (task) =>
                  task.status == MangaDownloadTaskStatus.queued &&
                  !_blocked.containsKey(task.storageKey),
            )
            .firstOrNull;
        if (task == null) break;
        await _runTask(task);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _runTask(MangaDownloadTask selected) async {
    SourceDownloadSession? session;
    MangaDownloadRun? running;
    void sessionStopped() {
      final reason = session?.cancellation.reason;
      if (reason == null) return;
      running?.stop(reason);
      if (reason == SourceTaskStopReason.pluginDisabled ||
          reason == SourceTaskStopReason.pluginUpdated ||
          reason == SourceTaskStopReason.runtimeClosed) {
        _state.pauseTask(selected.storageKey);
      }
    }

    try {
      final reader = _sourceReader;
      if (reader is SourceDownloadSessionGateway) {
        session = (reader as SourceDownloadSessionGateway)
            .acquireDownloadSession(selected.sourceKey);
      }
      final run = MangaDownloadRun(
        ownerId: _ownerId,
        control: _taskControl,
        session: session,
        isCurrent: () =>
            !_disposed &&
            identical(_runs[selected.storageKey], running) &&
            !_state.shouldAbortTask(selected.storageKey),
      );
      running = run;
      _runs[selected.storageKey] = run;
      session?.cancellation.addListener(sessionStopped);
      sessionStopped();
      await _executeTask(selected, run);
    } on SourceTaskCancelled catch (error) {
      if (error is SourceTaskTimedOut && running?.cancellation.reason == null) {
        rethrow;
      }
      running?.stop(error.reason);
      _state.pauseTask(selected.storageKey);
    } catch (error) {
      if (running == null) {
        _state.updateTask(
          selected.storageKey,
          selected.copyWith(
            status: MangaDownloadTaskStatus.failed,
            errorMessage: error.toString(),
          ),
        );
      } else {
        rethrow;
      }
    } finally {
      session?.cancellation.removeListener(sessionStopped);
      try {
        if (!_disposed) await _flushState();
      } finally {
        if (running != null) {
          await running.finish();
          if (identical(_runs[selected.storageKey], running)) {
            _runs.remove(selected.storageKey);
          }
        } else {
          session?.close();
        }
      }
    }
  }

  Future<void> _executeTask(
    MangaDownloadTask selected,
    MangaDownloadRun run,
  ) async {
    run.checkActive();
    var task = selected.copyWith(
      status: MangaDownloadTaskStatus.downloading,
      clearErrorMessage: true,
    );
    if (!_state.updateTask(task.storageKey, task)) {
      return;
    }
    await run.commit(_flushState);

    if (_shouldSuspendDownloads()) {
      await _requeueTaskForRetry(
        task,
        reason: 'downloads_suspended_before_run',
      );
      return;
    }

    final sourceKey = run.session?.sourceKey ?? task.sourceKey;
    try {
      if (!await _access.ensureAndroidDownloadsAccess()) {
        final rootPath = await MangaDownloadAccess.loadDownloadsRootPath();
        throw FileSystemException(
          'Android downloads access not granted',
          rootPath,
        );
      }
      run.checkActive();
      final rootDir = await run.commit(_access.ensureRootDir);
      final comicDir = await run.commit(
        () => _files.ensureComicDirectory(rootDir, task),
      );

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
        run: run,
      );
      run.checkActive();
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
        run.checkActive();
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
          sourceKey: sourceKey,
          taskOrigin: run.origin,
        );
        run.checkActive();
        if (_state.shouldAbortTask(task.storageKey)) {
          return;
        }
        final chapterDir = await run.commit(
          () => _files.ensureChapterDirectory(comicDir, target),
        );

        final savedPaths = <String>[];
        for (var i = 0; i < imageUrls.length; i++) {
          run.checkActive();
          final existingPath = await _files.findExistingImagePath(
            chapterDir,
            i + 1,
          );
          if (existingPath == null) break;
          savedPaths.add(existingPath);
        }
        run.checkActive();
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
          run.checkActive();
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
            sourceKey: sourceKey,
            taskOrigin: run.origin,
          );
          run.checkActive();
          if (_state.shouldAbortTask(task.storageKey)) {
            return;
          }
          final path = await run.commit(
            () =>
                _files.writeChapterImage(chapterDir, i + 1, prepared, run: run),
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

        run.checkActive();
        downloadedChapters.add(
          DownloadedMangaChapter(
            epId: target.epId,
            title: target.title,
            index: target.index,
            directoryIndex: target.directoryIndex,
            groupId: target.groupId,
            groupTitle: target.groupTitle,
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
        await run.commit(
          () => _files.writeMetadataFile(comicDir, downloadedComic, run: run),
        );
        run.checkActive();
        await run.commit(_flushState);
      }

      run.checkActive();
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

      run.checkActive();
      await run.commit(() async {
        await _files.writeMetadataFile(comicDir, downloadedComic, run: run);
        run.checkActive();
        _state.upsertDownloadedComic(downloadedComic);
        _state.removeTask(task.storageKey);
        await _flushState();
      }, checkAfter: false);
    } catch (e) {
      if (e is SourceTaskCancelled && e is! SourceTaskTimedOut) rethrow;
      run.checkActive();
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
