/// A source-scoped metadata reader that also works outside the widget tree.
typedef SourcePresentationReader =
    Map<String, dynamic> Function(String sourceKey);

Map<String, dynamic> emptySourcePresentation(String sourceKey) => const {};

/// Preserve the display contract of old declarations without source identities.
/// Explicit new fields, including false or an empty list, always take precedence.
Map<String, dynamic> comicDetailPresentation(Map<String, dynamic> value) {
  if (value['showUploader'] != true) return value;
  return {
    ...value,
    if (!value.containsKey('showCategories')) 'showCategories': true,
    if (!value.containsKey('showChineseTeam')) 'showChineseTeam': true,
    if (!value.containsKey('detailTagGroups'))
      'detailTagGroups': const ['tag', 'tags', '标签'],
  };
}

/// Historical metadata can render saved records, but never enables operations.
Map<String, dynamic> historicalSourcePresentation(Map<String, dynamic> value) {
  final display = comicDetailPresentation(value);
  return {
    for (final key in const [
      'showComicId',
      'showUploader',
      'showCategories',
      'showChineseTeam',
      'showPageCount',
      'showTags',
      'showComicStatus',
    ])
      if (display[key] is bool) key: display[key],
    for (final key in const ['listTagGroups', 'detailTagGroups'])
      if (display[key] case final List groups)
        key: groups.whereType<String>().toList(growable: false),
  };
}
