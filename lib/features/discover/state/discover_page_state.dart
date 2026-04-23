import 'package:hazuki/models/hazuki_models.dart';

class DiscoverPageState {
  List<ExploreSection> sections = const [];
  String? errorMessage;
  bool initialLoading = true;
  bool refreshing = false;
  int visibleSectionCount = 0;
  int sectionRevealGeneration = 0;
}
