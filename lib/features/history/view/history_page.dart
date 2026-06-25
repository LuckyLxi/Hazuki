import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/read_history_service.dart';
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
    required this.comicDetailPageBuilder,
    required this.onFavoriteRequested,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final HistoryFavoriteRequested onFavoriteRequested;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryPageController _controller;
  late final HistoryPageScrollCoordinator _scrollCoordinator;
  late final Listenable _pageListenable;
  late HistoryPageActionHandler _actions;

  @override
  void initState() {
    super.initState();
    _controller = HistoryPageController(
      readHistoryService: sl<ReadHistoryService>(),
      sourceService: sl<SourceRuntimeGateway>(),
    );
    _scrollCoordinator = HistoryPageScrollCoordinator();
    _pageListenable = Listenable.merge([_controller, _scrollCoordinator]);
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
    _scrollCoordinator.dispose();
    _controller.dispose();
    super.dispose();
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
