import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/shared/comic_cover_prefetcher.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/history_page_controller.dart';
import '../support/history_callbacks.dart';
import '../support/history_page_action_handler.dart';
import '../support/history_page_scroll_coordinator.dart';
import 'history_page_app_bar.dart';
import 'history_page_content.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.readHistoryService,
    required this.sourceService,
    required this.imageGateway,
    required this.comicDetailPageBuilder,
    required this.onFavoriteRequested,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ReadHistoryService readHistoryService;
  final SourceRuntimeGateway sourceService;
  final SourceImageGateway imageGateway;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final HistoryFavoriteRequested onFavoriteRequested;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryPageController _controller;
  late final HistoryPageScrollCoordinator _scrollCoordinator;
  late final ComicCoverPrefetcher _coverPrefetcher;
  late final Listenable _pageListenable;
  late HistoryPageActionHandler _actions;

  @override
  void initState() {
    super.initState();
    _controller = HistoryPageController(
      readHistoryService: widget.readHistoryService,
      sourceService: widget.sourceService,
    );
    _scrollCoordinator = HistoryPageScrollCoordinator();
    _coverPrefetcher = ComicCoverPrefetcher(imageGateway: widget.imageGateway);
    _pageListenable = Listenable.merge([_controller, _scrollCoordinator]);
    _controller.addListener(_scheduleCoverPrefetch);
    _scrollCoordinator.controller.addListener(_prefetchVisibleCovers);
    _actions = HistoryPageActionHandler(
      controller: _controller,
      comicDetailPageBuilder: widget.comicDetailPageBuilder,
      onFavoriteRequested: widget.onFavoriteRequested,
    );
    unawaited(_controller.loadInitial());
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actions = HistoryPageActionHandler(
      controller: _controller,
      comicDetailPageBuilder: widget.comicDetailPageBuilder,
      onFavoriteRequested: widget.onFavoriteRequested,
    );
  }

  @override
  void dispose() {
    _scrollCoordinator.controller.removeListener(_prefetchVisibleCovers);
    _controller.removeListener(_scheduleCoverPrefetch);
    _coverPrefetcher.dispose();
    _scrollCoordinator.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleCoverPrefetch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefetchVisibleCovers();
    });
  }

  void _prefetchVisibleCovers() {
    _coverPrefetcher.prefetchAroundScroll(
      comics: _controller.history,
      scrollController: _scrollCoordinator.controller,
      estimatedItemExtent: 112,
      extraBefore: 6,
      extraAfter: 28,
      maxRequests: 28,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        return PopScope(
          canPop: !_controller.selectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _controller.exitSelectionMode();
            }
          },
          child: WindowsComicDetailHost(
            child: Scaffold(
              appBar: HistoryPageAppBar(
                hasHistory: _controller.hasHistory,
                selectionMode: _controller.selectionMode,
                onToggleSelectionMode: _controller.toggleSelectionMode,
                onDeleteSelected: () => _actions.deleteSelected(context),
                onClearAll: () => _actions.clearAll(context),
              ),
              body: HistoryPageContent(
                loading: _controller.loading,
                history: _controller.history,
                scrollController: _scrollCoordinator.controller,
                showBackToTop: _scrollCoordinator.showBackToTop,
                playItemEntryAnimation: _controller.playItemEntryAnimation,
                selectionMode: _controller.selectionMode,
                selectedStorageKeys: _controller.selectedStorageKeys,
                strings: strings,
                comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
                onOpenComic: (comic, heroTag) =>
                    _actions.openComic(context, comic, heroTag),
                onToggleSelection: _controller.toggleSelection,
                onShowMenu: (comic, globalPosition, itemContext) =>
                    _actions.showComicMenu(
                      context: context,
                      comic: comic,
                      globalPosition: globalPosition,
                      itemContext: itemContext,
                    ),
                onBackToTopPressed: _scrollCoordinator.scrollToTop,
              ),
            ),
          ),
        );
      },
    );
  }
}
