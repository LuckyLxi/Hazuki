import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites_service.dart';

class FavoriteLocalFlow {
  const FavoriteLocalFlow(this.localFavoritesService);

  final LocalFavoritesService localFavoritesService;

  Future<String> loadSortOrder() {
    return localFavoritesService.loadSortOrder();
  }

  Future<void> saveSortOrder(String order) {
    return localFavoritesService.saveSortOrder(order);
  }

  Future<FavoritePageMode> loadFavoritePageMode() {
    return localFavoritesService.loadFavoritePageMode();
  }

  Future<void> saveFavoritePageMode(FavoritePageMode mode) {
    return localFavoritesService.saveFavoritePageMode(mode);
  }

  Future<String> loadSelectedFolderId(FavoritePageMode mode) {
    return localFavoritesService.loadSelectedFavoriteFolderId(mode);
  }

  Future<void> saveSelectedFolderId(FavoritePageMode mode, String folderId) {
    return localFavoritesService.saveSelectedFavoriteFolderId(mode, folderId);
  }

  Future<FavoriteFoldersResult> loadFolders() {
    return localFavoritesService.loadFavoriteFolders();
  }

  Future<FavoriteFoldersResult> loadFoldersForSource(String sourceKey) {
    return localFavoritesService.loadFavoriteFolders(sourceKey: sourceKey);
  }

  Future<FavoriteComicsResult> loadPage({
    required int page,
    required String folderId,
    required String sortOrder,
    String sourceKey = '',
  }) {
    return localFavoritesService.loadFavoriteComics(
      page: page,
      folderId: folderId.trim(),
      sortOrder: sortOrder,
      sourceKey: sourceKey,
    );
  }

  Future<void> addFolder(String name, {String sourceKey = ''}) {
    return localFavoritesService.addFavoriteFolder(name, sourceKey: sourceKey);
  }

  Future<void> renameFolder({
    required String folderId,
    required String name,
    String sourceKey = '',
  }) {
    return localFavoritesService.renameFavoriteFolder(
      folderId: folderId,
      name: name,
      sourceKey: sourceKey,
    );
  }

  Future<void> deleteFolder(String folderId, {String sourceKey = ''}) {
    return localFavoritesService.deleteFavoriteFolder(
      folderId,
      sourceKey: sourceKey,
    );
  }
}
