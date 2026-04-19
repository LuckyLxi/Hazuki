import 'package:flutter/material.dart';

import '../../app/app.dart';
import 'search_entry_page.dart';
import 'search_results_page.dart';
import 'search_shared.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    this.initialKeyword,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
    this.searchPageLoader,
  });

  final String? initialKeyword;
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
      comicDetailPageBuilder: comicDetailPageBuilder,
      comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
      searchPageLoader: searchPageLoader,
    );
  }
}
