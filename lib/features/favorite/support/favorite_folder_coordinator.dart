import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';

import 'favorite_cloud_flow.dart';

typedef FavoriteFolderContext = ({
  int generation,
  String sourceKey,
  FavoritePageMode mode,
});

typedef FavoriteFolderRequest = ({
  int generation,
  FavoriteFolderContext context,
});

/// Owns directory requests separately from comic-list requests.
/// Page state, selection and list transitions belong to the page controller.
class FavoriteFolderCoordinator {
  FavoriteFolderCoordinator({
    required FavoriteCloudFlow cloudFlow,
    required LocalFavoritesRepository localFavoritesRepository,
  }) : _cloudFlow = cloudFlow,
       _local = localFavoritesRepository;

  final FavoriteCloudFlow _cloudFlow;
  final LocalFavoritesRepository _local;
  int _contextVersion = 0;
  int _requestVersion = 0;

  FavoriteFolderContext captureContext({
    required String sourceKey,
    required FavoritePageMode mode,
  }) => (generation: _contextVersion, sourceKey: sourceKey, mode: mode);

  bool isCurrentContext(
    FavoriteFolderContext context, {
    required String sourceKey,
    required FavoritePageMode mode,
  }) =>
      context.generation == _contextVersion &&
      context.sourceKey == sourceKey &&
      context.mode == mode;

  FavoriteFolderRequest captureRequest(FavoriteFolderContext context) =>
      (generation: ++_requestVersion, context: context);

  bool isCurrentRequest(FavoriteFolderRequest request) =>
      request.generation == _requestVersion &&
      request.context.generation == _contextVersion;

  void invalidateRequests() => _requestVersion++;

  void invalidate() {
    _contextVersion++;
    invalidateRequests();
  }

  Future<FavoriteFoldersResult> load(FavoriteFolderContext context) =>
      context.mode == FavoritePageMode.local
      ? _local.loadFavoriteFolders(sourceKey: context.sourceKey)
      : _cloudFlow.loadFolders();

  Future<void> create(FavoriteFolderContext context, String name) =>
      context.mode == FavoritePageMode.local
      ? _local.addFavoriteFolder(name, sourceKey: context.sourceKey)
      : _cloudFlow.addFolder(name);

  Future<void> rename(FavoriteFolderContext context, String id, String name) =>
      context.mode == FavoritePageMode.local
      ? _local.renameFavoriteFolder(
          folderId: id,
          name: name,
          sourceKey: context.sourceKey,
        )
      : _cloudFlow.renameFolder(id, name, sourceKey: context.sourceKey);

  Future<void> delete(FavoriteFolderContext context, String id) =>
      context.mode == FavoritePageMode.local
      ? _local.deleteFavoriteFolder(id, sourceKey: context.sourceKey)
      : _cloudFlow.deleteFolder(id);
}
