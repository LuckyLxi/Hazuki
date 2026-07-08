import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'downloads_cover_widgets.dart';
import 'downloads_completed_status_widgets.dart';
import 'downloads_shell_widgets.dart';
import '../state/downloads_completed_list_controller.dart';

@immutable
class DownloadsCompletedTabModel {
  const DownloadsCompletedTabModel({
    required this.comics,
    required this.active,
    required this.selectionMode,
    required this.scanning,
    required this.selectedCount,
    required this.selectedComicIds,
    required this.comicsWithIntegrityIssues,
    required this.groups,
    required this.selectedGroupId,
    required this.selectedGroupName,
    required this.selectedGroupComicCount,
    required this.groupComicCounts,
  });

  final List<DownloadedMangaComic> comics;
  final bool active;
  final bool selectionMode;
  final bool scanning;
  final int selectedCount;
  final Set<String> selectedComicIds;
  final Set<String> comicsWithIntegrityIssues;
  final List<DownloadGroup> groups;
  final String selectedGroupId;
  final String selectedGroupName;
  final int selectedGroupComicCount;
  final Map<String, int> groupComicCounts;
}

@immutable
class DownloadsCompletedTabActions {
  const DownloadsCompletedTabActions({
    required this.onToggleSelection,
    required this.onDeleteSelected,
    required this.onScanDownloaded,
    required this.onOpenComic,
    required this.onDeleteComic,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onReorderGroups,
    required this.onDeleteGroup,
    required this.onShowComicMenu,
    required this.onBatchGroup,
  });

  final ValueChanged<String> onToggleSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;
  final ValueChanged<String> onSelectGroup;
  final Future<DownloadGroup> Function(String name) onCreateGroup;
  final Future<DownloadGroup> Function(String groupId, String name)
  onRenameGroup;
  final Future<void> Function(List<String> orderedGroupIds) onReorderGroups;
  final Future<void> Function(String groupId) onDeleteGroup;
  final Future<void> Function(
    DownloadedMangaComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  onShowComicMenu;
  final VoidCallback onBatchGroup;
}

class DownloadsCompletedTab extends StatefulWidget {
  const DownloadsCompletedTab({
    super.key,
    required this.model,
    required this.actions,
  });

  final DownloadsCompletedTabModel model;
  final DownloadsCompletedTabActions actions;

  List<DownloadedMangaComic> get comics => model.comics;
  bool get active => model.active;
  bool get selectionMode => model.selectionMode;
  bool get scanning => model.scanning;
  int get selectedCount => model.selectedCount;
  Set<String> get selectedComicIds => model.selectedComicIds;
  Set<String> get comicsWithIntegrityIssues => model.comicsWithIntegrityIssues;
  List<DownloadGroup> get groups => model.groups;
  String get selectedGroupId => model.selectedGroupId;
  String get selectedGroupName => model.selectedGroupName;
  int get selectedGroupComicCount => model.selectedGroupComicCount;
  Map<String, int> get groupComicCounts => model.groupComicCounts;
  ValueChanged<String> get onToggleSelection => actions.onToggleSelection;
  VoidCallback get onDeleteSelected => actions.onDeleteSelected;
  VoidCallback get onScanDownloaded => actions.onScanDownloaded;
  ValueChanged<DownloadedMangaComic> get onOpenComic => actions.onOpenComic;
  ValueChanged<DownloadedMangaComic> get onDeleteComic => actions.onDeleteComic;
  ValueChanged<String> get onSelectGroup => actions.onSelectGroup;
  Future<DownloadGroup> Function(String name) get onCreateGroup =>
      actions.onCreateGroup;
  Future<DownloadGroup> Function(String groupId, String name)
  get onRenameGroup => actions.onRenameGroup;
  Future<void> Function(List<String> orderedGroupIds) get onReorderGroups =>
      actions.onReorderGroups;
  Future<void> Function(String groupId) get onDeleteGroup =>
      actions.onDeleteGroup;
  Future<void> Function(
    DownloadedMangaComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  get onShowComicMenu => actions.onShowComicMenu;
  VoidCallback get onBatchGroup => actions.onBatchGroup;

  static const Duration dismissDuration = Duration(milliseconds: 320);

  @override
  State<DownloadsCompletedTab> createState() => _DownloadsCompletedTabState();
}

class _DownloadsCompletedTabState extends State<DownloadsCompletedTab> {
  static const double _backToTopThreshold = 280;
  static const double _categoryLauncherTopSpace =
      DownloadsCategoryMorphLauncher.height + 22;

  final GlobalKey _stackKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  late final DownloadsCompletedListController _listController;
  _DownloadedComicSwipeReveal? _swipeReveal;
  bool _showBackToTop = false;
  bool _categoryShellOpen = false;
  int _categoryLauncherLandingVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollChanged);
    _listController = DownloadsCompletedListController(
      comics: widget.comics,
      transitionDuration: DownloadsCompletedTab.dismissDuration,
    )..addListener(_handleListChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    _listController
      ..removeListener(_handleListChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DownloadsCompletedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.active && oldWidget.active) ||
        (widget.selectionMode && !oldWidget.selectionMode) ||
        (_swipeReveal != null &&
            !widget.comics.any(
              (comic) => comic.storageKey == _swipeReveal!.comic.storageKey,
            ))) {
      _swipeReveal = null;
    }
    if ((!widget.active || widget.comics.isEmpty) && _showBackToTop) {
      _showBackToTop = false;
    }
    _listController.sync(widget.comics);
  }

  void _handleListChanged() {
    if (mounted) setState(() {});
  }

  void _handleScrollChanged() {
    final showBackToTop =
        widget.active && _scrollController.offset >= _backToTopThreshold;
    if (_showBackToTop == showBackToTop) {
      return;
    }
    setState(() {
      _showBackToTop = showBackToTop;
    });
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _closeSwipeReveal() {
    if (_swipeReveal == null) {
      return;
    }
    setState(() {
      _swipeReveal = null;
    });
  }

  void _handleOpenComic(DownloadedMangaComic comic) {
    _closeSwipeReveal();
    widget.onOpenComic(comic);
  }

  void _handleDeleteComic(DownloadedMangaComic comic) {
    _closeSwipeReveal();
    widget.onDeleteComic(comic);
  }

  void _handleSwipeReveal(_DownloadedComicSwipeReveal reveal) {
    final activeStorageKey = _swipeReveal?.comic.storageKey;
    if (!reveal.claimActive &&
        activeStorageKey != null &&
        activeStorageKey != reveal.comic.storageKey) {
      return;
    }
    final nextReveal = reveal.progress <= precisionErrorTolerance
        ? null
        : reveal;
    setState(() {
      _swipeReveal = nextReveal;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && _swipeReveal != null) {
      setState(() {
        _swipeReveal = null;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final visibleComics = _listController.entries;
    final listContent = visibleComics.isEmpty
        ? Center(child: Text(l10n(context).downloadsEmptyDownloaded))
        : NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: ListView.builder(
              key: const ValueKey<String>('downloaded_comics_list'),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                16,
                _categoryLauncherTopSpace + 12,
                16,
                96,
              ),
              itemCount: visibleComics.length,
              itemBuilder: (context, index) {
                final entry = visibleComics[index];
                return _AnimatedDownloadedComicCard(
                  key: ValueKey<String>('downloaded_${entry.comic.storageKey}'),
                  entry: entry,
                  bottomSpacing: index == visibleComics.length - 1 ? 0 : 12,
                  selectionMode: widget.selectionMode,
                  selected: widget.selectedComicIds.contains(
                    entry.comic.storageKey,
                  ),
                  hasIntegrityIssue: widget.comicsWithIntegrityIssues.contains(
                    entry.comic.storageKey,
                  ),
                  activeSwipeStorageKey: _swipeReveal?.comic.storageKey,
                  swipeRevealStackKey: _stackKey,
                  onSwipeRevealChanged: _handleSwipeReveal,
                  onToggleSelection: widget.onToggleSelection,
                  onOpenComic: _handleOpenComic,
                  onShowComicMenu: widget.onShowComicMenu,
                );
              },
            ),
          );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: listContent),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DownloadsCategoryMorphLauncher(
            visible: !_categoryShellOpen,
            landingVersion: _categoryLauncherLandingVersion,
            label: widget.selectedGroupName,
            comicCount: widget.selectedGroupComicCount,
            onPressed: _showCategoryShell,
          ),
        ),
        if (_swipeReveal case final reveal?)
          Positioned(
            top: reveal.top,
            right:
                -_DownloadedComicEdgeDeleteButton.width * (1 - reveal.progress),
            height: reveal.height,
            child: _DownloadedComicEdgeDeleteButton(
              comic: reveal.comic,
              enabled: reveal.revealed,
              onDeleteComic: _handleDeleteComic,
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          right: widget.selectionMode || _showBackToTop ? 84 : 16,
          bottom: 16 + bottomInset,
          child: DownloadsScanButton(
            selectionMode: widget.selectionMode,
            scanning: widget.scanning,
            selectedCount: widget.selectedCount,
            onDeleteSelected: widget.onDeleteSelected,
            onScanDownloaded: widget.onScanDownloaded,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16 + bottomInset,
          child: DownloadsBatchGroupButton(
            visible: widget.selectionMode,
            enabled: widget.selectedCount > 0,
            onPressed: widget.onBatchGroup,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16 + bottomInset,
          child: DownloadsBackToTopButton(
            visible: _showBackToTop && !widget.selectionMode,
            onPressed: _scrollToTop,
          ),
        ),
      ],
    );
  }

  Future<void> _showCategoryShell() async {
    if (_categoryShellOpen) {
      return;
    }
    _closeSwipeReveal();
    setState(() {
      _categoryShellOpen = true;
    });
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return DownloadsCategoryShellDialog(
          animation: animation,
          onDisposed: _restoreCategoryLauncher,
          groups: widget.groups,
          selectedGroupId: widget.selectedGroupId,
          groupComicCounts: widget.groupComicCounts,
          onSelectGroup: widget.onSelectGroup,
          onCreateGroup: widget.onCreateGroup,
          onRenameGroup: widget.onRenameGroup,
          onReorderGroups: widget.onReorderGroups,
          onDeleteGroup: widget.onDeleteGroup,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  void _restoreCategoryLauncher() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _categoryShellOpen = false;
          _categoryLauncherLandingVersion++;
        });
      }
    });
  }
}

class DownloadsCategoryMorphLauncher extends StatefulWidget {
  const DownloadsCategoryMorphLauncher({
    super.key,
    required this.visible,
    required this.landingVersion,
    required this.onPressed,
    required this.label,
    required this.comicCount,
  });

  static const double height = 36;
  static const double cornerRadius = 12;

  final bool visible;
  final int landingVersion;
  final VoidCallback onPressed;
  final String label;
  final int comicCount;

  @override
  State<DownloadsCategoryMorphLauncher> createState() =>
      _DownloadsCategoryMorphLauncherState();
}

class _DownloadsCategoryMorphLauncherState
    extends State<DownloadsCategoryMorphLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _landingController;
  late final Animation<double> _landingOffset;
  late final Animation<double> _landingScale;

  @override
  void initState() {
    super.initState();
    _landingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    final landingCurve = CurvedAnimation(
      parent: _landingController,
      curve: Curves.easeOutCubic,
    );
    _landingOffset = Tween<double>(begin: -3, end: 0).animate(landingCurve);
    _landingScale = Tween<double>(begin: 0.995, end: 1).animate(landingCurve);
  }

  @override
  void didUpdateWidget(covariant DownloadsCategoryMorphLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && widget.landingVersion != oldWidget.landingVersion) {
      _landingController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _landingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(
      DownloadsCategoryMorphLauncher.cornerRadius,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: _landingController,
            builder: (context, child) {
              return Transform.translate(
                key: const ValueKey<String>(
                  'downloads_category_launcher_landing',
                ),
                offset: Offset(0, _landingOffset.value),
                child: Transform.scale(
                  scale: _landingScale.value,
                  child: child,
                ),
              );
            },
            child: Opacity(
              key: const ValueKey<String>(
                'downloads_category_launcher_opacity',
              ),
              opacity: widget.visible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !widget.visible,
                child: DecoratedBox(
                  key: const ValueKey<String>('downloads_category_launcher'),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: radius,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: radius,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onPressed,
                      child: SizedBox(
                        height: DownloadsCategoryMorphLauncher.height,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_copy_outlined,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.label} (${widget.comicCount})',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadsCategoryShellDialog extends StatefulWidget {
  const DownloadsCategoryShellDialog({
    super.key,
    required this.animation,
    required this.onDisposed,
    required this.groups,
    required this.selectedGroupId,
    required this.groupComicCounts,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onReorderGroups,
    required this.onDeleteGroup,
  });

  static const double _dialogHeight = 420;

  final Animation<double> animation;
  final VoidCallback onDisposed;
  final List<DownloadGroup> groups;
  final String selectedGroupId;
  final Map<String, int> groupComicCounts;
  final ValueChanged<String> onSelectGroup;
  final Future<DownloadGroup> Function(String name) onCreateGroup;
  final Future<DownloadGroup> Function(String groupId, String name)
  onRenameGroup;
  final Future<void> Function(List<String> orderedGroupIds) onReorderGroups;
  final Future<void> Function(String groupId) onDeleteGroup;

  @override
  State<DownloadsCategoryShellDialog> createState() =>
      _DownloadsCategoryShellDialogState();
}

class _DownloadsCategoryShellDialogState
    extends State<DownloadsCategoryShellDialog> {
  late List<DownloadGroup> _groups;
  late String _selectedGroupId;
  bool _sorting = false;

  @override
  void initState() {
    super.initState();
    _groups = List.of(widget.groups);
    _selectedGroupId = widget.selectedGroupId;
  }

  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogWidth = (constraints.maxWidth - 32).clamp(0.0, 420.0);
        final horizontalPosition = (constraints.maxWidth - dialogWidth) / 2;
        final startTop = mediaQuery.padding.top + kToolbarHeight + 56;
        final endCenterY = constraints.maxHeight / 2;
        final startRect = Rect.fromLTWH(
          horizontalPosition,
          startTop,
          dialogWidth,
          DownloadsCategoryMorphLauncher.height,
        );
        final centeredBarRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, endCenterY),
          width: dialogWidth,
          height: DownloadsCategoryMorphLauncher.height,
        );
        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            final progress = widget.animation.value;
            final moveProgress = const Interval(
              0,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final expandProgress = const Interval(
              0.08,
              1,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final movingRect = Rect.lerp(
              startRect,
              centeredBarRect,
              moveProgress,
            )!;
            final rect = Rect.fromCenter(
              center: movingRect.center,
              width: dialogWidth,
              height:
                  DownloadsCategoryMorphLauncher.height +
                  ((DownloadsCategoryShellDialog._dialogHeight -
                          DownloadsCategoryMorphLauncher.height) *
                      expandProgress),
            );
            final contentOpacity = const Interval(
              0.42,
              0.78,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            final launcherOpacity =
                1 - const Interval(0.12, 0.42).transform(progress);
            final shellColor = Color.lerp(
              colorScheme.primaryContainer,
              colorScheme.surfaceContainerHigh,
              expandProgress,
            )!;
            final borderColor = Color.lerp(
              colorScheme.primary.withValues(alpha: 0.24),
              Colors.transparent,
              expandProgress,
            )!;
            return Stack(
              key: const ValueKey<String>('downloads_category_morph_animation'),
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: Material(
                    key: const ValueKey<String>('downloads_category_dialog'),
                    color: shellColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DownloadsCategoryMorphLauncher.cornerRadius +
                            (16 * expandProgress),
                      ),
                      side: BorderSide(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    elevation: 4 + (4 * expandProgress),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: launcherOpacity,
                          child: _DownloadsCategoryLauncherContents(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight:
                                  DownloadsCategoryShellDialog._dialogHeight,
                              maxHeight:
                                  DownloadsCategoryShellDialog._dialogHeight,
                              child: Opacity(
                                opacity: contentOpacity,
                                child: _DownloadsCategoryShellContents(
                                  groups: _groups,
                                  selectedGroupId: _selectedGroupId,
                                  groupComicCounts: widget.groupComicCounts,
                                  onSelectGroup: (groupId) {
                                    widget.onSelectGroup(groupId);
                                    Navigator.of(context).pop();
                                  },
                                  onCreateGroup: _createGroup,
                                  onRenameGroup: _renameGroup,
                                  sorting: _sorting,
                                  onToggleSorting: _toggleSorting,
                                  onReorder: _reorder,
                                  onDeleteGroup: _deleteGroup,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup() async {
    final name = await _showCreateGroupDialog(context);
    if (name == null || !mounted) return;
    final group = await widget.onCreateGroup(name);
    if (!mounted) return;
    setState(() => _groups = [..._groups, group]);
  }

  Future<void> _renameGroup(DownloadGroup group) async {
    unawaited(HapticFeedback.lightImpact());
    final name = await _showRenameGroupDialog(context, group.name);
    if (name == null || !mounted) return;
    final renamed = await widget.onRenameGroup(group.id, name);
    if (!mounted) return;
    setState(() {
      _groups = [
        for (final item in _groups)
          if (item.id == renamed.id) renamed else item,
      ];
    });
  }

  Future<void> _toggleSorting() async {
    if (!_sorting) {
      setState(() => _sorting = true);
      return;
    }
    await widget.onReorderGroups([
      for (final group in _groups)
        if (!group.isDefault) group.id,
    ]);
    if (!mounted) return;
    setState(() => _sorting = false);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final defaultGroups = [
        for (final group in _groups)
          if (group.isDefault) group,
      ];
      final movableGroups = [
        for (final group in _groups)
          if (!group.isDefault) group,
      ];
      if (oldIndex < 0 || oldIndex >= movableGroups.length) return;
      final group = movableGroups.removeAt(oldIndex);
      final insertIndex = newIndex.clamp(0, movableGroups.length);
      movableGroups.insert(insertIndex, group);
      _groups = [...defaultGroups, ...movableGroups];
    });
  }

  Future<void> _deleteGroup(DownloadGroup group) async {
    final strings = l10n(context);
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 260),
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
          AlertDialog(
            title: Text(strings.downloadsDeleteGroupTitle),
            content: Text(strings.downloadsDeleteGroupContent(group.name)),
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
          ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onDeleteGroup(group.id);
    if (!mounted) return;
    setState(() {
      _groups = _groups.where((item) => item.id != group.id).toList();
      if (_selectedGroupId == group.id) {
        _selectedGroupId = DownloadGroupsService.defaultGroupId;
      }
    });
  }
}

class _DownloadsCategoryLauncherContents extends StatelessWidget {
  const _DownloadsCategoryLauncherContents({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.folder_copy_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          l10n(context).comicDetailCategories,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DownloadsCategoryShellContents extends StatefulWidget {
  const _DownloadsCategoryShellContents({
    required this.groups,
    required this.selectedGroupId,
    required this.groupComicCounts,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.sorting,
    required this.onToggleSorting,
    required this.onReorder,
    required this.onDeleteGroup,
  });

  final List<DownloadGroup> groups;
  final String selectedGroupId;
  final Map<String, int> groupComicCounts;
  final ValueChanged<String> onSelectGroup;
  final VoidCallback onCreateGroup;
  final ValueChanged<DownloadGroup> onRenameGroup;
  final bool sorting;
  final VoidCallback onToggleSorting;
  final ReorderCallback onReorder;
  final ValueChanged<DownloadGroup> onDeleteGroup;

  static const double _groupTileExtent = 56;

  @override
  State<_DownloadsCategoryShellContents> createState() =>
      _DownloadsCategoryShellContentsState();
}

class _DownloadsCategoryShellContentsState
    extends State<_DownloadsCategoryShellContents> {
  late final ScrollController _scrollController = ScrollController();
  bool _positionedSelectedGroup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSelectedGroup();
    });
  }

  @override
  void didUpdateWidget(covariant _DownloadsCategoryShellContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGroupId != oldWidget.selectedGroupId ||
        widget.groups.length != oldWidget.groups.length) {
      _positionedSelectedGroup = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _positionSelectedGroup();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _positionSelectedGroup() {
    if (_positionedSelectedGroup || !mounted || !_scrollController.hasClients) {
      return;
    }
    final selectedIndex = widget.groups.indexWhere(
      (group) => group.id == widget.selectedGroupId,
    );
    if (selectedIndex < 0) {
      _positionedSelectedGroup = true;
      return;
    }
    final selectedGroup = widget.groups[selectedIndex];
    if (selectedGroup.isDefault) {
      _scrollController.jumpTo(0);
      _positionedSelectedGroup = true;
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _positionSelectedGroup();
      });
      return;
    }
    final hasDefaultGroup = widget.groups.any((group) => group.isDefault);
    final nonDefaultIndex = widget.groups
        .where((group) => !group.isDefault)
        .toList(growable: false)
        .indexWhere((group) => group.id == widget.selectedGroupId);
    if (nonDefaultIndex < 0) {
      _positionedSelectedGroup = true;
      return;
    }
    final viewport = position.viewportDimension;
    final target =
        (hasDefaultGroup
            ? _DownloadsCategoryShellContents._groupTileExtent
            : 0) +
        nonDefaultIndex * _DownloadsCategoryShellContents._groupTileExtent -
        (viewport - _DownloadsCategoryShellContents._groupTileExtent) / 2;
    _scrollController.jumpTo(target.clamp(0, position.maxScrollExtent));
    _positionedSelectedGroup = true;
  }

  Widget _buildReorderProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(animation.value);
        final colorScheme = Theme.of(context).colorScheme;
        return Material(
          color: Colors.transparent,
          elevation: 6 * progress,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildGroupTile(
    BuildContext context, {
    required DownloadGroup group,
    required bool selected,
    int? reorderIndex,
  }) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canReorder = reorderIndex != null && !group.isDefault;
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedContainer(
        key: ValueKey<String>('download_group_background_${group.id}'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.28)
                : colorScheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.sorting ? null : () => widget.onSelectGroup(group.id),
            onLongPress: widget.sorting || group.isDefault
                ? null
                : () => widget.onRenameGroup(group),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.folder_open_rounded
                        : Icons.folder_outlined,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      group.isDefault
                          ? '${strings.downloadsDefaultGroup} (${widget.groupComicCounts[group.id] ?? 0})'
                          : '${group.name} (${widget.groupComicCounts[group.id] ?? 0})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: group.isDefault ? 12 : 54,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!group.isDefault && !widget.sorting)
                          IconButton(
                            tooltip: strings.comicDetailDelete,
                            onPressed: () => widget.onDeleteGroup(group),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        if (canReorder && widget.sorting)
                          ReorderableDragStartListener(
                            index: reorderIndex,
                            child: Tooltip(
                              message: strings.downloadsReorderGroup,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.sorting) {
      return KeyedSubtree(
        key: ValueKey<String>('download_group_${group.id}'),
        child: tile,
      );
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('download_group_${group.id}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    DownloadGroup? defaultGroup;
    for (final group in widget.groups) {
      if (group.isDefault) {
        defaultGroup = group;
        break;
      }
    }
    final sortableGroups = [
      for (final group in widget.groups)
        if (!group.isDefault) group,
    ];
    return SizedBox(
      height: DownloadsCategoryShellDialog._dialogHeight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.downloadsSwitchGroup,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.centerRight,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: widget.sorting
                      ? FilledButton.tonalIcon(
                          key: const ValueKey<String>(
                            'downloads_group_sort_save',
                          ),
                          onPressed: widget.onToggleSorting,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(strings.commonSave),
                        )
                      : IconButton(
                          key: const ValueKey<String>(
                            'downloads_group_sort_start',
                          ),
                          tooltip: strings.downloadsSortGroups,
                          onPressed: widget.onToggleSorting,
                          icon: const Icon(Icons.sort_rounded),
                        ),
                ),
                IconButton(
                  tooltip: strings.downloadsNewGroup,
                  onPressed: widget.sorting ? null : widget.onCreateGroup,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: _scrollController,
                itemExtent: _DownloadsCategoryShellContents._groupTileExtent,
                padding: EdgeInsets.zero,
                header: defaultGroup == null
                    ? null
                    : _buildGroupTile(
                        context,
                        group: defaultGroup,
                        selected: defaultGroup.id == widget.selectedGroupId,
                      ),
                itemCount: sortableGroups.length,
                onReorderItem: widget.onReorder,
                proxyDecorator: _buildReorderProxy,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final group = sortableGroups[index];
                  final selected = group.id == widget.selectedGroupId;
                  return _buildGroupTile(
                    context,
                    group: group,
                    selected: selected,
                    reorderIndex: index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DownloadsBackToTopButton extends StatelessWidget {
  const DownloadsBackToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      key: const ValueKey<String>('downloads_back_to_top_animation'),
      offset: visible ? Offset.zero : const Offset(1.5, 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.82,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton(
              key: const ValueKey<String>('downloads_back_to_top_button'),
              heroTag: 'downloads_back_to_top',
              onPressed: () => unawaited(onPressed()),
              child: const Icon(Icons.vertical_align_top_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDownloadedComicCard extends StatelessWidget {
  const _AnimatedDownloadedComicCard({
    super.key,
    required this.entry,
    required this.bottomSpacing,
    required this.selectionMode,
    required this.selected,
    required this.hasIntegrityIssue,
    required this.activeSwipeStorageKey,
    required this.swipeRevealStackKey,
    required this.onSwipeRevealChanged,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onShowComicMenu,
  });

  final AnimatedDownloadedComicEntry entry;
  final double bottomSpacing;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final String? activeSwipeStorageKey;
  final GlobalKey swipeRevealStackKey;
  final ValueChanged<_DownloadedComicSwipeReveal> onSwipeRevealChanged;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final Future<void> Function(
    DownloadedMangaComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  onShowComicMenu;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: entry.entering ? 0 : null,
        end: entry.exiting ? 0 : 1,
      ),
      duration: DownloadsCompletedTab.dismissDuration,
      curve: entry.exiting ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (context, value, child) {
        final horizontalExitOffset = entry.exiting
            ? -(MediaQuery.sizeOf(context).width + 32) * (1 - value)
            : 0.0;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(horizontalExitOffset, 8 * (1 - value)),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              alignment: Alignment.topCenter,
              child: ClipRect(
                clipper: const _DownloadedComicVerticalAnimationClipper(),
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: value,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: _SwipeRevealDownloadedComicCard(
        comic: entry.comic,
        bottomSpacing: bottomSpacing,
        selectionMode: selectionMode,
        activeSwipeStorageKey: activeSwipeStorageKey,
        swipeRevealStackKey: swipeRevealStackKey,
        onSwipeRevealChanged: onSwipeRevealChanged,
        child: _DownloadedComicCardContent(
          comic: entry.comic,
          selectionMode: selectionMode,
          selected: selected,
          hasIntegrityIssue: hasIntegrityIssue,
          onToggleSelection: onToggleSelection,
          onOpenComic: onOpenComic,
          onShowComicMenu: onShowComicMenu,
        ),
      ),
    );
  }
}

class _DownloadedComicVerticalAnimationClipper extends CustomClipper<Rect> {
  const _DownloadedComicVerticalAnimationClipper();

  static const double _rightHorizontalOverflow = 88;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      -size.width,
      0,
      size.width + _rightHorizontalOverflow,
      size.height,
    );
  }

  @override
  bool shouldReclip(_DownloadedComicVerticalAnimationClipper oldClipper) =>
      false;
}

class _DownloadedComicCard extends StatelessWidget {
  const _DownloadedComicCard({
    required this.bottomSpacing,
    required this.child,
  });

  final double bottomSpacing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: child,
    );
  }
}

class _SwipeRevealDownloadedComicCard extends StatefulWidget {
  const _SwipeRevealDownloadedComicCard({
    required this.comic,
    required this.bottomSpacing,
    required this.selectionMode,
    required this.activeSwipeStorageKey,
    required this.swipeRevealStackKey,
    required this.onSwipeRevealChanged,
    required this.child,
  });

  final DownloadedMangaComic comic;
  final double bottomSpacing;
  final bool selectionMode;
  final String? activeSwipeStorageKey;
  final GlobalKey swipeRevealStackKey;
  final ValueChanged<_DownloadedComicSwipeReveal> onSwipeRevealChanged;
  final Widget child;

  @override
  State<_SwipeRevealDownloadedComicCard> createState() =>
      _SwipeRevealDownloadedComicCardState();
}

class _SwipeRevealDownloadedComicCardState
    extends State<_SwipeRevealDownloadedComicCard>
    with SingleTickerProviderStateMixin {
  static const double _revealDistance = _DownloadedComicEdgeDeleteButton.width;
  static const double _maxDragOvershoot = 18;
  static const double _dragOvershootResistance = 0.2;
  static const double _settleVelocity = 350;

  late final AnimationController _controller;
  Animation<double>? _animation;
  double _offset = 0;
  double? _dragPosition;
  bool _open = false;

  bool get _revealed => _offset < -_revealDistance * 0.45;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          setState(() {
            _offset = _animation!.value;
          });
          _reportReveal(claimActive: false);
        });
  }

  @override
  void didUpdateWidget(covariant _SwipeRevealDownloadedComicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionMode && !oldWidget.selectionMode) {
      _scheduleClose();
      return;
    }
    if (widget.activeSwipeStorageKey != widget.comic.storageKey &&
        oldWidget.activeSwipeStorageKey == widget.comic.storageKey) {
      _scheduleClose();
    }
  }

  void _scheduleClose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateTo(0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final open = target < 0;
    if (_open != open) {
      setState(() {
        _open = open;
      });
    }
    final distance = (target - _offset).abs();
    final durationMillis = (120 + (100 * distance / _revealDistance))
        .round()
        .clamp(120, 220);
    _controller.duration = Duration(milliseconds: durationMillis);
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  void _handleDragStart(DragStartDetails details) {
    if (widget.selectionMode) {
      return;
    }
    _controller.stop();
    _dragPosition = _offset;
  }

  double _displayOffsetForDrag(double rawOffset) {
    if (rawOffset >= 0) {
      return 0;
    }
    if (rawOffset >= -_revealDistance) {
      return rawOffset;
    }
    final overshoot = (-rawOffset - _revealDistance) * _dragOvershootResistance;
    return -_revealDistance - overshoot.clamp(0, _maxDragOvershoot);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.selectionMode) {
      return;
    }
    final dragPosition = (_dragPosition ?? _offset) + details.delta.dx;
    _dragPosition = dragPosition;
    setState(() {
      _offset = _displayOffsetForDrag(dragPosition);
    });
    _reportReveal(claimActive: true);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.selectionMode) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    _dragPosition = null;
    final open =
        velocity < -_settleVelocity ||
        (velocity <= _settleVelocity && _revealed);
    _animateTo(open ? -_revealDistance : 0);
  }

  void _reportReveal({required bool claimActive}) {
    final stackBox =
        widget.swipeRevealStackKey.currentContext?.findRenderObject()
            as RenderBox?;
    final cardBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null || cardBox == null || !cardBox.hasSize) {
      return;
    }
    final top = cardBox.localToGlobal(Offset.zero, ancestor: stackBox).dy;
    widget.onSwipeRevealChanged(
      _DownloadedComicSwipeReveal(
        comic: widget.comic,
        top: top,
        height: cardBox.size.height - widget.bottomSpacing,
        progress: (-_offset / _revealDistance).clamp(0.0, 1.0),
        revealed: _open,
        claimActive: claimActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomSpacing),
      child: Transform.translate(
        offset: Offset(_offset, 0),
        child: _open
            ? GestureDetector(
                behavior: HitTestBehavior.translucent,
                dragStartBehavior: DragStartBehavior.down,
                onTap: () => _animateTo(0),
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: _DownloadedComicCard(
                  bottomSpacing: 0,
                  child: AbsorbPointer(child: widget.child),
                ),
              )
            : RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: widget.selectionMode
                    ? const <Type, GestureRecognizerFactory>{}
                    : <Type, GestureRecognizerFactory>{
                        _LeftHorizontalDragGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              _LeftHorizontalDragGestureRecognizer
                            >(_LeftHorizontalDragGestureRecognizer.new, (
                              recognizer,
                            ) {
                              recognizer
                                ..dragStartBehavior = DragStartBehavior.down
                                ..onStart = _handleDragStart
                                ..onUpdate = _handleDragUpdate
                                ..onEnd = _handleDragEnd;
                            }),
                      },
                child: _DownloadedComicCard(
                  bottomSpacing: 0,
                  child: widget.child,
                ),
              ),
      ),
    );
  }
}

class _LeftHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  static const double _claimSlopFactor = 0.5;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return globalDistanceMoved <
        -computeHitSlop(pointerDeviceKind, gestureSettings) * _claimSlopFactor;
  }

  @override
  String get debugDescription => 'left horizontal drag';
}

class _DownloadedComicEdgeDeleteButton extends StatelessWidget {
  const _DownloadedComicEdgeDeleteButton({
    required this.comic,
    required this.enabled,
    required this.onDeleteComic,
  });

  static const double width = 58;

  final DownloadedMangaComic comic;
  final bool enabled;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      excluding: !enabled,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Tooltip(
          message: l10n(context).comicDetailDelete,
          child: Material(
            key: ValueKey<String>('downloaded_edge_delete_${comic.storageKey}'),
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onDeleteComic(comic),
              child: SizedBox(
                width: width,
                height: double.infinity,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.onError,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadedComicSwipeReveal {
  const _DownloadedComicSwipeReveal({
    required this.comic,
    required this.top,
    required this.height,
    required this.progress,
    required this.revealed,
    required this.claimActive,
  });

  final DownloadedMangaComic comic;
  final double top;
  final double height;
  final double progress;
  final bool revealed;
  final bool claimActive;
}

class _DownloadedComicCardContent extends StatelessWidget {
  const _DownloadedComicCardContent({
    required this.comic,
    required this.selectionMode,
    required this.selected,
    required this.hasIntegrityIssue,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onShowComicMenu,
  });

  final DownloadedMangaComic comic;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final Future<void> Function(
    DownloadedMangaComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  onShowComicMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.secondaryContainer.withValues(alpha: 0.96)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.34)
              : colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Builder(
          builder: (itemContext) => GestureDetector(
            onLongPressStart: selectionMode
                ? null
                : (details) {
                    unawaited(HapticFeedback.mediumImpact());
                    unawaited(
                      onShowComicMenu(
                        comic,
                        details.globalPosition,
                        itemContext,
                      ),
                    );
                  },
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (selectionMode) {
                  onToggleSelection(comic.storageKey);
                } else {
                  onOpenComic(comic);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        DownloadedComicCover(
                          comic: comic,
                          heroTag: 'downloaded_cover_${comic.storageKey}',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comic.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (comic.subTitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  comic.subTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                l10n(context).downloadsChapterCount(
                                  '${comic.chapters.length}',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DownloadedComicSelectionSlot(
                          visible: selectionMode,
                          selected: selected,
                        ),
                      ],
                    ),
                  ),
                  if (hasIntegrityIssue)
                    DownloadedComicIntegrityWarningBanner(
                      message: l10n(context).downloadsIntegrityWarning,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> _showCreateGroupDialog(BuildContext context) async {
  final controller = TextEditingController();
  final strings = l10n(context);
  final value = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final name = value.text.trim();
            return AlertDialog(
              title: Text(strings.downloadsNewGroup),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.downloadsGroupName,
                  errorText: name.isEmpty
                      ? strings.downloadsGroupNameRequired
                      : null,
                ),
                onSubmitted: (_) {
                  if (name.isNotEmpty) Navigator.pop(dialogContext, name);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, name),
                  child: Text(strings.downloadsCreateGroup),
                ),
              ],
            );
          },
        ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 260));
  controller.dispose();
  return value;
}

Future<String?> _showRenameGroupDialog(
  BuildContext context,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );
  final strings = l10n(context);
  final value = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 260),
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
        child: ScaleTransition(
          key: const ValueKey<String>('downloads_rename_group_transition'),
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            final name = value.text.trim();
            return AlertDialog(
              key: const ValueKey<String>('downloads_rename_group_dialog'),
              title: Text(strings.downloadsRenameGroup),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.downloadsGroupName,
                  errorText: name.isEmpty
                      ? strings.downloadsGroupNameRequired
                      : null,
                ),
                onSubmitted: (_) {
                  if (name.isNotEmpty) Navigator.pop(dialogContext, name);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, name),
                  child: Text(strings.commonSave),
                ),
              ],
            );
          },
        ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 280));
  controller.dispose();
  return value;
}
