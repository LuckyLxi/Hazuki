import 'package:hazuki/models/hazuki_models.dart';

const searchLoadTimeout = Duration(seconds: 25);
const searchHistoryCollapsedMaxRows = 4;
const searchHistoryChipSpacing = 8.0;
typedef SearchPageLoader =
    Future<SearchComicsResult> Function({
      required String keyword,
      required int page,
      required String order,
    });

typedef SearchComicDetailsLoader =
    Future<ComicDetailsData> Function(
      String comicId, {
      required String sourceKey,
    });

class SearchMessages {
  const SearchMessages({required this.timeout, required this.failed});
  final String timeout;
  final String Function(String error) failed;
}
