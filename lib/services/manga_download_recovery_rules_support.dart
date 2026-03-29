import 'dart:io';

import 'manga_download_models.dart';

class MangaDownloadRecoveryRules {
  MangaDownloadRecoveryRules({
    required MangaDownloadTask? Function(String comicId) taskByComicId,
    required Directory Function(
      Directory comicDir,
      MangaChapterDownloadTarget target,
    )
    chapterDirForTarget,
  }) : _taskByComicId = taskByComicId,
       _chapterDirForTarget = chapterDirForTarget;

  final MangaDownloadTask? Function(String comicId) _taskByComicId;
  final Directory Function(
    Directory comicDir,
    MangaChapterDownloadTarget target,
  )
  _chapterDirForTarget;

  DownloadedMangaComic? sanitizeDownloadedComicState(
    DownloadedMangaComic comic,
  ) {
    final task = _taskByComicId(comic.comicId);
    final filteredChapters = comic.chapters
        .where(
          (chapter) =>
              !_shouldIgnoreRecoveredChapterForIncompleteTask(chapter, task),
        )
        .toList();
    final mergedChapters = mergeRecoveredChapters(
      normalizedChapters: filteredChapters,
      scannedChapters: const <DownloadedMangaChapter>[],
    );
    if (mergedChapters.isEmpty) {
      return null;
    }
    return comic.copyWith(
      chapters: mergedChapters,
      updatedAtMillis: comic.updatedAtMillis,
    );
  }

  List<DownloadedMangaChapter> mergeRecoveredChapters({
    required List<DownloadedMangaChapter> normalizedChapters,
    required List<DownloadedMangaChapter> scannedChapters,
  }) {
    if (normalizedChapters.isEmpty && scannedChapters.isEmpty) {
      return const <DownloadedMangaChapter>[];
    }

    final scannedByIndex = <int, DownloadedMangaChapter>{
      for (final chapter in scannedChapters) chapter.index: chapter,
    };
    final mergedByIndex = <int, DownloadedMangaChapter>{};

    for (final chapter in normalizedChapters) {
      final sanitized = _sanitizeRecoveredChapter(
        chapter,
        fallback: scannedByIndex[chapter.index],
      );
      mergedByIndex[sanitized.index] = _preferRecoveredChapter(
        mergedByIndex[sanitized.index],
        sanitized,
      );
    }
    for (final chapter in scannedChapters) {
      final sanitized = _sanitizeRecoveredChapter(chapter);
      mergedByIndex[sanitized.index] = _preferRecoveredChapter(
        mergedByIndex[sanitized.index],
        sanitized,
      );
    }

    final merged = mergedByIndex.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return merged;
  }

  DownloadedMangaComic sanitizeRecoveredComic({
    required String comicId,
    required DownloadedMangaComic comic,
    required String? localCoverPath,
    required List<DownloadedMangaChapter> chapters,
    required int updatedAtMillis,
  }) {
    final normalizedComicId = comic.comicId.trim().isNotEmpty
        ? comic.comicId.trim()
        : comicId;
    return DownloadedMangaComic(
      comicId: normalizedComicId,
      title: _normalizeRecoveredComicTitle(comic.title, normalizedComicId),
      subTitle: comic.subTitle.trim(),
      description: comic.description.trim(),
      coverUrl: comic.coverUrl.trim(),
      localCoverPath: localCoverPath,
      chapters: chapters,
      updatedAtMillis: updatedAtMillis,
    );
  }

  Set<String> blockedChapterDirectoryPathsForTask(Directory comicDir) {
    final task = _taskByComicId(_baseNameFromPath(comicDir.path));
    if (task == null) {
      return const <String>{};
    }
    final blocked = <String>{};
    for (final target in task.targets) {
      if (task.completedEpIds.contains(target.epId)) {
        continue;
      }
      blocked.add(_chapterDirForTarget(comicDir, target).path);
    }
    return blocked;
  }

  String _normalizeRecoveredComicTitle(String rawTitle, String comicId) {
    final normalized = rawTitle.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return comicId;
  }

  DownloadedMangaChapter _sanitizeRecoveredChapter(
    DownloadedMangaChapter chapter, {
    DownloadedMangaChapter? fallback,
  }) {
    final normalizedIndex = chapter.index < 0 ? 0 : chapter.index;
    final chapterNumber = normalizedIndex + 1;
    final fallbackEpId = fallback?.epId.trim() ?? '';
    final normalizedEpId = chapter.epId.trim().isNotEmpty
        ? chapter.epId.trim()
        : (fallbackEpId.isNotEmpty ? fallbackEpId : 'local_$chapterNumber');
    return DownloadedMangaChapter(
      epId: normalizedEpId,
      title: _normalizeRecoveredChapterTitle(
        chapter.title,
        chapterNumber: chapterNumber,
        fallbackTitle: fallback?.title,
      ),
      index: normalizedIndex,
      imagePaths: chapter.imagePaths.isNotEmpty
          ? chapter.imagePaths
          : (fallback?.imagePaths ?? const <String>[]),
    );
  }

  bool _isLocalRecoveredEpId(String epId) {
    return RegExp(r'^local_\d+$').hasMatch(epId.trim());
  }

  DownloadedMangaChapter _preferRecoveredChapter(
    DownloadedMangaChapter? current,
    DownloadedMangaChapter candidate,
  ) {
    if (current == null) {
      return candidate;
    }
    final currentIsLocal = _isLocalRecoveredEpId(current.epId);
    final candidateIsLocal = _isLocalRecoveredEpId(candidate.epId);
    if (currentIsLocal != candidateIsLocal) {
      return candidateIsLocal ? current : candidate;
    }
    if (candidate.imagePaths.length != current.imagePaths.length) {
      return candidate.imagePaths.length > current.imagePaths.length
          ? candidate
          : current;
    }
    final currentHasValidTitle = !_isInvalidRecoveredChapterTitle(
      current.title,
    );
    final candidateHasValidTitle = !_isInvalidRecoveredChapterTitle(
      candidate.title,
    );
    if (currentHasValidTitle != candidateHasValidTitle) {
      return candidateHasValidTitle ? candidate : current;
    }
    return current;
  }

  String _normalizeRecoveredChapterTitle(
    String rawTitle, {
    required int chapterNumber,
    String? fallbackTitle,
  }) {
    final normalized = rawTitle.trim();
    if (!_isInvalidRecoveredChapterTitle(normalized)) {
      return normalized;
    }
    final normalizedFallback = fallbackTitle?.trim() ?? '';
    if (!_isInvalidRecoveredChapterTitle(normalizedFallback)) {
      return normalizedFallback;
    }
    return 'Chapter $chapterNumber';
  }

  bool _isInvalidRecoveredChapterTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return true;
    }
    return <RegExp>[
      RegExp(r'^chapter\s*0*\d+$', caseSensitive: false),
      RegExp(r'^manga\s*0*\d+$', caseSensitive: false),
      RegExp(r'^0*\d+$'),
    ].any((pattern) => pattern.hasMatch(normalized));
  }

  bool _shouldIgnoreRecoveredChapterForIncompleteTask(
    DownloadedMangaChapter chapter,
    MangaDownloadTask? task,
  ) {
    if (task == null || !_isLocalRecoveredEpId(chapter.epId)) {
      return false;
    }
    for (final target in task.targets) {
      if (task.completedEpIds.contains(target.epId)) {
        continue;
      }
      if (target.index == chapter.index) {
        return true;
      }
    }
    return false;
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
