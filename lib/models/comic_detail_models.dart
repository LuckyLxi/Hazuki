import 'explore_models.dart';
import 'source_scoped_comic_id.dart';

enum ComicInfoAction { none, search, copy }

enum ComicHeaderStatAction { none, like }

class ComicChapterGroup {
  const ComicChapterGroup({
    required this.id,
    required this.title,
    required this.chapters,
  });
  final String id;
  final String title;
  final Map<String, String> chapters;
}

/// A short plugin-defined item above the reader button, never long-form text.
class ComicHeaderStat {
  const ComicHeaderStat({
    required this.text,
    this.action = ComicHeaderStatAction.none,
  });

  final Object text;
  final ComicHeaderStatAction action;
}

/// One plugin-defined detail row. Labels may be localized language maps.
class ComicInfoField {
  const ComicInfoField({
    required this.label,
    required this.values,
    this.action = ComicInfoAction.none,
  });

  final Object label;
  final List<String> values;
  final ComicInfoAction action;
}

class ComicDetailsData {
  const ComicDetailsData({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.cover,
    required this.description,
    required this.updateTime,
    required this.likesCount,
    required this.chapters,
    required this.tags,
    required this.recommend,
    required this.isFavorite,
    required this.subId,
    this.uploader = '',
    this.pageCount = '',
    this.isLiked = false,
    this.sourceKey = '',
    this.infoFields = const [],
    this.viewsCount = '',
    this.headerStats = const [],
    this.chapterGroups = const [],
  });

  final String id;
  final String title;
  final String subTitle;
  final String cover;
  final String description;
  final String updateTime;
  final String likesCount;
  final Map<String, String> chapters;
  final List<ComicChapterGroup> chapterGroups;

  ComicChapterGroup? groupForChapter(String id) => chapterGroups
      .where((group) => group.chapters.containsKey(id))
      .firstOrNull;
  final Map<String, List<String>> tags;
  final List<ExploreComic> recommend;
  final bool isFavorite;
  final String subId;
  final String uploader;
  final String pageCount;
  final bool isLiked;
  final String sourceKey;
  final List<ComicInfoField> infoFields;
  final String viewsCount;
  final List<ComicHeaderStat> headerStats;

  SourceScopedComicId get scopedId =>
      SourceScopedComicId(sourceKey: sourceKey, comicId: id);

  ComicDetailsData copyWith({
    String? id,
    String? title,
    String? subTitle,
    String? cover,
    String? description,
    String? updateTime,
    String? likesCount,
    Map<String, String>? chapters,
    List<ComicChapterGroup>? chapterGroups,
    Map<String, List<String>>? tags,
    List<ExploreComic>? recommend,
    bool? isFavorite,
    String? subId,
    String? uploader,
    String? pageCount,
    bool? isLiked,
    String? sourceKey,
    List<ComicInfoField>? infoFields,
    String? viewsCount,
    List<ComicHeaderStat>? headerStats,
  }) {
    return ComicDetailsData(
      id: id ?? this.id,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      cover: cover ?? this.cover,
      description: description ?? this.description,
      updateTime: updateTime ?? this.updateTime,
      likesCount: likesCount ?? this.likesCount,
      chapters: chapters ?? this.chapters,
      chapterGroups: chapterGroups ?? this.chapterGroups,
      tags: tags ?? this.tags,
      recommend: recommend ?? this.recommend,
      isFavorite: isFavorite ?? this.isFavorite,
      subId: subId ?? this.subId,
      uploader: uploader ?? this.uploader,
      pageCount: pageCount ?? this.pageCount,
      isLiked: isLiked ?? this.isLiked,
      sourceKey: sourceKey ?? this.sourceKey,
      infoFields: infoFields ?? this.infoFields,
      viewsCount: viewsCount ?? this.viewsCount,
      headerStats: headerStats ?? this.headerStats,
    );
  }
}
