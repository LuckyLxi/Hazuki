import '../models/source_task.dart';
import 'dart:async';

import '../../../models/hazuki_models.dart';
import '../debug/debug_favorites_capability.dart';
import 'source_favorites_capability.dart';

class SourceFavoritesOperations {
  SourceFavoritesOperations({
    required SourceFavoritesCapability favorites,
    required SourceFavoritesDebugCapability debug,
    required Stream<void> changedStream,
  }) : _favorites = favorites,
       _debug = debug,
       _changedStream = changedStream;

  final SourceFavoritesCapability _favorites;
  final SourceFavoritesDebugCapability _debug;
  final Stream<void> _changedStream;

  Stream<void> get changedStream => _changedStream;
  bool get favoriteSingleFolderForSingleComic =>
      _favorites.favoriteSingleFolderForSingleComic;
  bool get supportFavoriteFolderAdd => _favorites.supportFavoriteFolderAdd;
  bool get supportFavoriteFolderDelete =>
      _favorites.supportFavoriteFolderDelete;
  bool get supportFavoriteFolderRename =>
      _favorites.supportFavoriteFolderRename;
  bool get supportFavoriteFolderLoad => _favorites.supportFavoriteFolderLoad;
  bool get supportFavoriteSortOrder => _favorites.supportFavoriteSortOrder;
  bool get supportFavoriteToggle => _favorites.supportFavoriteToggle;
  String get favoriteSortOrder => _favorites.favoriteSortOrder;
  List<String> get favoriteSortOrders => _favorites.favoriteSortOrders;
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _favorites.favoriteSingleFolderForSingleComicForSource(sourceKey);
  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderAddForSource(sourceKey);
  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderDeleteForSource(sourceKey);
  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderLoadForSource(sourceKey);
  bool supportFavoriteToggleForSource(String sourceKey) =>
      _favorites.supportFavoriteToggleForSource(sourceKey);
  Future<void> setFavoriteSortOrder(String order) =>
      _favorites.setFavoriteSortOrder(order);
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.loadFavoriteComics(
    page: page,
    folderId: folderId,
    taskOrigin: taskOrigin,
  );
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.loadFavoriteFolders(
    comicId: comicId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<void> addFavoriteFolder(
    String name, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.addFavoriteFolder(
    name,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<void> deleteFavoriteFolder(
    String folderId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.deleteFavoriteFolder(
    folderId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<void> renameFavoriteFolder(
    String folderId,
    String name, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.renameFavoriteFolder(
    folderId,
    name,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    favoriteId: favoriteId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<void> warmUpFavoritesDebugInfo() => _debug.warmUpFavoritesDebugInfo();
  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  }) => _debug.collectFavoritesDebugInfo(forceRefresh: forceRefresh);
}
