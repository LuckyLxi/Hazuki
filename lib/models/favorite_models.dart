import 'explore_models.dart';

enum FavoriteFolderSource { cloud, local }

enum FavoritePageMode { cloud, local }

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
