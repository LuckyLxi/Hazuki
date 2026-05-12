import 'explore_models.dart';

class CategoryTagGroup {
  const CategoryTagGroup({required this.name, required this.tags});

  final String name;
  final List<String> tags;
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
