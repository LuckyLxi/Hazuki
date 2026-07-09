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

part 'downloads_completed/downloads_completed_buttons.dart';
part 'downloads_completed/downloads_completed_category.dart';
part 'downloads_completed/downloads_completed_comic_card.dart';

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
