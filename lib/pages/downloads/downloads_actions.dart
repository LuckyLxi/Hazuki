import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/manga_download_service.dart';
import '../../widgets/widgets.dart';

Future<bool?> showDownloadsDeleteDialog(
  BuildContext context, {
  required String title,
  required String content,
}) {
  final strings = l10n(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.comicDetailDelete),
          ),
        ],
      );
    },
  );
}

Future<void> showDownloadsScanResultPrompt(
  BuildContext context,
  MangaDownloadedScanResult result,
) async {
  final strings = l10n(context);
  final message = !result.permissionGranted
      ? strings.downloadsScanPermissionDenied
      : result.recoveredComics > 0
      ? strings.downloadsScanCompleted(
          result.scannedDirectories,
          result.recoveredComics,
        )
      : strings.downloadsScanNoRecoverable;
  await showHazukiPrompt(context, message);
}

Future<void> showDownloadsScanErrorPrompt(
  BuildContext context,
  Object error,
) async {
  await showHazukiPrompt(context, l10n(context).downloadsScanFailed('$error'));
}
