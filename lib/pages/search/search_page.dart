import 'package:flutter/material.dart';

import '../../app/app.dart';
import 'search_entry_page.dart';
import 'search_results_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    this.initialKeyword,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final String? initialKeyword;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  Widget build(BuildContext context) {
    final keyword = initialKeyword?.trim() ?? '';
    if (keyword.isNotEmpty) {
      return SearchResultsPage(
        initialKeyword: keyword,
        comicDetailPageBuilder: comicDetailPageBuilder,
        comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
      );
    }
    return SearchEntryPage(
      comicDetailPageBuilder: comicDetailPageBuilder,
      comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
    );
  }
}
