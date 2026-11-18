import '../../models/hazuki_models.dart';
import '../../services/manga_download/manga_download_commands.dart';

enum DownloadedChapterConflictAction { skip, continueToRedownload }

/// Submits selected chapters while the caller can still handle the result.
Future<({MangaDownloadEnqueueResult result, int chapterCount})?>
enqueueChapterDownloads({
  required MangaDownloadCommands downloader,
  required ComicDetailsData details,
  required List<MangaChapterDownloadTarget> targets,
  required String coverUrl,
  required bool Function() isActive,
  required Future<DownloadedChapterConflictAction?> Function(
    MangaDownloadConflict conflict,
  )
  chooseDownloadedAction,
  required Future<bool> Function(MangaDownloadConflict conflict)
  confirmRedownload,
}) async {
  if (targets.isEmpty || !isActive()) return null;

  final taskConflict = await downloader.checkDownloadTaskConflict(
    details: details,
    chapters: targets,
  );
  if (!isActive()) return null;
  var queuedTargets = _excludeExisting(targets, taskConflict);
  if (queuedTargets.isEmpty) {
    return (result: MangaDownloadEnqueueResult.alreadyQueued, chapterCount: 0);
  }

  final conflictTargets = queuedTargets;
  final conflict = await downloader.checkDownloadConflict(
    details: details,
    chapters: conflictTargets,
  );
  if (!isActive()) return null;
  var redownloadExisting = false;
  if (conflict.hasConflict) {
    if (conflict.existingChapters.length < conflictTargets.length) {
      final action = await chooseDownloadedAction(conflict);
      if (action == null || !isActive()) return null;
      if (action == DownloadedChapterConflictAction.skip) {
        queuedTargets = _excludeExisting(conflictTargets, conflict);
      }
    }
    if (queuedTargets.length == conflictTargets.length) {
      redownloadExisting = await confirmRedownload(conflict);
      if (!redownloadExisting || !isActive()) return null;
    }
  }

  final result = await downloader.enqueueDownload(
    details: details,
    coverUrl: coverUrl,
    description: details.description,
    chapters: queuedTargets,
    redownloadExisting: redownloadExisting,
  );
  if (!isActive()) return null;
  return (result: result, chapterCount: queuedTargets.length);
}

List<MangaChapterDownloadTarget> _excludeExisting(
  List<MangaChapterDownloadTarget> targets,
  MangaDownloadConflict conflict,
) {
  if (!conflict.hasConflict) return targets;
  final existingIds = conflict.existingChapters
      .map((item) => item.epId)
      .toSet();
  return targets
      .where((item) => !existingIds.contains(item.epId))
      .toList(growable: false);
}
