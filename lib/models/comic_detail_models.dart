import 'explore_models.dart';
import 'source_scoped_comic_id.dart';

enum ComicInfoAction { none, search, copy }

/// `plugin` 回调插件的 `comic.onHeaderAction`；点赞等有状态按钮也由插件自行处理。
enum ComicHeaderStatAction { none, plugin, link, search, copy }

enum ComicHeaderBadgeTone { normal, primary, warning, error }

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
    this.icon,
    this.action = ComicHeaderStatAction.none,
    this.actionId = '',
    this.url = '',
    this.value,
  });

  final Object text;

  /// 内置图标名；宿主不认识的名称不显示图标。
  final String? icon;
  final ComicHeaderStatAction action;

  /// `plugin` 动作传给 `onHeaderAction` 的标识。
  final String actionId;

  /// `link` 动作打开的 http(s) 地址。
  final String url;

  /// `search` / `copy` 的目标文字；为空时使用显示文字。
  final String? value;
}

/// 标题下方的短标签，例如「连载中」「付费」。
class ComicHeaderBadge {
  const ComicHeaderBadge({
    required this.text,
    this.tone = ComicHeaderBadgeTone.normal,
  });

  final Object text;
  final ComicHeaderBadgeTone tone;
}

/// `onHeaderAction` 的返回：替换顶部内容，或要求重新加载详情。
class ComicHeaderActionResult {
  const ComicHeaderActionResult({
    this.headerStats,
    this.headerBadges,
    this.reload = false,
  });

  final List<ComicHeaderStat>? headerStats;
  final List<ComicHeaderBadge>? headerBadges;
  final bool reload;
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
    this.sourceKey = '',
    this.infoFields = const [],
    this.viewsCount = '',
    this.headerStats = const [],
    this.headerBadges = const [],
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
  final String sourceKey;
  final List<ComicInfoField> infoFields;
  final String viewsCount;
  final List<ComicHeaderStat> headerStats;
  final List<ComicHeaderBadge> headerBadges;

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
    String? sourceKey,
    List<ComicInfoField>? infoFields,
    String? viewsCount,
    List<ComicHeaderStat>? headerStats,
    List<ComicHeaderBadge>? headerBadges,
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
      sourceKey: sourceKey ?? this.sourceKey,
      infoFields: infoFields ?? this.infoFields,
      viewsCount: viewsCount ?? this.viewsCount,
      headerStats: headerStats ?? this.headerStats,
      headerBadges: headerBadges ?? this.headerBadges,
    );
  }
}
