import '../plugins/source_search_capabilities.dart';
import '../plugins/source_sort_options.dart';
import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';
import '../models/source_task.dart';

abstract interface class SourceSearchGateway implements Listenable {
  String? get activeSourceKey;
  bool get supportsDirectComicId;
  DirectComicIdRules? directComicIdRulesForSource(String sourceKey);
  SourceRuntimeState get runtimeState;
  List<SourceCatalogEntry> get allowedSources;

  void logRuntimeRetryRequested(String source);
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = '',
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
}

abstract interface class SourceDiscoverGateway implements Listenable {
  bool? get requiresLogin;
  String? get sourceRevision;
  String? get activeSourceKey;
  bool get isLogged;
  SourceRuntimeState get runtimeState;

  void logRuntimeRetryRequested(String source);
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  });
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
    SourceTaskOrigin? taskOrigin,
  });
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = '',
    List<String>? orders,
    SourceTaskOrigin? taskOrigin,
  });
}

abstract interface class SourceCategoryGateway {
  bool get softwareLogCaptureEnabled;
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions({
    SourceTaskOrigin? taskOrigin,
  });
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
    SourceTaskOrigin? taskOrigin,
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
  SourceCommentSortOptions commentSortOptionsForSource(String sourceKey);
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
    String order = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
    SourceTaskOrigin? taskOrigin,
  });
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  });
}

abstract interface class SourceComicDetailGateway {
  String? get activeSourceKey;
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
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  });
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
    String sourceKey = '',
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
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
}

abstract interface class SourceFavoriteGateway implements Listenable {
  String? get activeSourceKey;
  bool get isLogged;
  bool get supportFavoriteFolderDelete;
  bool get supportFavoriteFolderRename;
  bool get supportFavoriteFolderAdd;
  bool get supportFavoriteFolderLoad;
  bool get supportFavoriteSortOrder;
  bool get supportFavoriteToggle;
  bool get favoriteSingleFolderForSingleComic;
  String get favoriteSortOrder;
  List<String> get favoriteSortOrders;
  Stream<void> get cloudFavoritesChangedStream;
  SourceRuntimeState get runtimeState;

  void logRuntimeRetryRequested(String source);
  Future<void> ensureInitialized();
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
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
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> setFavoriteSortOrder(String order);
  Future<void> renameFavoriteFolder(
    String folderId,
    String name, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
}

abstract interface class SourceReaderGateway {
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
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

/// Optional extension for production readers; offline/fake readers need no lease.
abstract interface class SourceReaderSessionGateway {
  SourceReaderSession acquireReaderSession(String sourceKey);
}

/// Optional download lifetime extension; offline/fake readers need no lease.
abstract interface class SourceDownloadSessionGateway {
  SourceDownloadSession acquireDownloadSession(String sourceKey);
}

/// Optional reader extension; old gateway implementations remain valid.
abstract interface class SourceReadingProgressGateway {
  Future<void> reportReadingProgress(
    Map<String, Object> progress, {
    required String sourceKey,
    SourceTaskOrigin? taskOrigin,
  });
}
