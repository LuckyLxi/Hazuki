import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/download_groups/download_group.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';
import '../state/downloads_bulk_group_controller.dart';
import '../view/downloads_cover_widgets.dart';

part 'downloads_bulk_group_dialog.dart';
part 'downloads_group_membership_dialog.dart';
part 'downloads_group_picker_dialog.dart';

enum DownloadsComicMenuAction { updateGroups, removeFromCurrentGroup, delete }

enum DownloadsBulkGroupAction { updateMemberships, removeFromCurrentGroup }

class DownloadsBulkGroupSelection {
  const DownloadsBulkGroupSelection({
    required this.action,
    this.comicKeysByGroup = const {},
  });

  final DownloadsBulkGroupAction action;
  final Map<String, Set<String>> comicKeysByGroup;
}

Future<DownloadsComicMenuAction?> showDownloadsComicMenu({
  required BuildContext context,
  required BuildContext itemContext,
  required Offset globalPosition,
}) async {
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  final cardBox = itemContext.findRenderObject() as RenderBox?;
  if (overlay == null || cardBox == null) return null;

  const width = 212.0;
  const height = 169.0;
  const gap = 8.0;
  final padding = MediaQuery.paddingOf(context);
  final finger = overlay.globalToLocal(globalPosition);
  final cardTop = cardBox.localToGlobal(Offset.zero, ancestor: overlay).dy;
  final cardBottom = cardTop + cardBox.size.height;
  final left = (finger.dx - width / 2).clamp(
    8.0,
    overlay.size.width - width - 8,
  );
  final showBelow =
      cardBottom + gap + height <= overlay.size.height - padding.bottom - 8;
  final top = showBelow
      ? (cardBottom + gap).clamp(
          8 + padding.top,
          overlay.size.height - height - 8,
        )
      : (cardTop - gap - height).clamp(
          8 + padding.top,
          overlay.size.height - height - 8,
        );
  final upwardBottom = overlay.size.height - cardTop + gap;
  final strings = l10n(context);

  return showGeneralDialog<DownloadsComicMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          alignment: Alignment(
            ((finger.dx - left) / width * 2 - 1).clamp(-1, 1),
            showBelow ? -1 : 1,
          ),
          scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final scheme = Theme.of(context).colorScheme;
      return Stack(
        children: [
          Positioned(
            left: left,
            top: showBelow ? top : null,
            bottom: showBelow ? null : upwardBottom,
            width: width,
            child: ClipRRect(
              key: const ValueKey<String>('downloads_comic_long_press_menu'),
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Material(
                  // 跟随全局弹窗底色，未配置时回退 M3 默认值。
                  color:
                      (DialogTheme.of(context).backgroundColor ??
                              scheme.surfaceContainerHigh)
                          .withValues(alpha: 0.78),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuItem(
                        icon: Icons.drive_file_move_outline,
                        label: strings.downloadsMoveOrAddAction,
                        onTap: () => Navigator.pop(
                          dialogContext,
                          DownloadsComicMenuAction.updateGroups,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      _MenuItem(
                        icon: Icons.remove_circle_outline_rounded,
                        label: strings.downloadsRemoveFromCurrentGroup,
                        onTap: () => Navigator.pop(
                          dialogContext,
                          DownloadsComicMenuAction.removeFromCurrentGroup,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      _MenuItem(
                        icon: Icons.delete_outline,
                        label: strings.comicDetailDelete,
                        danger: true,
                        onTap: () => Navigator.pop(
                          dialogContext,
                          DownloadsComicMenuAction.delete,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Future<Set<String>?> showDownloadGroupPicker({
  required BuildContext context,
  required List<DownloadGroup> groups,
  required Set<String> initiallySelectedGroupIds,
}) {
  return showGeneralDialog<Set<String>>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n(context).commonClose,
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
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
      return _DownloadGroupPickerDialog(
        groups: groups,
        initiallySelectedGroupIds: initiallySelectedGroupIds,
      );
    },
  );
}

Future<DownloadsBulkGroupSelection?> showDownloadsBulkGroupDialog({
  required BuildContext context,
  required List<DownloadGroup> groups,
  required List<DownloadedMangaComic> selectedComics,
  required Map<String, Set<String>> initialComicKeysByGroup,
  required String currentGroupName,
}) {
  return showGeneralDialog<DownloadsBulkGroupSelection>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n(context).commonClose,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _DownloadsBulkGroupDialog(
          groups: groups,
          selectedComics: selectedComics,
          initialComicKeysByGroup: initialComicKeysByGroup,
          currentGroupName: currentGroupName,
        ),
  );
}
