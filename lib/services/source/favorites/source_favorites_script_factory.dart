import 'dart:convert';

/// Builds safely encoded JavaScript calls for source favorite operations.
class SourceFavoritesScriptFactory {
  const SourceFavoritesScriptFactory();

  String loadComics({required int page, required String? folderId}) {
    return 'this.__hazuki_source.favorites.loadComics('
        '$page, ${jsonEncode(folderId)})';
  }

  String loadNext({required String? cursor, required String folderId}) {
    return 'this.__hazuki_source.favorites.loadNext('
        '${jsonEncode(cursor)}, ${jsonEncode(folderId)})';
  }

  String loadFolders(String? comicId) {
    return 'this.__hazuki_source.favorites.loadFolders('
        '${jsonEncode(comicId)})';
  }

  String addFolder(String name) {
    return 'this.__hazuki_source.favorites.addFolder(${jsonEncode(name)})';
  }

  String deleteFolder(String folderId) {
    return 'this.__hazuki_source.favorites.deleteFolder('
        '${jsonEncode(folderId)})';
  }

  String toggleFavorite({
    required String comicId,
    required String folderId,
    required bool isAdding,
    required String? favoriteId,
  }) {
    return 'this.__hazuki_source.favorites.addOrDelFavorite('
        '${jsonEncode(comicId)}, ${jsonEncode(folderId)}, '
        '$isAdding, ${jsonEncode(favoriteId)})';
  }
}
