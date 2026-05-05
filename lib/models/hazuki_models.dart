enum FavoriteFolderSource { cloud, local }

enum FavoritePageMode { cloud, local }

class SourceScopedComicId {
  const SourceScopedComicId({required this.sourceKey, required this.comicId});

  static final RegExp _unsafeFileNameChars = RegExp(r'[\\/:*?"<>|]');

  factory SourceScopedComicId.fromStorageKey(
    String storageKey, {
    String fallbackSourceKey = '',
  }) {
    final normalized = storageKey.trim();
    final separatorIndex = normalized.indexOf('::');
    if (separatorIndex <= 0 || separatorIndex >= normalized.length - 2) {
      return SourceScopedComicId(
        sourceKey: fallbackSourceKey.trim(),
        comicId: normalized,
      );
    }
    return SourceScopedComicId(
      sourceKey: normalized.substring(0, separatorIndex).trim(),
      comicId: normalized.substring(separatorIndex + 2).trim(),
    );
  }

  final String sourceKey;
  final String comicId;

  String get normalizedSourceKey => sourceKey.trim();
  String get normalizedComicId => comicId.trim();

  String get storageKey {
    final source = normalizedSourceKey;
    final comic = normalizedComicId;
    if (source.isEmpty) {
      return comic;
    }
    return '$source::$comic';
  }

  String get imageCacheKey => storageKey;

  String get downloadDirName =>
      storageKey.replaceAll(_unsafeFileNameChars, '_');

  bool matchesStorageKey(String candidate) {
    final normalizedCandidate = candidate.trim();
    if (normalizedCandidate.isEmpty) {
      return false;
    }
    return normalizedCandidate == storageKey ||
        (normalizedSourceKey.isEmpty &&
            normalizedCandidate == normalizedComicId);
  }
}

extension FavoriteFolderSourceStorageExtension on FavoriteFolderSource {
  String get storageValue => switch (this) {
    FavoriteFolderSource.cloud => 'cloud',
    FavoriteFolderSource.local => 'local',
  };
}

FavoriteFolderSource favoriteFolderSourceFromStorage(String raw) {
  return switch (raw.trim()) {
    'local' => FavoriteFolderSource.local,
    _ => FavoriteFolderSource.cloud,
  };
}

class FavoriteFolderHandle {
  const FavoriteFolderHandle({required this.source, required this.id});

  final FavoriteFolderSource source;
  final String id;

  String get storageKey => '${source.storageValue}::$id';
}

FavoriteFolderHandle? favoriteFolderHandleFromStorageKey(String key) {
  final separatorIndex = key.indexOf('::');
  if (separatorIndex <= 0 || separatorIndex >= key.length - 2) {
    return null;
  }
  final sourceRaw = key.substring(0, separatorIndex);
  final id = key.substring(separatorIndex + 2).trim();
  if (id.isEmpty) {
    return null;
  }
  return FavoriteFolderHandle(
    source: favoriteFolderSourceFromStorage(sourceRaw),
    id: id,
  );
}

class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    this.source = FavoriteFolderSource.cloud,
  });

  final String id;
  final String name;
  final FavoriteFolderSource source;

  bool get isAllFolder => id == '0';

  String get storageKey => '${source.storageValue}::$id';
}

class FavoriteFoldersResult {
  const FavoriteFoldersResult.success({
    required this.folders,
    required this.favoritedFolderIds,
  }) : errorMessage = null;

  const FavoriteFoldersResult.error(this.errorMessage)
    : folders = const [],
      favoritedFolderIds = const <String>{};

  final List<FavoriteFolder> folders;
  final Set<String> favoritedFolderIds;
  final String? errorMessage;
}

class FavoriteComicsResult {
  const FavoriteComicsResult.success(this.comics, {this.maxPage})
    : errorMessage = null;

  const FavoriteComicsResult.error(this.errorMessage)
    : comics = const [],
      maxPage = null;

  final List<ExploreComic> comics;
  final int? maxPage;
  final String? errorMessage;
}

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

class CategoryTagGroup {
  const CategoryTagGroup({required this.name, required this.tags});

  final String name;
  final List<String> tags;
}

class CategoryRankingOption {
  const CategoryRankingOption({required this.value, required this.label});

  final String value;
  final String label;
}

class CategoryComicsResult {
  const CategoryComicsResult({required this.comics, required this.maxPage});

  final List<ExploreComic> comics;
  final int? maxPage;
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
  final String sourceKey;

  SourceScopedComicId get scopedId =>
      SourceScopedComicId(sourceKey: sourceKey, comicId: id);
}

class ComicCommentData {
  const ComicCommentData({
    required this.avatar,
    required this.userName,
    required this.time,
    required this.content,
    this.id,
    this.replyCount,
    this.isLiked,
    this.score,
    this.voteStatus,
  });

  final String avatar;
  final String userName;
  final String time;
  final String content;
  final String? id;
  final int? replyCount;
  final bool? isLiked;
  final int? score;
  final int? voteStatus;
}

class ComicCommentsPageResult {
  const ComicCommentsPageResult({
    required this.comments,
    required this.maxPage,
  });

  final List<ComicCommentData> comments;
  final int? maxPage;
}

class SourceMeta {
  const SourceMeta({
    required this.name,
    required this.key,
    required this.version,
    required this.supportsAccount,
    required this.settingsDefaults,
  });

  final String name;
  final String key;
  final String version;
  final bool supportsAccount;
  final Map<String, dynamic> settingsDefaults;
}
