import 'package:flutter/material.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

import '../state/history_page_controller.dart';
import 'history_actions.dart';
import 'history_favorite_support.dart';
import 'history_menu_support.dart';

class HistoryPageActionHandler {
  HistoryPageActionHandler({
    required HistoryPageController controller,
    required ComicDetailPageBuilder comicDetailPageBuilder,
  }) : _controller = controller,
       _comicDetailPageBuilder = comicDetailPageBuilder;

  final HistoryPageController _controller;
  final ComicDetailPageBuilder _comicDetailPageBuilder;

  Future<void> deleteSelected(BuildContext context) async {
    if (_controller.selectedCount == 0) {
      return;
    }

    final confirm = await showDeleteSelectedHistoryDialog(
      context,
      selectedCount: _controller.selectedCount,
    );
    if (!context.mounted || confirm != true) {
      return;
    }

    await _controller.deleteSelected();
  }

  Future<void> clearAll(BuildContext context) async {
    final confirm = await showClearHistoryDialog(context);
    if (!context.mounted || confirm != true) {
      return;
    }

    await _controller.clearAll();
  }

  Future<void> showComicMenu({
    required BuildContext context,
    required ExploreComic comic,
    required Offset globalPosition,
    required BuildContext itemContext,
  }) async {
    final action = await showHistoryComicMenu(
      context: context,
      itemContext: itemContext,
      globalPosition: globalPosition,
    );

    if (!context.mounted || action == null) {
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

  Future<void> openComic(
    BuildContext context,
    ExploreComic comic,
    String heroTag,
  ) async {
    _controller.disableEntryAnimation();
    await openComicDetail(
      context,
      comic: comic,
      heroTag: heroTag,
      pageBuilder: _comicDetailPageBuilder,
    );
    if (!context.mounted) {
      return;
    }
    await _controller.reload();
  }
}
