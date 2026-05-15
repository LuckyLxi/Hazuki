import 'package:hazuki/models/hazuki_models.dart';

class CategoryTagNavigationTarget {
  const CategoryTagNavigationTarget({
    required this.title,
    required this.viewMoreUrl,
  });

  final String title;
  final String viewMoreUrl;
}

CategoryTagNavigationTarget? resolveCategoryTagNavigationTarget(
  Iterable<CategoryTagGroup> groups,
  String rawTag,
) {
  final tag = rawTag.trim();
  if (tag.isEmpty) {
    return null;
  }

  for (final group in groups) {
    if (!group.opensCategory) {
      continue;
    }
    final index = group.tags.indexWhere((item) => item.trim() == tag);
    if (index < 0) {
      continue;
    }
    final param = group.paramForIndex(index);
    return CategoryTagNavigationTarget(
      title: group.tags[index],
      viewMoreUrl: param == null
          ? 'category:${group.tags[index]}'
          : 'category:${group.tags[index]}@$param',
    );
  }

  return null;
}
