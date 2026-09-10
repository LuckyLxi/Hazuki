import '../../models/hazuki_models.dart';
import '../source/models/source_identity.dart';
import 'manga_download_models.dart';

/// Owns download records. Callers receive snapshots and mutate through commands.
class MangaDownloadState {
  final List<MangaDownloadTask> _tasks = [];
  final List<DownloadedMangaComic> _downloaded = [];

  List<MangaDownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadedMangaComic> get downloadedComics =>
      List.unmodifiable(_downloaded);

  MangaDownloadTask? get nextQueuedTask {
    for (final task in _tasks) {
      if (task.status == MangaDownloadTaskStatus.queued) return task;
    }
    return null;
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

  DownloadedMangaComic? downloadedComicByStorageKey(String storageKey) {
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

  MangaDownloadEnqueueResult enqueue({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
  }) {
    final sourceKey = details.sourceKey.trim();
    final existingTaskIndex = _taskIndexForStorageKey(
      details.scopedId.storageKey,
    );
    final existingTask = existingTaskIndex < 0
        ? null
        : _tasks[existingTaskIndex];
    final existingDownloaded = downloadedComicByIdForSource(
      details.id,
      sourceKey: sourceKey,
    );
    final normalizedTargets = <MangaChapterDownloadTarget>[];
    final seen = <String>{};
    var hasQueuedTarget = false;
    for (final target in chapters) {
      if (existingTask?.targets.any((item) => item.epId == target.epId) ??
          false) {
        hasQueuedTarget = true;
        continue;
      }
      if (target.epId.isEmpty ||
          (existingDownloaded?.chapters.any(
                (chapter) => chapterMatchesTarget(chapter, target),
              ) ??
              false) ||
          !seen.add(target.epId)) {
        continue;
      }
      normalizedTargets.add(target);
    }
    if (normalizedTargets.isEmpty) {
      return hasQueuedTarget
          ? MangaDownloadEnqueueResult.alreadyQueued
          : MangaDownloadEnqueueResult.nothingToQueue;
    }

    if (existingTask != null) {
      final mergedTargets = [...existingTask.targets, ...normalizedTargets]
        ..sort((a, b) => a.index.compareTo(b.index));
      _tasks[existingTaskIndex] = existingTask.copyWith(
        title: details.title,
        subTitle: details.subTitle,
        description: description,
        coverUrl: coverUrl,
        tags: details.tags,
        uploader: details.uploader,
        updateTime: details.updateTime,
        pageCount: details.pageCount,
        targets: mergedTargets,
        status: existingTask.status == MangaDownloadTaskStatus.failed
            ? MangaDownloadTaskStatus.queued
            : existingTask.status,
        clearErrorMessage:
            existingTask.status == MangaDownloadTaskStatus.failed,
        retryCount: existingTask.status == MangaDownloadTaskStatus.failed
            ? 0
            : existingTask.retryCount,
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

    return MangaDownloadEnqueueResult.queued;
  }

  void restoreTasks(Iterable<MangaDownloadTask> tasks) {
    _tasks
      ..clear()
      ..addAll(tasks);
    final tasksByStorageKey = <String, MangaDownloadTask>{};
    for (final task in _tasks) {
      final existing = tasksByStorageKey[task.storageKey];
      if (existing == null) {
        tasksByStorageKey[task.storageKey] = task;
        continue;
      }

      final targetsByEpId = <String, MangaChapterDownloadTarget>{
        for (final target in existing.targets) target.epId: target,
        for (final target in task.targets) target.epId: target,
      };
      final targets = targetsByEpId.values.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      final latest = task.updatedAtMillis > existing.updatedAtMillis
          ? task
          : existing;
      tasksByStorageKey[task.storageKey] = latest.copyWith(
        targets: targets,
        completedEpIds: {...existing.completedEpIds, ...task.completedEpIds},
      );
    }
    _tasks
      ..clear()
      ..addAll(tasksByStorageKey.values)
      ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
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

  bool updateTask(String storageKey, MangaDownloadTask next) {
    final index = _tasks.indexWhere(
      (item) =>
          item.storageKey == storageKey || item.storageKey == next.storageKey,
    );
    if (index < 0) {
      return false;
    }
    final current = _tasks[index];
    // Progress or retry callbacks must not undo a user's pause while awaiting IO.
    if (current.status == MangaDownloadTaskStatus.paused) return false;
    final targetsByEpId = <String, MangaChapterDownloadTarget>{
      for (final target in next.targets) target.epId: target,
      for (final target in current.targets) target.epId: target,
    };
    final targets = targetsByEpId.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    _tasks[index] = next.copyWith(
      targets: targets,
      completedEpIds: {...current.completedEpIds, ...next.completedEpIds},
    );
    return true;
  }

  int _taskIndexForStorageKey(String storageKey) {
    return _tasks.indexWhere((task) => task.storageKey == storageKey);
  }

  MangaDownloadTask? removeTask(String storageKey) {
    final index = _tasks.indexWhere(
      (item) =>
          item.storageKey == storageKey ||
          (item.sourceKey.isEmpty && item.comicId == storageKey),
    );
    if (index < 0) {
      return null;
    }
    return _tasks.removeAt(index);
  }

  MangaDownloadTask? taskByStorageKey(String storageKey) {
    for (final item in _tasks) {
      if (item.storageKey == storageKey ||
          (item.sourceKey.isEmpty && item.comicId == storageKey)) {
        return item;
      }
    }
    return null;
  }

  bool shouldAbortTask(String storageKey) {
    final latest = taskByStorageKey(storageKey);
    if (latest == null) {
      return true;
    }
    return latest.status == MangaDownloadTaskStatus.paused;
  }

  void upsertDownloadedComic(DownloadedMangaComic comic) {
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

  static bool chapterMatchesTarget(
    DownloadedMangaChapter downloaded,
    MangaChapterDownloadTarget target,
  ) {
    if (downloaded.epId == target.epId) {
      return true;
    }
    return RegExp(r'^local_\d+$').hasMatch(downloaded.epId.trim()) &&
        downloaded.index == target.index;
  }

  void replaceDownloaded(Iterable<DownloadedMangaComic> comics) {
    final merged = _mergeLegacyJmAliases(comics);
    _downloaded
      ..clear()
      ..addAll(merged)
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
  }

  void removeDownloaded(Set<String> storageKeys) {
    _downloaded.removeWhere((comic) => storageKeys.contains(comic.storageKey));
  }

  bool pauseTask(String storageKey) {
    final index = _taskIndexForStorageKey(storageKey);
    if (index < 0) return false;
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.paused,
    );
    return true;
  }

  bool resumeTask(String storageKey) {
    final index = _taskIndexForStorageKey(storageKey);
    if (index < 0) return false;
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.queued,
      clearErrorMessage: true,
      retryCount: 0,
    );
    return true;
  }

  bool pauseAllTasks() {
    var changed = false;
    for (final task in tasks) {
      if (task.status != MangaDownloadTaskStatus.paused) {
        changed = pauseTask(task.storageKey) || changed;
      }
    }
    return changed;
  }

  bool resumeAllTasks() {
    var changed = false;
    for (final task in tasks) {
      if (task.status == MangaDownloadTaskStatus.paused ||
          task.status == MangaDownloadTaskStatus.failed) {
        changed = resumeTask(task.storageKey) || changed;
      }
    }
    return changed;
  }
}
