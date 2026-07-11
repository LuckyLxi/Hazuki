import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import 'search_entry_page.dart';
import 'search_results_page.dart';
import '../support/search_shared.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    required this.sourceService,
    required this.historyService,
    this.initialKeyword,
    this.autoFocusOnOpen = false,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
    this.searchPageLoader,
  });

  final SourceSearchGateway sourceService;
  final SearchHistoryService historyService;
  final String? initialKeyword;
  final bool autoFocusOnOpen;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final SearchPageLoader? searchPageLoader;

  @override
  Widget build(BuildContext context) {
    final keyword = initialKeyword?.trim() ?? '';
    if (keyword.isNotEmpty) {
      return SearchResultsPage(
        sourceService: sourceService,
        historyService: historyService,
        initialKeyword: keyword,
        entryIntent: SearchEntryIntent.externalKeyword,
        comicDetailPageBuilder: comicDetailPageBuilder,
        comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
        searchPageLoader: searchPageLoader,
      );
    }
    return SearchEntryPage(
      sourceService: sourceService,
      historyService: historyService,
      autoFocusOnOpen: autoFocusOnOpen,
      comicDetailPageBuilder: comicDetailPageBuilder,
      comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
      searchPageLoader: searchPageLoader,
    );
  }
}
