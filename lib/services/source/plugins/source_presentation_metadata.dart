/// A source-scoped metadata reader that also works outside the widget tree.
typedef SourcePresentationReader =
    Map<String, dynamic> Function(String sourceKey);

Map<String, dynamic> emptySourcePresentation(String sourceKey) => const {};

/// Historical metadata can render saved records, but never enables operations.
Map<String, dynamic> historicalSourcePresentation(Map<String, dynamic> value) {
  final display = value;
  return {
    for (final key in const ['showComicId', 'showTags', 'showComicStatus'])
      if (display[key] is bool) key: display[key],
    for (final key in const ['listTagGroups'])
      if (display[key] case final List groups)
        key: groups.whereType<String>().toList(growable: false),
  };
}
