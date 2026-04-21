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

  Future<FavoriteFoldersResult> loadFolders() {
    return localFavoritesService.loadFavoriteFolders();
  }

  Future<FavoriteComicsResult> loadPage({
    required int page,
    required String folderId,
    required String sortOrder,
  }) {
    return localFavoritesService.loadFavoriteComics(
      page: page,
      folderId: folderId.trim(),
      sortOrder: sortOrder,
    );
  }

  Future<void> addFolder(String name) {
    return localFavoritesService.addFavoriteFolder(name);
  }

  Future<void> renameFolder({required String folderId, required String name}) {
    return localFavoritesService.renameFavoriteFolder(
      folderId: folderId,
      name: name,
    );
  }

  Future<void> deleteFolder(String folderId) {
    return localFavoritesService.deleteFavoriteFolder(folderId);
  }
}
