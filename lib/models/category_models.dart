import 'explore_models.dart';

class CategoryTagGroup {
  const CategoryTagGroup({
    required this.name,
    required this.tags,
    this.params = const <String?>[],
    this.itemType = 'search',
  });

  final String name;
  final List<String> tags;
  final List<String?> params;
  final String itemType;

  String? paramForIndex(int index) {
    if (index < 0 || index >= params.length) {
      return null;
    }
    final param = params[index]?.trim();
    return param == null || param.isEmpty ? null : param;
  }

  bool get opensCategory => itemType.trim() == 'category';
}

class CategoryRankingOption {
  const CategoryRankingOption({required this.value, required this.label});

  final String value;
  final String label;
}

class CategoryComicsResult {
  const CategoryComicsResult({required this.comics, required this.maxPage});

  final List<ExploreComic> comics;
  final int? maxPage;
}
