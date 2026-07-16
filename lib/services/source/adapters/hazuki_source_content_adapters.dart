import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../account/source_account_operations.dart';
import '../comments/source_comments_operations.dart';
import '../content/source_content_operations.dart';
import '../debug/source_debug_operations.dart';
import '../favorites/source_favorites_operations.dart';
import '../gateways/source_content_gateways.dart';
import '../image/source_image_operations.dart';
import '../image/source_image_preparation_capability.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_runtime_operations.dart';
import '../runtime/source_runtime_view.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceSearchAdapter extends HazukiSourceListenableAdapter
    implements SourceSearchGateway {
  const HazukiSourceSearchAdapter({
    required SourceRuntimeView runtime,
    required SourceContentOperations content,
  }) : _content = content,
       super(runtime);

  final SourceContentOperations _content;

  @override
  String get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isActiveJmSource => runtime.isActiveJmSource;
  @override
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      runtime.runtimeRegistry.allowedSources;
  @override
  void logRuntimeRetryRequested(String value) =>
      runtime.logRuntimeRetryRequested(value);
  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) => _content.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
  );
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _content.loadComicDetails(comicId, sourceKey: sourceKey);
}

class HazukiSourceDiscoverAdapter extends HazukiSourceListenableAdapter
    implements SourceDiscoverGateway {
  HazukiSourceDiscoverAdapter({
    required SourceRuntimeView runtime,
    required SourceContentOperations content,
    required SourceAccountOperations account,
  }) : _content = content,
       _account = account,
       super(runtime);

  final SourceContentOperations _content;
  final SourceAccountOperations _account;

  @override
  String get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isLogged => _account.isLogged;
  @override
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  void logRuntimeRetryRequested(String value) =>
      runtime.logRuntimeRetryRequested(value);
  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) => _content.loadExploreSections(forceRefresh: forceRefresh);
  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) => _content.loadCategoryOptionGroupsByViewMore(viewMoreUrl: viewMoreUrl);
  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) => _content.loadCategoryComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
  );
}

class HazukiSourceCategoryAdapter implements SourceCategoryGateway {
  const HazukiSourceCategoryAdapter({
    required SourceContentOperations content,
    required SourceDebugOperations debug,
  }) : _content = content,
       _debug = debug;

  final SourceContentOperations _content;
  final SourceDebugOperations _debug;

  @override
  bool get softwareLogCaptureEnabled => _debug.softwareLogCaptureEnabled;
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) => _content.loadCategoryTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
  );
  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() =>
      _content.loadCategoryRankingOptions();
  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) => _content.loadCategoryRankingComics(
    rankingOption: rankingOption,
    page: page,
  );
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _debug.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
}

class HazukiSourceCommentsAdapter implements SourceCommentsGateway {
  const HazukiSourceCommentsAdapter({
    required SourceCommentsOperations comments,
    required SourceDebugOperations debug,
  }) : _comments = comments,
       _debug = debug;

  final SourceCommentsOperations _comments;
  final SourceDebugOperations _debug;

  @override
  bool get isLogged => _comments.isLogged;
  @override
  bool get supportCommentSend => _comments.supportCommentSend;
  @override
  bool get supportCommentLike => _comments.supportCommentLike;
  @override
  bool isLoggedForSource(String sourceKey) =>
      _comments.isLoggedForSource(sourceKey);
  @override
  bool supportCommentSendForSource(String sourceKey) =>
      _comments.supportCommentSendForSource(sourceKey);
  @override
  bool supportCommentLikeForSource(String sourceKey) =>
      _comments.supportCommentLikeForSource(sourceKey);
  @override
  bool supportCommentRepliesForSource(String sourceKey) =>
      _comments.supportCommentRepliesForSource(sourceKey);
  @override
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) => _comments.loadCommentsPage(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
  );
  @override
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) => _comments.sendComment(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
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
  }) => _comments.likeComment(
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
  }) => _debug.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
}

class HazukiSourceComicDetailAdapter implements SourceComicDetailGateway {
  HazukiSourceComicDetailAdapter({
    required SourceRuntimeView runtime,
    required SourceAccountOperations account,
    required SourceFavoritesOperations favorites,
    required SourceContentOperations content,
    required SourceImageOperations image,
  }) : _account = account,
       _favorites = favorites,
       _content = content,
       _image = image,
       _runtime = runtime;

  final SourceAccountOperations _account;
  final SourceFavoritesOperations _favorites;
  final SourceContentOperations _content;
  final SourceImageOperations _image;
  final SourceRuntimeView _runtime;

  @override
  String get activeSourceKey => _runtime.activeSourceKey;
  @override
  bool isLoggedForSource(String sourceKey) =>
      _account.isLoggedForSource(sourceKey);
  @override
  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderLoadForSource(sourceKey);
  @override
  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderAddForSource(sourceKey);
  @override
  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      _favorites.supportFavoriteFolderDeleteForSource(sourceKey);
  @override
  bool supportFavoriteToggleForSource(String sourceKey) =>
      _favorites.supportFavoriteToggleForSource(sourceKey);
  @override
  bool supportComicLikeForSource(String sourceKey) =>
      _content.supportComicLikeForSource(sourceKey);
  @override
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _favorites.favoriteSingleFolderForSingleComicForSource(sourceKey);
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _content.loadComicDetails(comicId, sourceKey: sourceKey);
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) => _content.loadCategoryTagGroups(
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
    bool priority = false,
    String sourceKey = '',
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _content.loadChapterImages(
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
  }) => _image.prefetchComicImages(
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
  }) => _favorites.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);
  @override
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) =>
      _favorites.addFavoriteFolder(name, sourceKey: sourceKey);
  @override
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) =>
      _favorites.deleteFavoriteFolder(folderId, sourceKey: sourceKey);
  @override
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) => _favorites.toggleFavorite(
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
  }) => _content.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
  );
}

class HazukiSourceFavoriteAdapter extends HazukiSourceListenableAdapter
    implements SourceFavoriteGateway {
  HazukiSourceFavoriteAdapter({
    required SourceRuntimeView runtime,
    required SourceAccountOperations account,
    required SourceFavoritesOperations favorites,
    required SourceRuntimeOperations runtimeOperations,
  }) : _account = account,
       _favorites = favorites,
       _runtimeOperations = runtimeOperations,
       super(runtime);

  final SourceAccountOperations _account;
  final SourceFavoritesOperations _favorites;
  final SourceRuntimeOperations _runtimeOperations;

  @override
  String get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isLogged => _account.isLogged;
  @override
  bool get supportFavoriteFolderDelete =>
      _favorites.supportFavoriteFolderDelete;
  @override
  bool get supportFavoriteFolderAdd => _favorites.supportFavoriteFolderAdd;
  @override
  bool get supportFavoriteFolderLoad => _favorites.supportFavoriteFolderLoad;
  @override
  bool get supportFavoriteSortOrder => _favorites.supportFavoriteSortOrder;
  @override
  bool get supportFavoriteToggle => _favorites.supportFavoriteToggle;
  @override
  bool get favoriteSingleFolderForSingleComic =>
      _favorites.favoriteSingleFolderForSingleComic;
  @override
  String get favoriteSortOrder => _favorites.favoriteSortOrder;
  @override
  List<String> get favoriteSortOrders => _favorites.favoriteSortOrders;
  @override
  Stream<void> get cloudFavoritesChangedStream => _favorites.changedStream;
  @override
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  void logRuntimeRetryRequested(String value) =>
      runtime.logRuntimeRetryRequested(value);
  @override
  Future<void> ensureInitialized() => _runtimeOperations.ensureInitialized();
  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) => _favorites.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);
  @override
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) => _favorites.loadFavoriteComics(page: page, folderId: folderId);
  @override
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) =>
      _favorites.addFavoriteFolder(name, sourceKey: sourceKey);
  @override
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) =>
      _favorites.deleteFavoriteFolder(folderId, sourceKey: sourceKey);
  @override
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) => _favorites.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    favoriteId: favoriteId,
    sourceKey: sourceKey,
  );
  @override
  Future<void> setFavoriteSortOrder(String order) =>
      _favorites.setFavoriteSortOrder(order);
}

class HazukiSourceReaderAdapter implements SourceReaderGateway {
  HazukiSourceReaderAdapter({
    required SourceContentOperations content,
    required SourceImagePreparationCapability imagePreparation,
    required SourceImageOperations image,
    required SourceDebugOperations debug,
  }) : _content = content,
       _imagePreparation = imagePreparation,
       _image = image,
       _debug = debug;

  final SourceContentOperations _content;
  final SourceImagePreparationCapability _imagePreparation;
  final SourceImageOperations _image;
  final SourceDebugOperations _debug;

  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _content.loadComicDetails(comicId, sourceKey: sourceKey);
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _content.loadChapterImages(
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
    bool priority = false,
    String sourceKey = '',
  }) => _imagePreparation.prepareChapterImageData(
    imageUrl,
    comicId: comicId,
    epId: epId,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );
  @override
  bool isLocalImagePath(String value) =>
      _imagePreparation.isLocalImagePath(value);
  @override
  String normalizeLocalImagePath(String value) =>
      _imagePreparation.normalizeLocalImagePath(value);
  @override
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _image.evictImageBytesFromMemory(urls, sourceKey: sourceKey);
  @override
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _image.evictImageCacheEntries(urls, sourceKey: sourceKey);
  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => _debug.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
}
