import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/widgets/widgets.dart';

Future<bool?> showDeleteSelectedHistoryDialog(
  BuildContext context, {
  required int selectedCount,
}) {
  final strings = AppLocalizations.of(context)!;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return AlertDialog(
        title: Text(strings.historyDeleteSelectedTitle),
        content: Text(strings.historyDeleteSelectedContent(selectedCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.commonConfirm),
          ),
        ],
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        ).value,
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}

Future<bool?> showClearHistoryDialog(BuildContext context) {
  final strings = AppLocalizations.of(context)!;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return AlertDialog(
        title: Text(strings.historyClearAllTitle),
        content: Text(strings.historyClearAllContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.commonConfirm),
          ),
        ],
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        ).value,
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}

Future<void> copyHistoryComicId(BuildContext context, String comicId) async {
  final strings = AppLocalizations.of(context)!;
  await Clipboard.setData(ClipboardData(text: comicId));
  if (!context.mounted) {
    return;
  }
  unawaited(showHazukiPrompt(context, strings.historyCopiedComicId));
}
