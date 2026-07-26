import 'source_scoped_comic_id.dart';

class ExploreSection {
  const ExploreSection({
    required this.title,
    required this.comics,
    this.viewMoreUrl,
    this.maxPage,
  });

  final String title;
  final List<ExploreComic> comics;

  /// jm.js 专栏 viewMore 字段，如 "category:禁漫天堂@0"，可用于分页加载更多
  final String? viewMoreUrl;

  final int? maxPage;

  ExploreSection copyWith({
    String? title,
    List<ExploreComic>? comics,
    String? viewMoreUrl,
    int? maxPage,
  }) {
    return ExploreSection(
      title: title ?? this.title,
      comics: comics ?? this.comics,
      viewMoreUrl: viewMoreUrl ?? this.viewMoreUrl,
      maxPage: maxPage ?? this.maxPage,
    );
  }
}

class ExploreComic {
  const ExploreComic({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.cover,
    this.sourceKey = '',
    this.tags = const [],
  });

  final String id;
  final String title;
  final String subTitle;
  final String cover;
  final String sourceKey;
  final List<String> tags;

  ExploreComic copyWith({List<String>? tags}) => ExploreComic(
    id: id,
    title: title,
    subTitle: subTitle,
    cover: cover,
    sourceKey: sourceKey,
    tags: tags ?? this.tags,
  );

  SourceScopedComicId get scopedId =>
      SourceScopedComicId(sourceKey: sourceKey, comicId: id);
}

class SearchComicsResult {
  const SearchComicsResult({required this.comics, required this.maxPage});

  final List<ExploreComic> comics;
  final int? maxPage;
}
