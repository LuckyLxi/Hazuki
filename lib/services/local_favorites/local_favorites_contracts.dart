import 'package:flutter/foundation.dart';

import '../../models/hazuki_models.dart';

abstract interface class LocalFavoritesRepository implements Listenable {
  void onExternalDataChanged();

  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  });
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
    String sortOrder = 'mr',
    String sourceKey = '',
  });
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''});
  Future<void> renameFavoriteFolder({
    required String folderId,
    required String name,
    String sourceKey = '',
  });
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''});
  Future<void> toggleFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  });
  Future<bool> isComicFavorited(String comicId, {String sourceKey = ''});
}

abstract interface class LocalFavoritesSyncStore {
  Future<String> exportFoldersJsonString();
  Future<String> exportEntriesJsonString();
  Future<String> exportFolderTombstonesJsonString();
  Future<String> exportEntryTombstonesJsonString();
  Future<String> exportComicFolderTombstonesJsonString();
  Future<void> importJsonStrings({
    String? foldersRaw,
    String? entriesRaw,
    String? folderTombstonesRaw,
    String? entryTombstonesRaw,
    String? comicFolderTombstonesRaw,
    required bool replace,
  });
}
