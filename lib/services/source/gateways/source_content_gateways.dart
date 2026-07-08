import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';

abstract interface class SourceSearchGateway implements Listenable {
  String get activeSourceKey;
  bool get isActiveJmSource;
  SourceRuntimeState get sourceRuntimeState;
  List<SourceCatalogEntry> get allowedSources;

  void logRuntimeRetryRequested(String source);
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  });
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  });
}

abstract interface class SourceDiscoverGateway implements Listenable {
  String get activeSourceKey;
  bool get isLogged;
  SourceRuntimeState get sourceRuntimeState;

  void logRuntimeRetryRequested(String source);
  Future<List<ExploreSection>> loadExploreSections({bool forceRefresh = false});
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  });
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  });
}

abstract interface class SourceCategoryGateway {
  bool get softwareLogCaptureEnabled;
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  });
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions();
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  });
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  });
}

abstract interface class SourceCommentsGateway {
  bool get isLogged;
  bool get supportCommentSend;
  bool get supportCommentLike;
  bool isLoggedForSource(String sourceKey);
  bool supportCommentSendForSource(String sourceKey);
  bool supportCommentLikeForSource(String sourceKey);
  bool supportCommentRepliesForSource(String sourceKey);
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  });
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  });
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  });
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  });
}

abstract interface class SourceComicDetailGateway {
  String get activeSourceKey;
  bool isLoggedForSource(String sourceKey);
  bool supportFavoriteFolderLoadForSource(String sourceKey);
  bool supportFavoriteFolderAddForSource(String sourceKey);
  bool supportFavoriteFolderDeleteForSource(String sourceKey);
  bool supportFavoriteToggleForSource(String sourceKey);
  bool supportComicLikeForSource(String sourceKey);
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey);
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  });
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  });
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  });
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  });
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
    String sourceKey = '',
  });
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  });
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''});
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''});
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  });
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  });
}

abstract interface class SourceFavoriteGateway implements Listenable {
  String get activeSourceKey;
  bool get isLogged;
  bool get supportFavoriteFolderDelete;
  bool get supportFavoriteFolderAdd;
  bool get supportFavoriteFolderLoad;
  bool get supportFavoriteSortOrder;
  bool get supportFavoriteToggle;
  bool get favoriteSingleFolderForSingleComic;
  String get favoriteSortOrder;
  List<String> get favoriteSortOrders;
  Stream<void> get cloudFavoritesChangedStream;
  SourceRuntimeState get sourceRuntimeState;

  void logRuntimeRetryRequested(String source);
  Future<void> ensureInitialized();
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  });
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  });
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''});
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''});
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  });
  Future<void> setFavoriteSortOrder(String order);
}

abstract interface class SourceReaderGateway {
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  });
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  });
  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  });
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  });
  bool isLocalImagePath(String value);
  String normalizeLocalImagePath(String value);
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  });
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  });
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  });
}
