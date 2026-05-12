import 'source_scoped_comic_id.dart';

class ExploreSection {
  const ExploreSection({
    required this.title,
    required this.comics,
    this.viewMoreUrl,
  });

  final String title;
  final List<ExploreComic> comics;

  /// jm.js 专栏 viewMore 字段，如 "category:禁漫天堂@0"，可用于分页加载更多
  final String? viewMoreUrl;
}

class ExploreComic {
  const ExploreComic({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.cover,
    this.sourceKey = '',
  });

  final String id;
  final String title;
  final String subTitle;
  final String cover;
  final String sourceKey;

  SourceScopedComicId get scopedId =>
      SourceScopedComicId(sourceKey: sourceKey, comicId: id);
}

class SearchComicsResult {
  const SearchComicsResult({required this.comics, required this.maxPage});

  final List<ExploreComic> comics;
  final int? maxPage;
}
