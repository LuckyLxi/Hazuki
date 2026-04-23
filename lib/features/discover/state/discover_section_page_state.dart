import 'package:hazuki/models/hazuki_models.dart';

class DiscoverSectionPageState {
  List<ExploreComic> comics = [];
  List<CategoryRankingOption> sortOptions = const <CategoryRankingOption>[];
  String? selectedSortValue;
  bool loadingMore = false;
  bool hasMore = true;
  int currentPage = 0;
  String? errorMessage;
  bool sortLoading = false;
  bool showLoadMoreFooter = false;
  int requestVersion = 0;
}
