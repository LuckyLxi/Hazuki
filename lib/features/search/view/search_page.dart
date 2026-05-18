import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';

import 'search_entry_page.dart';
import 'search_results_page.dart';
import '../support/search_shared.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    this.initialKeyword,
    this.autoFocusOnOpen = false,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
    this.searchPageLoader,
  });

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
        initialKeyword: keyword,
        entryIntent: SearchEntryIntent.externalKeyword,
        comicDetailPageBuilder: comicDetailPageBuilder,
        comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
        searchPageLoader: searchPageLoader,
      );
    }
    return SearchEntryPage(
      autoFocusOnOpen: autoFocusOnOpen,
      comicDetailPageBuilder: comicDetailPageBuilder,
      comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
      searchPageLoader: searchPageLoader,
    );
  }
}
