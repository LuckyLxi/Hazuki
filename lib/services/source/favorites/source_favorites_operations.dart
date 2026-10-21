import '../models/source_task.dart';
import 'dart:async';

import '../../../models/hazuki_models.dart';
import '../debug/debug_favorites_capability.dart';
import 'source_favorites_capability.dart';

abstract interface class SourceFavoritesOperations {
  Stream<void> get changedStream;
  bool get favoriteSingleFolderForSingleComic;
  bool get supportFavoriteFolderAdd;
  bool get supportFavoriteFolderDelete;
  bool get supportFavoriteFolderRename;
  bool get supportFavoriteFolderLoad;
  bool get supportFavoriteSortOrder;
  bool get supportFavoriteToggle;
  String get favoriteSortOrder;
  List<String> get favoriteSortOrders;
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey);
  bool supportFavoriteFolderAddForSource(String sourceKey);
  bool supportFavoriteFolderDeleteForSource(String sourceKey);
  bool supportFavoriteFolderLoadForSource(String sourceKey);
  bool supportFavoriteToggleForSource(String sourceKey);
  Future<void> setFavoriteSortOrder(String order);
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
    SourceTaskOrigin? taskOrigin,
  });
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> addFavoriteFolder(
    String name, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> deleteFavoriteFolder(
    String folderId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> renameFavoriteFolder(
    String folderId,
    String name, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> warmUpFavoritesDebugInfo();
  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  });
}

class SourceFavoritesOperationService implements SourceFavoritesOperations {
  SourceFavoritesOperationService({
    required SourceFavoritesCapability favorites,
    required SourceFavoritesDebugCapability debug,
    required Stream<void> changedStream,
  }) : _favorites = favorites,
       _debug = debug,
       _changedStream = changedStream;

  final SourceFavoritesCapability _favorites;
  final SourceFavoritesDebugCapability _debug;
  final Stream<void> _changedStream;

  @override
  Stream<void> get changedStream => _changedStream;
  @override
  bool get favoriteSingleFolderForSingleComic =>
      _favorites.favoriteSingleFolderForSingleComic;
  @override
  bool get supportFavoriteFolderAdd => _favorites.supportFavoriteFolderAdd;
  @override
  bool get supportFavoriteFolderDelete =>
      _favorites.supportFavoriteFolderDelete;
  @override
  bool get supportFavoriteFolderRename =>
      _favorites.supportFavoriteFolderRename;
  @override
  bool get supportFavoriteFolderLoad => _favorites.supportFavoriteFolderLoad;
  @override
  bool get supportFavoriteSortOrder => _favorites.supportFavoriteSortOrder;
  @override
  bool get supportFavoriteToggle => _favorites.supportFavoriteToggle;
  @override
  String get favoriteSortOrder => _favorites.favoriteSortOrder;
  @override
  List<String> get favoriteSortOrders => _favorites.favoriteSortOrders;
  @override
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _favorites.favoriteSingleFolderForSingleComicForSource(sourceKey);
  @override
  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderAddForSource(sourceKey);
  @override
  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderDeleteForSource(sourceKey);
  @override
  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderLoadForSource(sourceKey);
  @override
  bool supportFavoriteToggleForSource(String sourceKey) =>
      _favorites.supportFavoriteToggleForSource(sourceKey);
  @override
  Future<void> setFavoriteSortOrder(String order) =>
      _favorites.setFavoriteSortOrder(order);
  @override
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.loadFavoriteComics(
    page: page,
    folderId: folderId,
    taskOrigin: taskOrigin,
  );
  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.loadFavoriteFolders(
    comicId: comicId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> addFavoriteFolder(
    String name, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.addFavoriteFolder(
    name,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> deleteFavoriteFolder(
    String folderId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _favorites.deleteFavoriteFolder(
    folderId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
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
  @override
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
  @override
  Future<void> warmUpFavoritesDebugInfo() => _debug.warmUpFavoritesDebugInfo();
  @override
  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  }) => _debug.collectFavoritesDebugInfo(forceRefresh: forceRefresh);
}
