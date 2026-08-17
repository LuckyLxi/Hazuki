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
      tags: _filterDisplayTags(tags),
      recommend: recommendations,
      isFavorite: jsAsBool(map['isFavorite']),
      isLiked: jsAsBool(map['isLiked']),
      uploader: map['uploader']?.toString() ?? '',
      pageCount: (map['pageCount'] ?? map['maxPage'] ?? '').toString(),
      subId: map['subId']?.toString() ?? '',
      sourceKey: sourceKey,
    );
  }

  Map<String, String> _extractChapters(
    Map<String, dynamic> map, {
    required String fallbackComicId,
  }) {
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
