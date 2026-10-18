import '../../../models/hazuki_models.dart';
import '../../../shared/chapter_title_resolver.dart';
import '../common/source_json_coerce.dart';

typedef ComicDetailsTextTranslator =
    String Function(String text, {String sourceKey});

/// Converts a source comic-detail payload into Hazuki's domain model.
class SourceComicDetailsParser {
  const SourceComicDetailsParser(this._translateSourceText);

  final ComicDetailsTextTranslator _translateSourceText;

  ComicDetailsData parse({
    required Map<String, dynamic> map,
    required String fallbackComicId,
    required String sourceKey,
  }) {
    final chapters = _extractChapters(map, fallbackComicId: fallbackComicId);
    final recommendations = _extractRecommendations(map, sourceKey: sourceKey);
    final tags = _extractTags(map, sourceKey: sourceKey);
    final detailsComicId = map['id']?.toString().trim() ?? '';

    return ComicDetailsData(
      id: detailsComicId.isEmpty ? fallbackComicId : detailsComicId,
      title: map['title']?.toString() ?? '',
      subTitle: (map['subTitle'] ?? map['subtitle'] ?? '').toString(),
      cover: map['cover']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      updateTime: _resolveUpdateTime(map['updateTime']?.toString() ?? '', tags),
      likesCount: map['likesCount']?.toString() ?? '',
      chapters: chapters,
      chapterGroups: parseChapterGroups(map['chapterGroups']),
      tags: _filterDisplayTags(tags),
      recommend: recommendations,
      isFavorite: jsAsBool(map['isFavorite']),
      isLiked: jsAsBool(map['isLiked']),
      uploader: map['uploader']?.toString() ?? '',
      pageCount: (map['pageCount'] ?? map['maxPage'] ?? '').toString(),
      subId: map['subId']?.toString() ?? '',
      sourceKey: sourceKey,
      infoFields: _extractInfoFields(map['infoFields'], sourceKey: sourceKey),
      viewsCount: map['viewsCount']?.toString() ?? '',
      headerStats: _extractHeaderStats(
        map['headerStats'],
        sourceKey: sourceKey,
      ),
    );
  }

  List<ComicHeaderStat> _extractHeaderStats(
    Object? value, {
    required String sourceKey,
  }) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('plugin_invalid_header_stats');
    }
    final stats = <ComicHeaderStat>[];
    for (final item in value) {
      if (item is! Map) {
        throw const FormatException('plugin_invalid_header_stat');
      }
      final text = item['text'];
      final Object parsedText;
      if (text is String) {
        parsedText = _translateSourceText(text.trim(), sourceKey: sourceKey);
      } else if (text is Map &&
          text.entries.every((e) => e.key is String && e.value is String)) {
        parsedText = Map<String, String>.unmodifiable(
          Map<String, String>.from(text),
        );
      } else {
        throw const FormatException('plugin_invalid_header_stat_text');
      }
      final action = item['action'] ?? 'none';
      final parsedAction = ComicHeaderStatAction.values
          .where((candidate) => candidate.name == action)
          .firstOrNull;
      if (parsedAction == null) {
        throw const FormatException('plugin_invalid_header_stat_action');
      }
      if (text is String && text.trim().isEmpty ||
          text is Map &&
              text.values.every((v) => (v as String).trim().isEmpty)) {
        continue;
      }
      stats.add(ComicHeaderStat(text: parsedText, action: parsedAction));
    }
    return List.unmodifiable(stats);
  }

  List<ComicInfoField> _extractInfoFields(
    Object? value, {
    required String sourceKey,
  }) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('plugin_invalid_info_fields');
    }
    final fields = <ComicInfoField>[];
    for (final item in value) {
      if (item is! Map) {
        throw const FormatException('plugin_invalid_info_field');
      }
      final label = item['label'];
      final Object parsedLabel;
      if (label is String && label.trim().isNotEmpty) {
        parsedLabel = _translateSourceText(label.trim(), sourceKey: sourceKey);
      } else if (label is Map &&
          label.isNotEmpty &&
          label.entries.every((e) => e.key is String && e.value is String) &&
          label.values.any((v) => (v as String).trim().isNotEmpty)) {
        parsedLabel = Map<String, String>.unmodifiable(
          Map<String, String>.from(label),
        );
      } else {
        throw const FormatException('plugin_invalid_info_field_label');
      }
      final rawValues = item['values'];
      final List<String> values;
      if (rawValues is String) {
        values = [rawValues];
      } else if (rawValues is List && rawValues.every((v) => v is String)) {
        values = rawValues.cast<String>();
      } else {
        throw const FormatException('plugin_invalid_info_field_values');
      }
      final action = item['action'] ?? 'none';
      final parsedAction = ComicInfoAction.values
          .where((candidate) => candidate.name == action)
          .firstOrNull;
      if (parsedAction == null) {
        throw const FormatException('plugin_invalid_info_field_action');
      }
      final nonempty = values.map((v) => v.trim()).where((v) => v.isNotEmpty);
      if (nonempty.isEmpty) continue;
      fields.add(
        ComicInfoField(
          label: parsedLabel,
          values: List.unmodifiable(nonempty),
          action: parsedAction,
        ),
      );
    }
    return List.unmodifiable(fields);
  }

  Map<String, String> _extractChapters(
    Map<String, dynamic> map, {
    required String fallbackComicId,
  }) {
    final groups = parseChapterGroups(map['chapterGroups']);
    if (groups.isNotEmpty) {
      return {for (final group in groups) ...group.chapters};
    }
    final chapters = <String, String>{};
    final chapterEntries = map['__chapterEntries'];
    if (chapterEntries is List) {
      for (final item in chapterEntries) {
        if (item is List && item.length >= 2) {
          final id = item[0].toString().trim();
          final title = item[1].toString().trim();
          if (id.isNotEmpty && title.isNotEmpty) chapters[id] = title;
        }
      }
    }

    if (chapters.isEmpty) {
      final chapterMap = map['chapters'];
      if (chapterMap is Map) {
        for (final entry in chapterMap.entries) {
          final id = entry.key.toString().trim();
          final title = entry.value.toString().trim();
          if (id.isNotEmpty && title.isNotEmpty) chapters[id] = title;
        }
      }
    }

    if (chapters.isEmpty && fallbackComicId.isNotEmpty) {
      chapters[fallbackComicId] = hazukiDefaultChapterTitleToken;
    }
    return chapters;
  }

  Map<String, List<String>> _extractTags(
    Map<String, dynamic> map, {
    required String sourceKey,
  }) {
    final tags = <String, List<String>>{};
    final rawTags = map['tags'];
    if (rawTags is Map) {
      for (final entry in rawTags.entries) {
        final value = entry.value;
        if (value is List) {
          tags[_translateSourceText(
            entry.key.toString(),
            sourceKey: sourceKey,
          )] = value
              .map((item) => item.toString())
              .toList();
        }
      }
    }
    return tags;
  }

  List<ExploreComic> _extractRecommendations(
    Map<String, dynamic> map, {
    required String sourceKey,
  }) {
    final recommendations = <ExploreComic>[];
    final rawRecommendations = map['recommend'];
    if (rawRecommendations is! List) return recommendations;

    for (final item in rawRecommendations) {
      if (item is! Map) continue;
      final recommendation = Map<String, dynamic>.from(item);
      final id = recommendation['id']?.toString().trim() ?? '';
      final title = recommendation['title']?.toString().trim() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      recommendations.add(
        ExploreComic(
          id: id,
          title: title,
          subTitle:
              (recommendation['subTitle'] ?? recommendation['subtitle'] ?? '')
                  .toString()
                  .trim(),
          cover: recommendation['cover']?.toString().trim() ?? '',
          sourceKey: sourceKey,
        ),
      );
    }
    return recommendations;
  }

  String _resolveUpdateTime(
    String explicitUpdateTime,
    Map<String, List<String>> tags,
  ) {
    final trimmed = explicitUpdateTime.trim();
    if (trimmed.isNotEmpty) return trimmed;
    for (final entry in tags.entries) {
      if (!_isUpdateTagKey(entry.key)) continue;
      for (final value in entry.value) {
        final text = value.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  Map<String, List<String>> _filterDisplayTags(Map<String, List<String>> tags) {
    final filtered = <String, List<String>>{};
    for (final entry in tags.entries) {
      if (!_isUpdateTagKey(entry.key)) filtered[entry.key] = entry.value;
    }
    return filtered;
  }

  bool _isUpdateTagKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == '更新' ||
        normalized == '更新时间' ||
        normalized == 'update' ||
        normalized == 'updated' ||
        normalized == 'time' ||
        normalized == 'datetime' ||
        normalized == 'datetime_updated';
  }
}

List<ComicChapterGroup> parseChapterGroups(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw const FormatException('plugin_invalid_chapter_groups');
  }
  final groups = <ComicChapterGroup>[];
  final groupIds = <String>{};
  final chapterIds = <String>{};
  for (final item in raw) {
    if (item is! Map ||
        item['id'] is! String ||
        item['title'] is! String ||
        (item['id'] as String).trim().isEmpty ||
        (item['title'] as String).trim().isEmpty ||
        item['chapters'] is! List ||
        !groupIds.add(item['id'] as String)) {
      throw const FormatException('plugin_invalid_chapter_group');
    }
    final chapters = <String, String>{};
    for (final chapter in item['chapters'] as List) {
      if (chapter is! Map ||
          chapter['id'] is! String ||
          chapter['title'] is! String ||
          (chapter['id'] as String).trim().isEmpty ||
          (chapter['title'] as String).trim().isEmpty ||
          !chapterIds.add(chapter['id'] as String)) {
        throw const FormatException('plugin_invalid_or_duplicate_chapter');
      }
      chapters[chapter['id'] as String] = chapter['title'] as String;
    }
    groups.add(
      ComicChapterGroup(
        id: item['id'] as String,
        title: item['title'] as String,
        chapters: Map.unmodifiable(chapters),
      ),
    );
  }
  return List.unmodifiable(groups);
}
