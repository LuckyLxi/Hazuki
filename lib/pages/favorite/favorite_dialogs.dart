import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations _strings(BuildContext context) => AppLocalizations.of(context)!;

Future<String?> showFavoriteCreateFolderDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      String? errorText;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final strings = _strings(dialogContext);
          return AlertDialog(
            title: Text(strings.favoriteCreateFolderTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.favoriteCreateFolderHint,
                border: const OutlineInputBorder(),
                errorText: errorText,
              ),
              onChanged: (_) {
                if (errorText != null) {
                  setDialogState(() => errorText = null);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setDialogState(
                      () => errorText = strings.favoriteCreateFolderNameRequired,
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, text);
                },
                child: Text(strings.commonConfirm),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showFavoriteDeleteFolderDialog(
  BuildContext context, {
  required String folderName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final strings = _strings(dialogContext);
      return AlertDialog(
        title: Text(strings.favoriteDeleteFolderTitle),
        content: Text(strings.favoriteDeleteFolderContent(folderName)),
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

  return confirmed ?? false;
}
