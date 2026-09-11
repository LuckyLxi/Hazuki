import 'package:hazuki/models/hazuki_models.dart';

import '../state/aggregate_search_results_controller.dart';
import '../state/search_results_controller.dart';
import 'search_contracts.dart';

/// Coordinates search decisions; the view owns focus and route presentation.
class SearchSubmissionCoordinator {
  SearchSubmissionCoordinator({
    required this.results,
    required this.aggregateResults,
    required this.recordHistory,
    required this.openComic,
    required this.isActive,
  });

  final SearchResultsController results;
  final AggregateSearchResultsController aggregateResults;
  final Future<void> Function(String keyword) recordHistory;
  final Future<void> Function(ExploreComic comic) openComic;
  final bool Function() isActive;
  int _generation = 0;

  void invalidate() => _generation++;

  Future<void> submit({
    required String keyword,
    required bool aggregate,
    required String activeSourceKey,
    required SearchMessages messages,
  }) async {
    final generation = ++_generation;
    final sourceKey = directComicIdSourceKey(
      aggregateSearchEnabled: aggregate,
      activeSourceKey: activeSourceKey,
    );
    final comicId = sourceKey == null
        ? null
        : normalizeDirectComicIdKeyword(keyword);
    final token = comicId == null
        ? null
        : results.prepareDirectIdLookup(keyword);
    bool current() =>
        isActive() &&
        generation == _generation &&
        (token == null || results.isCurrentRequest(token));

    if (comicId != null) {
      try {
        final details = await results.loadComicById(
          comicId,
          sourceKey: sourceKey!,
        );
        if (!current()) return;
        final comic = ExploreComic(
          id: details.id,
          title: details.title.trim().isEmpty ? keyword.trim() : details.title,
          subTitle: details.subTitle,
          cover: details.cover,
          sourceKey: details.sourceKey,
        );
        await recordHistory(keyword);
        if (!current()) return;
        await openComic(comic);
        if (current()) results.finishDirectIdLookup(token!);
        return;
      } catch (_) {
        // Preserve keyword search fallback when direct lookup cannot be opened.
      }
    }
    if (!current()) return;
    await recordHistory(keyword);
    if (!current()) return;
    if (token != null) results.finishDirectIdLookup(token);
    if (aggregate) {
      await aggregateResults.search(messages, keyword);
    } else {
      await results.search(messages, keyword: keyword, page: 1);
    }
  }
}
