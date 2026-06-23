import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';

class FavoriteLocalFlow {
  const FavoriteLocalFlow({
    required this.repository,
    required this.preferences,
  });

  final LocalFavoritesRepository repository;
  final LocalFavoritesPreferencesStore preferences;

  Future<String> loadSortOrder() {
    return preferences.loadSortOrder();
  }

  Future<void> saveSortOrder(String order) {
    return preferences.saveSortOrder(order);
  }

  Future<FavoritePageMode> loadFavoritePageMode({String sourceKey = ''}) {
    return preferences.loadFavoritePageMode(sourceKey: sourceKey);
  }

  Future<void> saveFavoritePageMode(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) {
    return preferences.saveFavoritePageMode(mode, sourceKey: sourceKey);
  }

  Future<String> loadSelectedFolderId(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) {
    return preferences.loadSelectedFavoriteFolderId(mode, sourceKey: sourceKey);
  }

  Future<void> saveSelectedFolderId(
    FavoritePageMode mode,
    String folderId, {
    String sourceKey = '',
  }) {
    return preferences.saveSelectedFavoriteFolderId(
      mode,
      folderId,
      sourceKey: sourceKey,
    );
  }

  Future<FavoriteFoldersResult> loadFolders() {
    return repository.loadFavoriteFolders();
  }

  Future<FavoriteFoldersResult> loadFoldersForSource(String sourceKey) {
    return repository.loadFavoriteFolders(sourceKey: sourceKey);
  }

  Future<FavoriteComicsResult> loadPage({
    required int page,
    required String folderId,
    required String sortOrder,
    String sourceKey = '',
  }) {
    return repository.loadFavoriteComics(
      page: page,
      folderId: folderId.trim(),
      sortOrder: sortOrder,
      sourceKey: sourceKey,
    );
  }

  Future<void> addFolder(String name, {String sourceKey = ''}) {
    return repository.addFavoriteFolder(name, sourceKey: sourceKey);
  }

  Future<void> renameFolder({
    required String folderId,
    required String name,
    String sourceKey = '',
  }) {
    return repository.renameFavoriteFolder(
      folderId: folderId,
      name: name,
      sourceKey: sourceKey,
    );
  }

  Future<void> deleteFolder(String folderId, {String sourceKey = ''}) {
    return repository.deleteFavoriteFolder(folderId, sourceKey: sourceKey);
  }
}
