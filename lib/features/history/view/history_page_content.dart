import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'history_comic_list_item.dart';

class HistoryPageContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBody(context),
        HistoryBackToTopButton(
          visible: showBackToTop,
          onPressed: onBackToTopPressed,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return _buildLoadingState();
    }
    if (history.isEmpty) {
      return Center(child: Text(strings.historyEmpty));
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
          Text(strings.commonLoading),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return _buildItem(history[index], index);
      },
    );
  }

  Widget _buildItem(ExploreComic comic, int index) {
    final storageKey = comic.scopedId.storageKey;
    final heroTag = comicCoverHeroTagBuilder(comic, salt: 'history');
    return HistoryComicListItem(
      key: ValueKey(storageKey),
      comic: comic,
      index: index,
      heroTag: heroTag,
      animateEntry: playItemEntryAnimation,
      selectionMode: selectionMode,
      selected: selectedStorageKeys.contains(storageKey),
      onShowMenu: (globalPosition, itemContext) =>
          onShowMenu(comic, globalPosition, itemContext),
      onToggleSelection: (selected) =>
          onToggleSelection(storageKey, selected: selected),
      onTap: () async {
        if (selectionMode) {
          onToggleSelection(storageKey);
          return;
        }
        await onOpenComic(comic, heroTag);
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
