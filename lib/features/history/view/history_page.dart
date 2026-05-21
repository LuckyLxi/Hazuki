import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/history_page_controller.dart';
import '../support/history_actions.dart';
import '../support/history_favorite_support.dart';
import '../support/history_menu_support.dart';
import 'history_page_content.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryPageController _controller;
  final ScrollController _scrollController = ScrollController();

  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _controller = HistoryPageController(
      readHistoryService: sl<ReadHistoryService>(),
      sourceService: sl<HazukiSourceService>(),
    );
    _scrollController.addListener(_onScroll);
    unawaited(_controller.loadInitial());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextShowBackToTop = position.pixels > 520;
    if (nextShowBackToTop != _showBackToTop && mounted) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }
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

  Future<void> _deleteSelected() async {
    if (_controller.selectedCount == 0) {
      return;
    }

    final confirm = await showDeleteSelectedHistoryDialog(
      context,
      selectedCount: _controller.selectedCount,
    );
    if (confirm != true) {
      return;
    }

    await _controller.deleteSelected();
  }

  Future<void> _clearAll() async {
    final confirm = await showClearHistoryDialog(context);
    if (confirm != true) {
      return;
    }

    await _controller.clearAll();
  }

  Future<void> _showComicMenu(
    ExploreComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  ) async {
    final action = await showHistoryComicMenu(
      context: context,
      itemContext: itemContext,
      globalPosition: globalPosition,
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case HistoryComicMenuAction.copy:
        await copyHistoryComicId(context, comic.id);
        break;
      case HistoryComicMenuAction.favorite:
        await toggleFavoriteFromHistory(context, comic);
        break;
      case HistoryComicMenuAction.delete:
        await _controller.deleteComic(comic);
        break;
    }
  }

  Future<void> _openComic(ExploreComic comic, String heroTag) async {
    _controller.disableEntryAnimation();
    await openComicDetail(
      context,
      comic: comic,
      heroTag: heroTag,
      pageBuilder: widget.comicDetailPageBuilder,
    );
    if (!mounted) {
      return;
    }
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return WindowsComicDetailHost(
          child: Scaffold(
            appBar: hazukiFrostedAppBar(
              context: context,
              title: Text(strings.historyTitle),
              actions: [
                if (_controller.hasHistory)
                  IconButton(
                    tooltip: _controller.selectionMode
                        ? strings.historySelectionCancelTooltip
                        : strings.historySelectionEnterTooltip,
                    icon: Icon(
                      _controller.selectionMode ? Icons.close : Icons.checklist,
                    ),
                    onPressed: _controller.toggleSelectionMode,
                  ),
                if (_controller.hasHistory)
                  IconButton(
                    tooltip: _controller.selectionMode
                        ? strings.historyDeleteSelectedTooltip
                        : strings.historyClearAllTooltip,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _controller.selectionMode
                        ? _deleteSelected
                        : _clearAll,
                  ),
              ],
            ),
            body: HistoryPageContent(
              loading: _controller.loading,
              history: _controller.history,
              scrollController: _scrollController,
              showBackToTop: _showBackToTop,
              playItemEntryAnimation: _controller.playItemEntryAnimation,
              selectionMode: _controller.selectionMode,
              selectedStorageKeys: _controller.selectedStorageKeys,
              strings: strings,
              comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
              onOpenComic: _openComic,
              onToggleSelection: _controller.toggleSelection,
              onShowMenu: _showComicMenu,
              onBackToTopPressed: _scrollToTop,
            ),
          ),
        );
      },
    );
  }
}
