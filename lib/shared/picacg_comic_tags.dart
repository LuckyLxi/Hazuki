import '../models/comic_detail_models.dart';

const _picacgTagKeys = <String>{
  'tag',
  'tags',
  'category',
  'categories',
  '标签',
  '分类',
};

List<String> picacgComicDetailTags(ComicDetailsData details) => details
    .tags
    .entries
    .where((entry) => _picacgTagKeys.contains(entry.key.trim().toLowerCase()))
    .expand((entry) => entry.value)
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toSet()
    .toList(growable: false);
