import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'history_comic_list_item.dart';

const Duration _historyItemRemovalDuration = Duration(milliseconds: 240);

class HistoryPageContent extends StatefulWidget {
  const HistoryPageContent({
    super.key,
    required this.loading,
    required this.history,
    required this.scrollController,
    required this.showBackToTop,
    required this.playItemEntryAnimation,
    required this.selectionMode,
    required this.selectedStorageKeys,
    required this.strings,
    required this.comicCoverHeroTagBuilder,
    required this.onOpenComic,
    required this.onToggleSelection,
    required this.onShowMenu,
    required this.onBackToTopPressed,
  });

  final bool loading;
  final List<ExploreComic> history;
  final ScrollController scrollController;
  final bool showBackToTop;
  final bool playItemEntryAnimation;
  final bool selectionMode;
  final Set<String> selectedStorageKeys;
  final AppLocalizations strings;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final Future<void> Function(ExploreComic comic, String heroTag) onOpenComic;
  final void Function(String storageKey, {bool? selected}) onToggleSelection;
  final Future<void> Function(
    ExploreComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  onShowMenu;
  final Future<void> Function() onBackToTopPressed;

  @override
  State<HistoryPageContent> createState() => _HistoryPageContentState();
}

class _HistoryPageContentState extends State<HistoryPageContent> {
  late List<ExploreComic> _visibleHistory;
  final Set<String> _removingStorageKeys = <String>{};
  int _syncVersion = 0;

  @override
  void initState() {
    super.initState();
    _visibleHistory = List<ExploreComic>.of(widget.history);
  }

  @override
  void didUpdateWidget(covariant HistoryPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibleHistory();
  }

  void _syncVisibleHistory() {
    final nextByKey = <String, ExploreComic>{
      for (final comic in widget.history) comic.scopedId.storageKey: comic,
    };
    final nextKeys = nextByKey.keys.toSet();
    final visibleKeys = _visibleHistory
        .map((comic) => comic.scopedId.storageKey)
        .toSet();
    final removedKeys = visibleKeys.difference(nextKeys);
    final addedKeys = nextKeys.difference(visibleKeys);

    if (removedKeys.isEmpty && _removingStorageKeys.isEmpty) {
      _visibleHistory = List<ExploreComic>.of(widget.history);
      return;
    }

    if (removedKeys.isNotEmpty) {
      _removingStorageKeys.addAll(removedKeys);
      _scheduleRemovalCleanup();
    }

    _visibleHistory = <ExploreComic>[
      for (final comic in _visibleHistory)
        nextByKey[comic.scopedId.storageKey] ?? comic,
      for (final comic in widget.history)
        if (addedKeys.contains(comic.scopedId.storageKey)) comic,
    ];
  }

  void _scheduleRemovalCleanup() {
    final version = ++_syncVersion;
    Future<void>.delayed(_historyItemRemovalDuration, () {
      if (!mounted || version != _syncVersion) {
        return;
      }
      setState(() {
        final currentKeys = widget.history
            .map((comic) => comic.scopedId.storageKey)
            .toSet();
        _removingStorageKeys.removeWhere(currentKeys.contains);
        _visibleHistory = List<ExploreComic>.of(widget.history);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBody(context),
        HistoryBackToTopButton(
          visible: widget.showBackToTop,
          onPressed: widget.onBackToTopPressed,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.loading) {
      return _buildLoadingState();
    }
    if (widget.history.isEmpty && _visibleHistory.isEmpty) {
      return Center(child: Text(widget.strings.historyEmpty));
    }
    return _buildHistoryList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazukiSandyLoadingIndicator(size: 136),
          const SizedBox(height: 10),
          Text(widget.strings.commonLoading),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.all(16),
      itemCount: _visibleHistory.length,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) {
          return null;
        }
        final storageKey = key.value;
        final index = _visibleHistory.indexWhere(
          (comic) => comic.scopedId.storageKey == storageKey,
        );
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        return _buildItem(_visibleHistory[index], index);
      },
    );
  }

  Widget _buildItem(ExploreComic comic, int index) {
    final storageKey = comic.scopedId.storageKey;
    final heroTag = widget.comicCoverHeroTagBuilder(comic, salt: 'history');
    return HistoryComicListItem(
      key: ValueKey(storageKey),
      comic: comic,
      index: index,
      heroTag: heroTag,
      animateEntry:
          widget.playItemEntryAnimation &&
          !_removingStorageKeys.contains(storageKey),
      removing: _removingStorageKeys.contains(storageKey),
      selectionMode: widget.selectionMode,
      selected: widget.selectedStorageKeys.contains(storageKey),
      onShowMenu: (globalPosition, itemContext) =>
          widget.onShowMenu(comic, globalPosition, itemContext),
      onToggleSelection: (selected) =>
          widget.onToggleSelection(storageKey, selected: selected),
      onTap: () async {
        if (widget.selectionMode) {
          widget.onToggleSelection(storageKey);
          return;
        }
        await widget.onOpenComic(comic, heroTag);
      },
    );
  }
}

class HistoryBackToTopButton extends StatelessWidget {
  const HistoryBackToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.24),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: visible ? 1 : 0.86,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: IgnorePointer(
              ignoring: !visible,
              child: FloatingActionButton(
                heroTag: 'history_back_to_top',
                onPressed: () => unawaited(onPressed()),
                child: const Icon(Icons.vertical_align_top_rounded),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
