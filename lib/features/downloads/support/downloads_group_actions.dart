import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import '../view/downloads_cover_widgets.dart';

enum DownloadsComicMenuAction { updateGroups, delete }

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
  const height = 126.0;
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
                        icon: Icons.drive_file_move_outline,
                        label: strings.downloadsMoveOrAddAction,
                        onTap: () => Navigator.pop(
                          dialogContext,
                          DownloadsComicMenuAction.updateGroups,
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

class _DownloadsBulkGroupDialog extends StatefulWidget {
  const _DownloadsBulkGroupDialog({
    required this.groups,
    required this.selectedComics,
    required this.initialComicKeysByGroup,
    required this.currentGroupName,
  });

  final List<DownloadGroup> groups;
  final List<DownloadedMangaComic> selectedComics;
  final Map<String, Set<String>> initialComicKeysByGroup;
  final String currentGroupName;

  @override
  State<_DownloadsBulkGroupDialog> createState() =>
      _DownloadsBulkGroupDialogState();
}

enum _DownloadsBulkDialogStage { actions, groups, removeConfirmation }

class _DownloadsBulkGroupDialogState extends State<_DownloadsBulkGroupDialog> {
  _DownloadsBulkDialogStage _stage = _DownloadsBulkDialogStage.actions;
  late final Set<String> _selectedComicKeys = {
    for (final comic in widget.selectedComics) comic.storageKey,
  };
  late final Map<String, Set<String>> _initialComicKeysByGroup = {
    for (final group in widget.groups)
      group.id: Set<String>.of(
        widget.initialComicKeysByGroup[group.id] ?? const {},
      ),
  };
  late final Map<String, Set<String>> _draftComicKeysByGroup = {
    for (final entry in _initialComicKeysByGroup.entries)
      entry.key: Set<String>.of(entry.value),
  };

  @override
  Widget build(BuildContext context) {
    final choosingGroups = _stage == _DownloadsBulkDialogStage.groups;
    final confirmingRemoval =
        _stage == _DownloadsBulkDialogStage.removeConfirmation;
    return Center(
      child: AnimatedContainer(
        key: const ValueKey<String>('downloads_bulk_group_dialog'),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: choosingGroups ? 420 : (confirmingRemoval ? 340 : 280),
        height: choosingGroups ? 500 : (confirmingRemoval ? 220 : 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(confirmingRemoval ? 48 : 28),
          border: Border.all(
            color: confirmingRemoval
                ? Theme.of(context).colorScheme.error
                : Colors.transparent,
            width: confirmingRemoval ? 2 : 0,
          ),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          elevation: confirmingRemoval ? 12 : 8,
          borderRadius: BorderRadius.circular(confirmingRemoval ? 48 : 28),
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
            child: switch (_stage) {
              _DownloadsBulkDialogStage.actions => _buildActionSelection(
                context,
              ),
              _DownloadsBulkDialogStage.groups => _buildGroupSelection(context),
              _DownloadsBulkDialogStage.removeConfirmation =>
                _buildRemoveConfirmation(context),
            },
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
                setState(() => _stage = _DownloadsBulkDialogStage.groups),
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(strings.downloadsMoveOrAddAction),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => setState(
              () => _stage = _DownloadsBulkDialogStage.removeConfirmation,
            ),
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(strings.downloadsRemoveFromCurrentGroup),
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
                final initial =
                    _initialComicKeysByGroup[group.id] ?? const <String>{};
                final draft =
                    _draftComicKeysByGroup[group.id] ?? const <String>{};
                final initialAll =
                    initial.length == _selectedComicKeys.length &&
                    _selectedComicKeys.isNotEmpty;
                final value = draft.isEmpty
                    ? false
                    : draft.length == _selectedComicKeys.length
                    ? true
                    : null;
                return Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        tristate: true,
                        contentPadding: EdgeInsets.zero,
                        value: value,
                        title: Text(
                          group.isDefault
                              ? strings.downloadsDefaultGroup
                              : group.name,
                        ),
                        onChanged: initialAll
                            ? null
                            : (_) => _toggleGroup(group.id),
                      ),
                    ),
                    if (value == null)
                      TextButton(
                        onPressed: () => _showGroupMembershipDetails(group),
                        child: Text(strings.downloadsViewGroupMembership),
                      ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    setState(() => _stage = _DownloadsBulkDialogStage.actions),
                child: Text(strings.downloadsBack),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    DownloadsBulkGroupSelection(
                      action: DownloadsBulkGroupAction.updateMemberships,
                      comicKeysByGroup: {
                        for (final entry in _draftComicKeysByGroup.entries)
                          entry.key: Set<String>.of(entry.value),
                      },
                    ),
                  );
                },
                child: Text(strings.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveConfirmation(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      key: const ValueKey<String>('downloads_bulk_remove_confirmation_stage'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.downloadsConfirmRemoveFromGroup(widget.currentGroupName),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    setState(() => _stage = _DownloadsBulkDialogStage.actions),
                child: Text(strings.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  const DownloadsBulkGroupSelection(
                    action: DownloadsBulkGroupAction.removeFromCurrentGroup,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(strings.commonConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleGroup(String groupId) {
    final initial = _initialComicKeysByGroup[groupId] ?? const <String>{};
    final draft = _draftComicKeysByGroup[groupId] ?? const <String>{};
    setState(() {
      _draftComicKeysByGroup[groupId] =
          draft.length == _selectedComicKeys.length
          ? Set<String>.of(initial)
          : Set<String>.of(_selectedComicKeys);
    });
  }

  Future<void> _showGroupMembershipDetails(DownloadGroup group) async {
    final updated = await showGeneralDialog<Set<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n(context).commonClose,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              key: const ValueKey<String>(
                'downloads_group_membership_details_transition',
              ),
              scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => Center(
        child: _DownloadsGroupMembershipDetailsDialog(
          group: group,
          comics: widget.selectedComics,
          joinedComicKeys: Set<String>.of(
            _draftComicKeysByGroup[group.id] ?? const {},
          ),
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _draftComicKeysByGroup[group.id] = updated);
  }
}

class _DownloadsGroupMembershipDetailsDialog extends StatefulWidget {
  const _DownloadsGroupMembershipDetailsDialog({
    required this.group,
    required this.comics,
    required this.joinedComicKeys,
  });

  final DownloadGroup group;
  final List<DownloadedMangaComic> comics;
  final Set<String> joinedComicKeys;

  @override
  State<_DownloadsGroupMembershipDetailsDialog> createState() =>
      _DownloadsGroupMembershipDetailsDialogState();
}

class _DownloadsGroupMembershipDetailsDialogState
    extends State<_DownloadsGroupMembershipDetailsDialog> {
  late final Set<String> _joinedComicKeys = Set.of(widget.joinedComicKeys);
  bool _showJoined = false;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final visibleComics = widget.comics
        .where(
          (comic) => _joinedComicKeys.contains(comic.storageKey) == _showJoined,
        )
        .toList(growable: false);
    return AlertDialog(
      key: const ValueKey<String>('downloads_group_membership_details_dialog'),
      title: Text(
        widget.group.isDefault
            ? strings.downloadsDefaultGroup
            : widget.group.name,
      ),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(strings.downloadsNotJoined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(strings.downloadsJoined),
                ),
              ],
              selected: {_showJoined},
              onSelectionChanged: (value) {
                setState(() => _showJoined = value.single);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: visibleComics.isEmpty
                  ? Center(child: Text(strings.downloadsNoMatchingComics))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 96,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: visibleComics.length,
                      itemBuilder: (context, index) {
                        final comic = visibleComics[index];
                        return _DownloadsMembershipComicCover(
                          comic: comic,
                          joined: _joinedComicKeys.contains(comic.storageKey),
                          onTap: () {
                            setState(() {
                              if (_joinedComicKeys.contains(comic.storageKey)) {
                                _joinedComicKeys.remove(comic.storageKey);
                              } else {
                                _joinedComicKeys.add(comic.storageKey);
                              }
                            });
                          },
                        );
                      },
                    ),
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
          onPressed: () => Navigator.pop(context, Set.of(_joinedComicKeys)),
          child: Text(strings.commonSave),
        ),
      ],
    );
  }
}

class _DownloadsMembershipComicCover extends StatelessWidget {
  const _DownloadsMembershipComicCover({
    required this.comic,
    required this.joined,
    required this.onTap,
  });

  final DownloadedMangaComic comic;
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DownloadedComicCover(comic: comic, borderRadius: 10),
          Positioned(
            top: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.88),
                shape: BoxShape.circle,
              ),
              child: Icon(
                joined ? Icons.remove_circle_rounded : Icons.add_circle_rounded,
                color: joined
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
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
  });

  final List<DownloadGroup> groups;
  final Set<String> initiallySelectedGroupIds;

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
          child: Text(strings.downloadsMoveOrAddAction),
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
