import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

enum DownloadedChapterConflictAction { skip, continueToRedownload }

Future<DownloadedChapterConflictAction?> showSkipDownloadedChaptersDialog(
  BuildContext context, {
  required MangaDownloadConflict conflict,
  ThemeData? dialogTheme,
  Key key = const Key('skip-downloaded-dialog'),
}) {
  final strings = l10n(context);
  return _showAnimatedDownloadConflictDialog<DownloadedChapterConflictAction>(
    context,
    dialogTheme: dialogTheme,
    key: key,
    title: strings.downloadsSkipDownloadedDialogTitle,
    content: strings.downloadsSkipDownloadedDialogContent(
      conflict.existingChapters.length,
    ),
    secondaryActionLabel: strings.downloadsDoNotSkipAction,
    onSecondaryAction: (dialogContext) => Navigator.of(
      dialogContext,
    ).pop(DownloadedChapterConflictAction.continueToRedownload),
    primaryActionLabel: strings.downloadsSkipDownloadedAction,
    onPrimaryAction: (dialogContext) =>
        Navigator.of(dialogContext).pop(DownloadedChapterConflictAction.skip),
  );
}

Future<bool> showDownloadConflictDialog(
  BuildContext context, {
  required MangaDownloadConflict conflict,
  ThemeData? dialogTheme,
  Key key = const Key('download-conflict-dialog'),
}) async {
  final strings = l10n(context);
  final chapterTitles = conflict.existingChapters
      .take(5)
      .map((chapter) => chapter.title)
      .join('\n');
  final hasMore = conflict.existingChapters.length > 5;
  final result = await _showAnimatedDownloadConflictDialog<bool>(
    context,
    dialogTheme: dialogTheme,
    key: key,
    title: strings.downloadsDuplicateDialogTitle,
    content: strings.downloadsDuplicateDialogContent(
      conflict.comicTitle,
      conflict.existingChapters.length,
      '$chapterTitles${hasMore ? '\n...' : ''}',
    ),
    secondaryActionLabel: strings.commonCancel,
    onSecondaryAction: (dialogContext) =>
        Navigator.of(dialogContext).pop(false),
    primaryActionLabel: strings.downloadsDuplicateDownloadAction,
    onPrimaryAction: (dialogContext) => Navigator.of(dialogContext).pop(true),
  );
  return result ?? false;
}

Future<T?> _showAnimatedDownloadConflictDialog<T>(
  BuildContext context, {
  ThemeData? dialogTheme,
  required Key key,
  required String title,
  required String content,
  required String secondaryActionLabel,
  required ValueChanged<BuildContext> onSecondaryAction,
  required String primaryActionLabel,
  required ValueChanged<BuildContext> onPrimaryAction,
}) {
  final strings = l10n(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.dialogBarrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Theme(
      data: dialogTheme ?? Theme.of(dialogContext),
      child: AlertDialog(
        key: key,
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => onSecondaryAction(dialogContext),
            child: Text(secondaryActionLabel),
          ),
          FilledButton(
            onPressed: () => onPrimaryAction(dialogContext),
            child: Text(primaryActionLabel),
          ),
        ],
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
          child: child,
        ),
      );
    },
  );
}
