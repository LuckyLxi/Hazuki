/// A source-scoped metadata reader that also works outside the widget tree.
typedef SourcePresentationReader =
    Map<String, dynamic> Function(String sourceKey);

Map<String, dynamic> emptySourcePresentation(String sourceKey) => const {};

/// Historical metadata can render saved records, but never enables operations.
Map<String, dynamic> historicalSourcePresentation(Map<String, dynamic> value) =>
    {
      for (final key in const [
        'showComicId',
        'showUploader',
        'showPageCount',
        'showTags',
        'showComicStatus',
      ])
        if (value[key] is bool) key: value[key],
      if (value['listTagGroups'] case final List groups)
        'listTagGroups': groups.whereType<String>().toList(growable: false),
    };
