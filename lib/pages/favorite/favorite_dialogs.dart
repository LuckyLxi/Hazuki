import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations _strings(BuildContext context) =>
    AppLocalizations.of(context)!;

Future<T?> _showAnimatedFolderDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return builder(dialogContext);
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = Tween<double>(begin: 0.92, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        ),
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

Future<String?> showFavoriteCreateFolderDialog(BuildContext context) {
  final controller = TextEditingController();
  return _showAnimatedFolderDialog<String>(
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
                      () =>
                          errorText = strings.favoriteCreateFolderNameRequired,
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

Future<String?> showFavoriteRenameFolderDialog(
  BuildContext context, {
  required String initialName,
}) {
  final controller = TextEditingController(
    text: initialName,
  );
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
  return _showAnimatedFolderDialog<String>(
    context: context,
    builder: (dialogContext) {
      String? errorText;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final strings = _strings(dialogContext);
          return AlertDialog(
            title: Text(strings.favoriteRenameFolderTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: strings.favoriteRenameFolderHint,
                border: const OutlineInputBorder(),
                errorText: errorText,
              ),
              onChanged: (_) {
                if (errorText != null) {
                  setDialogState(() => errorText = null);
                }
              },
              onSubmitted: (_) {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setDialogState(
                    () =>
                        errorText = strings.favoriteCreateFolderNameRequired,
                  );
                  return;
                }
                Navigator.pop(dialogContext, text);
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
                      () =>
                          errorText = strings.favoriteCreateFolderNameRequired,
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
  final confirmed = await _showAnimatedFolderDialog<bool>(
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
