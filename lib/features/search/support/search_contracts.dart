import 'package:hazuki/models/hazuki_models.dart';

const searchLoadTimeout = Duration(seconds: 25);
const searchHistoryCollapsedMaxRows = 4;
const searchHistoryChipSpacing = 8.0;
const jmSearchSourceKey = 'jm';
const searchOrderKeys = <String>{
  'mr',
  'mv',
  'mv_m',
  'mv_w',
  'mv_t',
  'mp',
  'tf',
};
const copyMangaSourceKey = 'copy_manga';
const copyMangaSearchModeKeys = <String>{'-', 'name', 'author', 'local'};
const picacgSourceKey = 'picacg';
const picacgSearchOrderKeys = <String>{'dd', 'da', 'ld', 'vd'};

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

String? normalizeDirectComicIdKeyword(String keyword) {
  final normalized = keyword.trim().toLowerCase();
  if (RegExp(r'^\d{2,}$').hasMatch(normalized)) {
    return normalized;
  }
  if (RegExp(r'^jm\d{2,}$').hasMatch(normalized)) {
    return normalized;
  }
  return null;
}

String? directComicIdSourceKey({
  required bool aggregateSearchEnabled,
  required String activeSourceKey,
}) {
  if (aggregateSearchEnabled) return jmSearchSourceKey;
  return activeSourceKey.trim() == jmSearchSourceKey ? jmSearchSourceKey : null;
}
