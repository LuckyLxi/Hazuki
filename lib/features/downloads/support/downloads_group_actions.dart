import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import '../state/downloads_bulk_group_controller.dart';
import '../view/downloads_cover_widgets.dart';

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

class _DownloadsBulkGroupDialogState extends State<_DownloadsBulkGroupDialog> {
  late final DownloadsBulkGroupController _controller;

  DownloadsBulkDialogStage get _stage => _controller.stage;
  Set<String> get _selectedComicKeys => _controller.selectedComicKeys;
  Map<String, Set<String>> get _initialComicKeysByGroup =>
      _controller.initialComicKeysByGroup;
  Map<String, Set<String>> get _draftComicKeysByGroup =>
      _controller.draftComicKeysByGroup;

  @override
  void initState() {
    super.initState();
    _controller = DownloadsBulkGroupController(
      groups: widget.groups,
      selectedComics: widget.selectedComics,
      initialComicKeysByGroup: widget.initialComicKeysByGroup,
    )..addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choosingGroups = _stage == DownloadsBulkDialogStage.groups;
    final confirmingRemoval =
        _stage == DownloadsBulkDialogStage.removeConfirmation;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
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
                DownloadsBulkDialogStage.actions => _buildActionSelection(
                  context,
                ),
                DownloadsBulkDialogStage.groups => _buildGroupSelection(
                  context,
                ),
                DownloadsBulkDialogStage.removeConfirmation =>
                  _buildRemoveConfirmation(context),
              },
            ),
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
            onPressed: _controller.showGroups,
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(strings.downloadsMoveOrAddAction),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _controller.showRemoveConfirmation,
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
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.82,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: value == null
                            ? TextButton(
                                key: ValueKey<String>(
                                  'downloads_view_membership_${group.id}',
                                ),
                                onPressed: () =>
                                    _showGroupMembershipDetails(group),
                                child: Text(
                                  strings.downloadsViewGroupMembership,
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey<String>(
                                  'downloads_view_membership_hidden',
                                ),
                              ),
                      ),
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
                onPressed: _controller.showActions,
                child: Text(strings.downloadsBack),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    DownloadsBulkGroupSelection(
                      action: DownloadsBulkGroupAction.updateMemberships,
                      comicKeysByGroup: _controller.snapshotDraftMemberships(),
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
                onPressed: _controller.showActions,
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
    _controller.toggleGroup(groupId);
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
    _controller.updateGroupMembership(group.id, updated);
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
  static const Duration _coverDismissDuration = Duration(milliseconds: 240);

  late final Set<String> _joinedComicKeys = Set.of(widget.joinedComicKeys);
  final Map<String, bool> _dismissingComicTabs = {};
  bool _showJoined = false;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final visibleComics = widget.comics
        .where(
          (comic) =>
              _joinedComicKeys.contains(comic.storageKey) == _showJoined ||
              _dismissingComicTabs[comic.storageKey] == _showJoined,
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
            _DownloadsMembershipSlider(
              showJoined: _showJoined,
              notJoinedLabel: strings.downloadsNotJoined,
              joinedLabel: strings.downloadsJoined,
              onChanged: (value) => setState(() => _showJoined = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                key: const ValueKey<String>(
                  'downloads_membership_content_switcher',
                ),
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) {
                  final joined = (child.key as ValueKey<bool>).value;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(joined ? 0.08 : -0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<bool>(_showJoined),
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
                              joined: _joinedComicKeys.contains(
                                comic.storageKey,
                              ),
                              dismissing:
                                  _dismissingComicTabs[comic.storageKey] ==
                                  _showJoined,
                              onTap: () => _toggleMembership(comic),
                            );
                          },
                        ),
                ),
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

  void _toggleMembership(DownloadedMangaComic comic) {
    final storageKey = comic.storageKey;
    if (_dismissingComicTabs.containsKey(storageKey)) {
      return;
    }
    final joined = _joinedComicKeys.contains(storageKey);
    setState(() {
      _dismissingComicTabs[storageKey] = joined;
      if (joined) {
        _joinedComicKeys.remove(storageKey);
      } else {
        _joinedComicKeys.add(storageKey);
      }
    });
    Future<void>.delayed(_coverDismissDuration, () {
      if (!mounted) return;
      setState(() => _dismissingComicTabs.remove(storageKey));
    });
  }
}

class _DownloadsMembershipSlider extends StatelessWidget {
  const _DownloadsMembershipSlider({
    required this.showJoined,
    required this.notJoinedLabel,
    required this.joinedLabel,
    required this.onChanged,
  });

  final bool showJoined;
  final String notJoinedLabel;
  final String joinedLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('downloads_membership_slider'),
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            key: const ValueKey<String>('downloads_membership_slider_thumb'),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: showJoined
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _DownloadsMembershipSliderOption(
                  label: notJoinedLabel,
                  selected: !showJoined,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _DownloadsMembershipSliderOption(
                  label: joinedLabel,
                  selected: showJoined,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadsMembershipSliderOption extends StatelessWidget {
  const _DownloadsMembershipSliderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ) ??
                const TextStyle(),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _DownloadsMembershipComicCover extends StatelessWidget {
  const _DownloadsMembershipComicCover({
    required this.comic,
    required this.joined,
    required this.dismissing,
    required this.onTap,
  });

  final DownloadedMangaComic comic;
  final bool joined;
  final bool dismissing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      key: ValueKey<String>('downloads_membership_cover_${comic.storageKey}'),
      opacity: dismissing ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInCubic,
      child: AnimatedScale(
        scale: dismissing ? 0.78 : 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInBack,
        child: InkWell(
          onTap: dismissing ? null : onTap,
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
                    joined
                        ? Icons.remove_circle_rounded
                        : Icons.add_circle_rounded,
                    color: joined
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
