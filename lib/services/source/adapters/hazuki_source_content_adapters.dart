import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../../hazuki_source_service.dart';
import '../gateways/source_content_gateways.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceSearchAdapter extends HazukiSourceListenableAdapter
    implements SourceSearchGateway {
  const HazukiSourceSearchAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isActiveJmSource => source.isActiveJmSource;
  @override
  SourceRuntimeState get sourceRuntimeState => source.sourceRuntimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      source.runtimeRegistry.allowedSources;
  @override
  void logRuntimeRetryRequested(String value) =>
      source.logRuntimeRetryRequested(value);
  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) => source.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
  );
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => source.loadComicDetails(comicId, sourceKey: sourceKey);
}

class HazukiSourceDiscoverAdapter extends HazukiSourceListenableAdapter
    implements SourceDiscoverGateway {
  const HazukiSourceDiscoverAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isLogged => source.isLogged;
  @override
  SourceRuntimeState get sourceRuntimeState => source.sourceRuntimeState;
  @override
  void logRuntimeRetryRequested(String value) =>
      source.logRuntimeRetryRequested(value);
  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) => source.loadExploreSections(forceRefresh: forceRefresh);
  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) => source.loadCategoryOptionGroupsByViewMore(viewMoreUrl: viewMoreUrl);
  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) => source.loadCategoryComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
  );
}

class HazukiSourceCategoryAdapter extends HazukiSourceAdapterBase
    implements SourceCategoryGateway {
  const HazukiSourceCategoryAdapter(super.source);

  @override
  bool get softwareLogCaptureEnabled => source.softwareLogCaptureEnabled;
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) => source.loadCategoryTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
  );
  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() =>
      source.loadCategoryRankingOptions();
  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) => source.loadCategoryRankingComics(
    rankingOption: rankingOption,
    page: page,
  );
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => this.source.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
}

class HazukiSourceCommentsAdapter extends HazukiSourceAdapterBase
    implements SourceCommentsGateway {
  const HazukiSourceCommentsAdapter(super.source);

  @override
  bool get isLogged => source.isLogged;
  @override
  bool get supportCommentSend => source.supportCommentSend;
  @override
  bool get supportCommentLike => source.supportCommentLike;
  @override
  bool isLoggedForSource(String sourceKey) =>
      source.isLoggedForSource(sourceKey);
  @override
  bool supportCommentSendForSource(String sourceKey) =>
      source.supportCommentSendForSource(sourceKey);
  @override
  bool supportCommentLikeForSource(String sourceKey) =>
      source.supportCommentLikeForSource(sourceKey);
  @override
  bool supportCommentRepliesForSource(String sourceKey) =>
      source.supportCommentRepliesForSource(sourceKey);
  @override
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) => source.loadCommentsPage(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
  );
  @override
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) => source.sendComment(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    content: content,
    replyTo: replyTo,
  );
  @override
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) => source.likeComment(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    commentId: commentId,
    isLike: isLike,
  );
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => this.source.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
}

class HazukiSourceComicDetailAdapter extends HazukiSourceAdapterBase
    implements SourceComicDetailGateway {
  const HazukiSourceComicDetailAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool isLoggedForSource(String sourceKey) =>
      source.isLoggedForSource(sourceKey);
  @override
  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      source.supportFavoriteFolderLoadForSource(sourceKey);
  @override
  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      source.supportFavoriteFolderAddForSource(sourceKey);
  @override
  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      source.supportFavoriteFolderDeleteForSource(sourceKey);
  @override
  bool supportFavoriteToggleForSource(String sourceKey) =>
      source.supportFavoriteToggleForSource(sourceKey);
  @override
  bool supportComicLikeForSource(String sourceKey) =>
      source.supportComicLikeForSource(sourceKey);
  @override
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      source.favoriteSingleFolderForSingleComicForSource(sourceKey);
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => source.loadComicDetails(comicId, sourceKey: sourceKey);
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) => source.loadCategoryTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
  );
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    String sourceKey = '',
  }) => source.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    sourceKey: sourceKey,
  );
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => source.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
  );
  @override
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
    String sourceKey = '',
  }) => source.prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
    sourceKey: sourceKey,
  );
  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) => source.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);
  @override
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) =>
      source.addFavoriteFolder(name, sourceKey: sourceKey);
  @override
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) =>
      source.deleteFavoriteFolder(folderId, sourceKey: sourceKey);
  @override
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) => source.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    favoriteId: favoriteId,
    sourceKey: sourceKey,
  );
  @override
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) => source.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
  );
}

class HazukiSourceFavoriteAdapter extends HazukiSourceListenableAdapter
    implements SourceFavoriteGateway {
  const HazukiSourceFavoriteAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isLogged => source.isLogged;
  @override
  bool get supportFavoriteFolderDelete => source.supportFavoriteFolderDelete;
  @override
  bool get supportFavoriteFolderAdd => source.supportFavoriteFolderAdd;
  @override
  bool get supportFavoriteFolderLoad => source.supportFavoriteFolderLoad;
  @override
  bool get supportFavoriteSortOrder => source.supportFavoriteSortOrder;
  @override
  bool get supportFavoriteToggle => source.supportFavoriteToggle;
  @override
  bool get favoriteSingleFolderForSingleComic =>
      source.favoriteSingleFolderForSingleComic;
  @override
  String get favoriteSortOrder => source.favoriteSortOrder;
  @override
  List<String> get favoriteSortOrders => source.favoriteSortOrders;
  @override
  Stream<void> get cloudFavoritesChangedStream =>
      source.cloudFavoritesChangedStream;
  @override
  SourceRuntimeState get sourceRuntimeState => source.sourceRuntimeState;
  @override
  void logRuntimeRetryRequested(String value) =>
      source.logRuntimeRetryRequested(value);
  @override
  Future<void> ensureInitialized() => source.ensureInitialized();
  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) => source.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);
  @override
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) => source.loadFavoriteComics(page: page, folderId: folderId);
  @override
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) =>
      source.addFavoriteFolder(name, sourceKey: sourceKey);
  @override
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) =>
      source.deleteFavoriteFolder(folderId, sourceKey: sourceKey);
  @override
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) => source.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    favoriteId: favoriteId,
    sourceKey: sourceKey,
  );
  @override
  Future<void> setFavoriteSortOrder(String order) =>
      source.setFavoriteSortOrder(order);
}

class HazukiSourceReaderAdapter extends HazukiSourceAdapterBase
    implements SourceReaderGateway {
  const HazukiSourceReaderAdapter(super.source);

  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => source.loadComicDetails(comicId, sourceKey: sourceKey);
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => source.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
  );
  @override
  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    String sourceKey = '',
  }) => source.prepareChapterImageData(
    imageUrl,
    comicId: comicId,
    epId: epId,
    useDiskCache: useDiskCache,
    sourceKey: sourceKey,
  );
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    String sourceKey = '',
  }) => source.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    sourceKey: sourceKey,
  );
  @override
  bool isLocalImagePath(String value) => source.isLocalImagePath(value);
  @override
  String normalizeLocalImagePath(String value) =>
      source.normalizeLocalImagePath(value);
  @override
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => source.evictImageBytesFromMemory(urls, sourceKey: sourceKey);
  @override
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => source.evictImageCacheEntries(urls, sourceKey: sourceKey);
  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => this.source.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
}
