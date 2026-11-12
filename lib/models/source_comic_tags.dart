import '../models/comic_detail_models.dart';

List<String> sourceComicDetailTags(
  ComicDetailsData details,
  Map<String, dynamic> presentation,
) {
  final groups = presentation['listTagGroups'];
  if (groups is! List) return const [];
  final keys = groups
      .whereType<String>()
      .map((key) => key.trim().toLowerCase())
      .toSet();
  return details.tags.entries
      .where((entry) => keys.contains(entry.key.trim().toLowerCase()))
      .expand((entry) => entry.value)
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
