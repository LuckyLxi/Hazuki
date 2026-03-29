import 'dart:io';

import 'hazuki_source_service.dart';
import 'manga_download_models.dart';
import 'manga_download_storage_support.dart';

typedef MangaDownloadReplaceTask =
    bool Function(String comicId, MangaDownloadTask next);
typedef MangaDownloadRemoveTask = bool Function(String comicId);
typedef MangaDownloadLatestTask = MangaDownloadTask? Function(String comicId);
typedef MangaDownloadAbortCheck = Future<bool> Function(String comicId);
typedef MangaDownloadFindDownloadedComic =
    DownloadedMangaComic? Function(String comicId);
typedef MangaDownloadUpsertComic = void Function(DownloadedMangaComic comic);
typedef MangaDownloadStateFlush = Future<void> Function();
typedef MangaDownloadEnsureAccess = Future<bool> Function();
typedef MangaDownloadEnsureRootDir = Future<Directory> Function();
typedef MangaDownloadFindExistingImagePath =
    Future<String?> Function(Directory chapterDir, int imageIndex);
typedef MangaDownloadCoverDownload =
    Future<String?> Function({
      required MangaDownloadTask task,
      required Directory comicDir,
    });
typedef MangaDownloadWriteMetadata =
    Future<void> Function(Directory comicDir, DownloadedMangaComic comic);
typedef MangaDownloadChapterDirBuilder =
    Directory Function(Directory comicDir, MangaChapterDownloadTarget target);

class MangaDownloadQueueExecutor {
  MangaDownloadQueueExecutor({
    required List<MangaDownloadTask> tasks,
    required MangaDownloadReplaceTask replaceTask,
    required MangaDownloadRemoveTask removeTaskByComicId,
    required MangaDownloadLatestTask latestTask,
    required MangaDownloadAbortCheck shouldAbortTask,
    required MangaDownloadFindDownloadedComic downloadedComicById,
    required MangaDownloadUpsertComic upsertDownloadedComic,
    required MangaDownloadStateFlush flushState,
    required MangaDownloadEnsureAccess ensureAndroidDownloadsAccess,
    required MangaDownloadEnsureRootDir ensureRootDir,
    required MangaDownloadFindExistingImagePath findExistingImagePath,
    required MangaDownloadCoverDownload downloadCoverIfNeeded,
    required MangaDownloadWriteMetadata writeMetadataFile,
    required MangaDownloadChapterDirBuilder chapterDirForTarget,
  }) : _tasks = tasks,
       _replaceTask = replaceTask,
       _removeTaskByComicId = removeTaskByComicId,
       _latestTask = latestTask,
       _shouldAbortTask = shouldAbortTask,
       _downloadedComicById = downloadedComicById,
       _upsertDownloadedComic = upsertDownloadedComic,
       _flushState = flushState,
       _ensureAndroidDownloadsAccess = ensureAndroidDownloadsAccess,
       _ensureRootDir = ensureRootDir,
       _findExistingImagePath = findExistingImagePath,
       _downloadCoverIfNeeded = downloadCoverIfNeeded,
       _writeMetadataFile = writeMetadataFile,
       _chapterDirForTarget = chapterDirForTarget;

  final List<MangaDownloadTask> _tasks;
  final MangaDownloadReplaceTask _replaceTask;
  final MangaDownloadRemoveTask _removeTaskByComicId;
  final MangaDownloadLatestTask _latestTask;
  final MangaDownloadAbortCheck _shouldAbortTask;
  final MangaDownloadFindDownloadedComic _downloadedComicById;
  final MangaDownloadUpsertComic _upsertDownloadedComic;
  final MangaDownloadStateFlush _flushState;
  final MangaDownloadEnsureAccess _ensureAndroidDownloadsAccess;
  final MangaDownloadEnsureRootDir _ensureRootDir;
  final MangaDownloadFindExistingImagePath _findExistingImagePath;
  final MangaDownloadCoverDownload _downloadCoverIfNeeded;
  final MangaDownloadWriteMetadata _writeMetadataFile;
  final MangaDownloadChapterDirBuilder _chapterDirForTarget;

  bool _processing = false;

  Future<void> processQueue() async {
    if (_processing) {
      return;
    }
    _processing = true;
    try {
      while (true) {
        final taskIndex = _tasks.indexWhere(
          (task) => task.status == MangaDownloadTaskStatus.queued,
        );
        if (taskIndex < 0) {
          break;
        }
        await runTask(taskIndex);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> runTask(int taskIndex) async {
    if (taskIndex < 0 || taskIndex >= _tasks.length) {
      return;
    }
    var task = _tasks[taskIndex].copyWith(
      status: MangaDownloadTaskStatus.downloading,
      clearErrorMessage: true,
    );
    if (!_replaceTask(task.comicId, task)) {
      return;
    }
    await _flushState();

    try {
      if (!await _ensureAndroidDownloadsAccess()) {
        throw FileSystemException(
          'Android downloads access not granted',
          MangaDownloadAccess.downloadsRootPath,
        );
      }
      final rootDir = await _ensureRootDir();
      final comicDir = Directory('${rootDir.path}/${task.comicId}');
      if (!await comicDir.exists()) {
        await comicDir.create(recursive: true);
      }

      var downloadedComic =
          _downloadedComicById(task.comicId) ??
          DownloadedMangaComic(
            comicId: task.comicId,
            title: task.title,
            subTitle: task.subTitle,
            description: task.description,
            coverUrl: task.coverUrl,
            localCoverPath: null,
            chapters: const <DownloadedMangaChapter>[],
            updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
          );

      final localCoverPath = await _downloadCoverIfNeeded(
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
      final sourceService = HazukiSourceService.instance;

      for (final target in task.targets) {
        if (await _shouldAbortTask(task.comicId)) {
          return;
        }
        if (existingChapterIds.contains(target.epId)) {
          task = task.copyWith(
            completedEpIds: {...task.completedEpIds, target.epId},
          );
          if (!_replaceTask(task.comicId, task)) {
            return;
          }
          continue;
        }

        final imageUrls = await sourceService.loadChapterImages(
          comicId: task.comicId,
          epId: target.epId,
        );
        if (await _shouldAbortTask(task.comicId)) {
          return;
        }
        final chapterDir = _chapterDirForTarget(comicDir, target);
        if (!await chapterDir.exists()) {
          await chapterDir.create(recursive: true);
        }

        final savedPaths = <String>[];
        for (var i = 0; i < imageUrls.length; i++) {
          final existingPath = await _findExistingImagePath(chapterDir, i + 1);
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
        if (!_replaceTask(task.comicId, task)) {
          return;
        }
        await _flushState();

        for (var i = savedPaths.length; i < imageUrls.length; i++) {
          if (await _shouldAbortTask(task.comicId)) {
            return;
          }
          final imageUrl = imageUrls[i];
          final prepared = await sourceService.prepareChapterImageData(
            imageUrl,
            comicId: task.comicId,
            epId: target.epId,
          );
          if (await _shouldAbortTask(task.comicId)) {
            return;
          }
          final fileName =
              '${(i + 1).toString().padLeft(4, '0')}.${prepared.extension}';
          final file = File('${chapterDir.path}/$fileName');
          await file.writeAsBytes(prepared.bytes, flush: true);
          savedPaths.add(file.path);
          task = task.copyWith(
            currentChapterEpId: target.epId,
            currentChapterTitle: target.title,
            currentImageIndex: i + 1,
            currentImageTotal: imageUrls.length,
          );
          if (!_replaceTask(task.comicId, task)) {
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
        if (!_replaceTask(task.comicId, task)) {
          return;
        }

        downloadedComic = downloadedComic.copyWith(
          chapters: downloadedChapters,
          updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
        );
        _upsertDownloadedComic(downloadedComic);
        await _writeMetadataFile(comicDir, downloadedComic);
        await _flushState();
      }

      _removeTaskByComicId(task.comicId);
      _upsertDownloadedComic(downloadedComic);
      await _writeMetadataFile(comicDir, downloadedComic);
      await _flushState();
    } catch (e) {
      final latest = _latestTask(task.comicId);
      if (latest == null) {
        return;
      }
      _replaceTask(
        task.comicId,
        latest.copyWith(
          status: MangaDownloadTaskStatus.failed,
          clearCurrentChapterEpId: true,
          clearCurrentChapterTitle: true,
          currentImageIndex: 0,
          currentImageTotal: 0,
          errorMessage: e.toString(),
        ),
      );
      await _flushState();
    }
  }
}
