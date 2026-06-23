import 'package:hazuki/models/hazuki_models.dart';

/// Feature-neutral contract for editing cloud and local favorite folders.
abstract interface class FavoriteFoldersRepository {
  bool get isLogged;
  bool get supportFavoriteFolderLoad;
  bool get supportFavoriteFolderAdd;
  bool get supportFavoriteFolderDelete;
  bool get supportFavoriteToggle;
  bool get favoriteSingleFolderForSingleComic;

  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  });

  Future<void> addCloudFavoriteFolder(String name);
  Future<void> deleteCloudFavoriteFolder(String id);

  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  });

  Future<void> addLocalFavoriteFolder(String name, {String sourceKey = ''});
  Future<void> deleteLocalFavoriteFolder(String id, {String sourceKey = ''});

  Future<void> toggleCloudFavorite({
    required String comicId,
    required bool isAdding,
    required String folderId,
  });

  Future<void> toggleLocalFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  });
}
