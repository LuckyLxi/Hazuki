import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/download_groups_service.dart';

enum DownloadsComicMenuAction { add, move, delete }

class DownloadsBulkGroupSelection {
  const DownloadsBulkGroupSelection({
    required this.action,
    required this.groupIds,
  });

  final DownloadsComicMenuAction action;
  final Set<String> groupIds;
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
  const height = 174.0;
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
                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.78),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuItem(
                        icon: Icons.playlist_add_rounded,
                        label: strings.downloadsAddToGroup,
                        onTap: () => Navigator.pop(
                          dialogContext,
                          DownloadsComicMenuAction.add,
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.drive_file_move_outline,
                        label: strings.downloadsMoveToGroup,
                        onTap: () => Navigator.pop(
                          dialogContext,
                          DownloadsComicMenuAction.move,
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
  required DownloadsComicMenuAction action,
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
        action: action,
      );
    },
  );
}

Future<DownloadsBulkGroupSelection?> showDownloadsBulkGroupDialog({
  required BuildContext context,
  required List<DownloadGroup> groups,
  required Set<String> initiallySelectedGroupIds,
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
          initiallySelectedGroupIds: initiallySelectedGroupIds,
        ),
  );
}

class _DownloadsBulkGroupDialog extends StatefulWidget {
  const _DownloadsBulkGroupDialog({
    required this.groups,
    required this.initiallySelectedGroupIds,
  });

  final List<DownloadGroup> groups;
  final Set<String> initiallySelectedGroupIds;

  @override
  State<_DownloadsBulkGroupDialog> createState() =>
      _DownloadsBulkGroupDialogState();
}

class _DownloadsBulkGroupDialogState extends State<_DownloadsBulkGroupDialog> {
  DownloadsComicMenuAction? _action;
  late final Set<String> _selected = {...widget.initiallySelectedGroupIds};
  bool _showSelectionRequired = false;

  @override
  Widget build(BuildContext context) {
    final choosingGroups = _action != null;
    return Center(
      child: AnimatedContainer(
        key: const ValueKey<String>('downloads_bulk_group_dialog'),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: choosingGroups ? 380 : 260,
        height: choosingGroups ? 430 : 250,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          elevation: 8,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) =>
                currentChild ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: choosingGroups
                ? _buildGroupSelection(context)
                : _buildActionSelection(context),
          ),
        ),
      ),
    );
  }

  Widget _buildActionSelection(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      key: const ValueKey<String>('downloads_bulk_action_stage'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.downloadsBatchGroupAction,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () =>
                setState(() => _action = DownloadsComicMenuAction.add),
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(strings.downloadsAddAction),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () =>
                setState(() => _action = DownloadsComicMenuAction.move),
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(strings.downloadsMoveAction),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildGroupSelection(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      key: const ValueKey<String>('downloads_bulk_group_stage'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.downloadsChooseGroup,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.groups.length,
              itemBuilder: (context, index) {
                final group = widget.groups[index];
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(group.id),
                  title: Text(
                    group.isDefault
                        ? strings.downloadsDefaultGroup
                        : group.name,
                  ),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selected.add(group.id);
                      } else {
                        _selected.remove(group.id);
                      }
                      if (_selected.isNotEmpty) {
                        _showSelectionRequired = false;
                      }
                    });
                  },
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _showSelectionRequired && _selected.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      strings.downloadsSelectAtLeastOneGroup,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _action = null),
                child: Text(strings.downloadsBack),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  if (_selected.isEmpty) {
                    setState(() => _showSelectionRequired = true);
                    return;
                  }
                  Navigator.pop(
                    context,
                    DownloadsBulkGroupSelection(
                      action: _action!,
                      groupIds: Set.of(_selected),
                    ),
                  );
                },
                child: Text(
                  _action == DownloadsComicMenuAction.add
                      ? strings.downloadsAddAction
                      : strings.downloadsMoveAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadGroupPickerDialog extends StatefulWidget {
  const _DownloadGroupPickerDialog({
    required this.groups,
    required this.initiallySelectedGroupIds,
    required this.action,
  });

  final List<DownloadGroup> groups;
  final Set<String> initiallySelectedGroupIds;
  final DownloadsComicMenuAction action;

  @override
  State<_DownloadGroupPickerDialog> createState() =>
      _DownloadGroupPickerDialogState();
}

class _DownloadGroupPickerDialogState
    extends State<_DownloadGroupPickerDialog> {
  late final Set<String> _selected = {...widget.initiallySelectedGroupIds};
  bool _showSelectionRequired = false;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      title: Text(strings.downloadsChooseGroup),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: widget.groups.length,
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    final selected = _selected.contains(group.id);
                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      value: selected,
                      secondary: const Icon(Icons.folder_outlined),
                      title: Text(
                        group.isDefault
                            ? strings.downloadsDefaultGroup
                            : group.name,
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(group.id);
                          } else {
                            _selected.remove(group.id);
                          }
                          if (_selected.isNotEmpty) {
                            _showSelectionRequired = false;
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _showSelectionRequired && _selected.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        strings.downloadsSelectAtLeastOneGroup,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_selected.isEmpty) {
              setState(() => _showSelectionRequired = true);
              return;
            }
            Navigator.pop(context, Set<String>.of(_selected));
          },
          child: Text(
            widget.action == DownloadsComicMenuAction.add
                ? strings.downloadsAddAction
                : strings.downloadsMoveAction,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
