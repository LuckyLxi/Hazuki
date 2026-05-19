import 'package:hazuki/models/hazuki_models.dart';

class DiscoverPageState {
  List<ExploreSection> sections = const [];
  String? errorMessage;
  bool initialLoading = true;
  bool refreshing = false;
  int visibleSectionCount = 0;
  int sectionRevealGeneration = 0;
  final Map<int, int> sectionPages = <int, int>{};
  final Set<int> sectionLoadingMore = <int>{};
  final Set<int> sectionNoMore = <int>{};
}
