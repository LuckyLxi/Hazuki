import 'explore_models.dart';
import 'source_scoped_comic_id.dart';

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
  });

  final String id;
  final String title;
  final String subTitle;
  final String cover;
  final String description;
  final String updateTime;
  final String likesCount;
  final Map<String, String> chapters;
  final Map<String, List<String>> tags;
  final List<ExploreComic> recommend;
  final bool isFavorite;
  final String subId;
  final String uploader;
  final String pageCount;
  final bool isLiked;
  final String sourceKey;

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
    Map<String, List<String>>? tags,
    List<ExploreComic>? recommend,
    bool? isFavorite,
    String? subId,
    String? uploader,
    String? pageCount,
    bool? isLiked,
    String? sourceKey,
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
      tags: tags ?? this.tags,
      recommend: recommend ?? this.recommend,
      isFavorite: isFavorite ?? this.isFavorite,
      subId: subId ?? this.subId,
      uploader: uploader ?? this.uploader,
      pageCount: pageCount ?? this.pageCount,
      isLiked: isLiked ?? this.isLiked,
      sourceKey: sourceKey ?? this.sourceKey,
    );
  }
}
