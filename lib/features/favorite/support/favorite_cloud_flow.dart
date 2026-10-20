import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';

import '../state/favorite_folder_state.dart' show defaultCloudFavoriteFolder;

class FavoriteCloudFlow {
  FavoriteCloudFlow(this.sourceService);

  final _sourceUi = SourceUiOwner();
  void dispose() => _sourceUi.dispose();
  void cancel() => _sourceUi.restart();
  Future<T> run<T>(Future<T> Function() operation) => _sourceUi.run(operation);

  final SourceFavoriteGateway sourceService;

  bool get isLogged => sourceService.isLogged;
  bool get supportsFolderDelete => sourceService.supportFavoriteFolderDelete;
  bool get supportsFolderRename => sourceService.supportFavoriteFolderRename;
  bool get supportsFolderAdd => sourceService.supportFavoriteFolderAdd;
  bool get supportsFolderLoad => sourceService.supportFavoriteFolderLoad;
  bool get supportsSortOrder => sourceService.supportFavoriteSortOrder;
  String get currentSortOrder => sourceService.favoriteSortOrder;
  List<String> get sortOrders => sourceService.favoriteSortOrders;

  Future<void> ensureInitialized() {
    return _sourceUi.run(sourceService.ensureInitialized);
  }

  Future<FavoriteFoldersResult> loadFolders() {
    return _sourceUi.run(sourceService.loadFavoriteFolders);
  }

  Future<FavoriteComicsResult> loadPage({
    required int page,
    required String folderId,
    required String timeoutMessage,
    required Duration timeout,
  }) {
    final targetFolderId = folderId.trim().isEmpty ? '0' : folderId.trim();
    return _sourceUi.run(
      () => SourceUiScope.timeout(
        sourceService.loadFavoriteComics(page: page, folderId: targetFolderId),
        timeout,
        onTimeout: () => FavoriteComicsResult.error(timeoutMessage),
      ),
    );
  }

  Future<void> addFolder(String name) {
    return _sourceUi.run(() => sourceService.addFavoriteFolder(name));
  }

  Future<void> deleteFolder(String folderId) {
    return _sourceUi.run(() => sourceService.deleteFavoriteFolder(folderId));
  }

  Future<void> renameFolder(
    String folderId,
    String name, {
    required String sourceKey,
  }) {
    return _sourceUi.run(
      () => sourceService.renameFavoriteFolder(
        folderId,
        name,
        sourceKey: sourceKey,
      ),
    );
  }

  Future<void> setSortOrder(String order) {
    return _sourceUi.run(() => sourceService.setFavoriteSortOrder(order));
  }

  List<FavoriteFolder> normalizeFolders(FavoriteFoldersResult result) {
    if (result.folders.isEmpty) {
      return const <FavoriteFolder>[defaultCloudFavoriteFolder];
    }
    return result.folders;
  }
}
