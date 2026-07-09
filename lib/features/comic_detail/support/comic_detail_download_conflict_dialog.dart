import 'package:flutter/material.dart';

import 'package:hazuki/shared/downloads/download_conflict_dialog.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

typedef ComicDetailDownloadedChapterAction = DownloadedChapterConflictAction;

Future<ComicDetailDownloadedChapterAction?>
showComicDetailSkipDownloadedChaptersDialog(
  BuildContext context, {
  required MangaDownloadConflict conflict,
  ThemeData? dialogTheme,
}) {
  return showSkipDownloadedChaptersDialog(
    context,
    key: const Key('comic-detail-skip-downloaded-dialog'),
    conflict: conflict,
    dialogTheme: dialogTheme,
  );
}

Future<bool> showComicDetailDownloadConflictDialog(
  BuildContext context, {
  required MangaDownloadConflict conflict,
  ThemeData? dialogTheme,
}) {
  return showDownloadConflictDialog(
    context,
    key: const Key('comic-detail-download-conflict-dialog'),
    conflict: conflict,
    dialogTheme: dialogTheme,
  );
}
