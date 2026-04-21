import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import '../state/favorite_page_state.dart';

class FavoriteCloudFlow {
  const FavoriteCloudFlow(this.sourceService);

  final HazukiSourceService sourceService;

  bool get isLogged => sourceService.isLogged;
  bool get supportsFolderDelete => sourceService.supportFavoriteFolderDelete;
  bool get supportsFolderAdd => sourceService.supportFavoriteFolderAdd;
  bool get supportsFolderLoad => sourceService.supportFavoriteFolderLoad;
  bool get supportsSortOrder => sourceService.supportFavoriteSortOrder;
  String get currentSortOrder => sourceService.favoriteSortOrder;

  Future<void> ensureInitialized() {
    return sourceService.ensureInitialized();
  }

  Future<FavoriteFoldersResult> loadFolders() {
    return sourceService.loadFavoriteFolders();
  }

  Future<FavoriteComicsResult> loadPage({
    required int page,
    required String folderId,
    required String timeoutMessage,
    required Duration timeout,
  }) {
    final targetFolderId = folderId.trim().isEmpty ? '0' : folderId.trim();
    return sourceService
        .loadFavoriteComics(page: page, folderId: targetFolderId)
        .timeout(
          timeout,
          onTimeout: () => FavoriteComicsResult.error(timeoutMessage),
        );
  }

  Future<void> addFolder(String name) {
    return sourceService.addFavoriteFolder(name);
  }

  Future<void> deleteFolder(String folderId) {
    return sourceService.deleteFavoriteFolder(folderId);
  }

  Future<void> setSortOrder(String order) {
    return sourceService.setFavoriteSortOrder(order);
  }

  List<FavoriteFolder> normalizeFolders(FavoriteFoldersResult result) {
    if (result.folders.isEmpty) {
      return const <FavoriteFolder>[defaultCloudFavoriteFolder];
    }
    return result.folders;
  }
}
