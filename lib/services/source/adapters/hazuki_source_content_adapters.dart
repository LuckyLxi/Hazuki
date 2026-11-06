import '../comic/comic_details_capability.dart';
import '../comic/comic_detail_tab_capability.dart';
import '../category/source_category_capability.dart';
import '../content/explore_capability.dart';
import '../plugins/source_search_capabilities.dart';
import '../plugins/source_sort_options.dart';
import '../plugins/source_detail_tabs.dart';

import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../account/account_session_capability.dart';
import '../comments/comments_capability.dart';
import '../content/source_content_operations.dart';
import '../content/source_reading_progress_uploads.dart';
import '../debug/source_debug_operations.dart';
import '../favorites/source_favorites_capability.dart';
import '../gateways/source_content_gateways.dart';
import '../image/source_image_operations.dart';
import '../image/source_image_preparation_capability.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_runtime_initialization_operations.dart';
import '../runtime/source_runtime_recovery_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../models/source_task.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceSearchAdapter extends HazukiSourceListenableAdapter
    implements SourceSearchGateway {
  const HazukiSourceSearchAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeRecoveryOperations recovery,
    required SourceContentOperations content,
    required SourceComicDetailsCapability comicDetails,
  }) : _content = content,
       _comicDetails = comicDetails,
       _recovery = recovery,
       super(runtime);

  final SourceRuntimeRecoveryOperations _recovery;
  final SourceContentOperations _content;
  final SourceComicDetailsCapability _comicDetails;

  @override
  String? get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get supportsDirectComicId => runtime.supportsDirectComicId;
  @override
  DirectComicIdRules? directComicIdRulesForSource(String sourceKey) =>
      runtime.directComicIdRulesForSource(sourceKey);
  @override
  SourceRuntimeState get runtimeState => runtime.runtimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      runtime.runtimeRegistry.allowedSources;
  // Aggregate search also needs metadata changes from inactive sources.
  @override
  void addListener(VoidCallback listener) =>
      runtime.runtimeRegistry.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      runtime.runtimeRegistry.removeListener(listener);
  @override
  void requestRuntimeRetry(String trigger) =>
      _recovery.requestRuntimeRetry(trigger);
  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = '',
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _content.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadComicDetails(
    comicId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
}

class HazukiSourceDiscoverAdapter extends HazukiSourceListenableAdapter
    implements SourceDiscoverGateway {
  HazukiSourceDiscoverAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeRecoveryOperations recovery,
    required SourceExploreCapability explore,
    required SourceCategoryCapability category,
    required SourceAccountSessionCapability account,
  }) : _explore = explore,
       _category = category,
       _account = account,
       _recovery = recovery,
       super(runtime);

  final SourceRuntimeRecoveryOperations _recovery;
  final SourceExploreCapability _explore;
  final SourceCategoryCapability _category;
  final SourceAccountSessionCapability _account;

  @override
  String? get sourceRevision => runtime.sourceRevision;
  @override
  bool get requiresLogin =>
      runtime.runtimeRegistry.allowedSources
          .where((s) => s.key == runtime.activeSourceKey)
          .firstOrNull
          ?.presentation['requiresLogin'] ==
      true;
  @override
  String? get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isLogged => _account.isLogged;
  @override
  SourceRuntimeState get runtimeState => runtime.runtimeState;
  @override
  void requestRuntimeRetry(String trigger) =>
      _recovery.requestRuntimeRetry(trigger);
  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) => _explore.load(forceRefresh: forceRefresh, taskOrigin: taskOrigin);
  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadOptionGroupsByViewMore(
    viewMoreUrl: viewMoreUrl,
    taskOrigin: taskOrigin,
  );
  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = '',
    List<String>? orders,
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
    taskOrigin: taskOrigin,
  );
}

class HazukiSourceCategoryAdapter implements SourceCategoryGateway {
  const HazukiSourceCategoryAdapter({
    required SourceCategoryCapability category,
    required SourceDebugOperations debug,
  }) : _category = category,
       _debug = debug;

  final SourceCategoryCapability _category;
  final SourceDebugOperations _debug;

  @override
  bool get softwareLogCaptureEnabled => _debug.softwareLogCaptureEnabled;
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions({
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadRankingOptions(taskOrigin: taskOrigin);
  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadRankingComics(
    rankingOption: rankingOption,
    page: page,
    taskOrigin: taskOrigin,
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
    required SourceCommentsCapability comments,
    required SourceAccountSessionCapability account,
    required SourceDebugOperations debug,
  }) : _comments = comments,
       _account = account,
       _debug = debug;

  final SourceCommentsCapability _comments;
  final SourceAccountSessionCapability _account;
  final SourceDebugOperations _debug;

  @override
  bool get isLogged => _account.isLogged;
  @override
  bool get supportCommentSend => _comments.supportCommentSendForSource('');
  @override
  bool get supportCommentLike => _comments.supportCommentLikeForSource('');
  @override
  bool isLoggedForSource(String sourceKey) =>
      _account.isLoggedForSource(sourceKey);
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
  SourceCommentSortOptions commentSortOptionsForSource(String sourceKey) =>
      _comments.commentSortOptionsForSource(sourceKey);
  @override
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
  }) => _comments.loadCommentsPage(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
    order: order,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
    SourceTaskOrigin? taskOrigin,
  }) => _comments.sendComment(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    content: content,
    replyTo: replyTo,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
    SourceTaskOrigin? taskOrigin,
  }) => _comments.likeComment(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    commentId: commentId,
    isLike: isLike,
    taskOrigin: taskOrigin,
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
    required SourceAccountSessionCapability account,
    required SourceFavoritesCapability favorites,
    required SourceComicDetailsCapability comicDetails,
    required SourceCategoryCapability category,
    required SourceComicDetailTabCapability detailTabs,
    required SourceImageOperations image,
  }) : _account = account,
       _favorites = favorites,
       _comicDetails = comicDetails,
       _category = category,
       _detailTabs = detailTabs,
       _image = image,
       _runtime = runtime;

  final SourceAccountSessionCapability _account;
  final SourceFavoritesCapability _favorites;
  final SourceComicDetailsCapability _comicDetails;
  final SourceCategoryCapability _category;
  final SourceComicDetailTabCapability _detailTabs;
  final SourceImageOperations _image;
  final SourceRuntimeView _runtime;

  @override
  String? get activeSourceKey => _runtime.activeSourceKey;
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
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _favorites.favoriteSingleFolderForSingleComicForSource(sourceKey);
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadComicDetails(
    comicId,
    sourceKey: sourceKey,
    forceRefresh: forceRefresh,
    taskOrigin: taskOrigin,
  );
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
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
    SourceTaskOrigin? taskOrigin,
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<List<SourceDetailTabBlock>> loadDetailTab({
    required String comicId,
    required String tabId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _detailTabs.loadDetailTab(
    comicId: comicId,
    tabId: tabId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _image.prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
    sourceKey: sourceKey,
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
  Future<ComicHeaderActionResult> runComicHeaderAction({
    required String comicId,
    required String actionId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.runComicHeaderAction(
    comicId: comicId,
    actionId: actionId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
}

class HazukiSourceFavoriteAdapter extends HazukiSourceListenableAdapter
    implements SourceFavoriteGateway {
  HazukiSourceFavoriteAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeRecoveryOperations recovery,
    required SourceAccountSessionCapability account,
    required SourceFavoritesCapability favorites,
    required this.cloudFavoritesChangedStream,
    required SourceRuntimeInitializationOperations initialization,
  }) : _account = account,
       _favorites = favorites,
       _initialization = initialization,
       _recovery = recovery,
       super(runtime);

  final SourceRuntimeRecoveryOperations _recovery;
  final SourceAccountSessionCapability _account;
  final SourceFavoritesCapability _favorites;
  final SourceRuntimeInitializationOperations _initialization;

  @override
  String? get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isLogged => _account.isLogged;
  @override
  bool get supportFavoriteFolderDelete =>
      _favorites.supportFavoriteFolderDelete;
  @override
  bool get supportFavoriteFolderRename =>
      _favorites.supportFavoriteFolderRename;
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
  final Stream<void> cloudFavoritesChangedStream;
  @override
  SourceRuntimeState get runtimeState => runtime.runtimeState;
  @override
  void requestRuntimeRetry(String trigger) =>
      _recovery.requestRuntimeRetry(trigger);
  @override
  Future<void> ensureInitialized() => _initialization.ensureInitialized();
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
  Future<void> setFavoriteSortOrder(String order) =>
      _favorites.setFavoriteSortOrder(order);
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
}

class HazukiSourceReaderAdapter
    implements
        SourceReaderGateway,
        SourceReadingProgressGateway,
        SourceReaderSessionGateway,
        SourceDownloadSessionGateway {
  HazukiSourceReaderAdapter({
    required SourceReadingProgressUploads readingProgressUploads,
    required SourceComicDetailsCapability comicDetails,
    required SourceImagePreparationCapability imagePreparation,
    required SourceImageOperations image,
    required SourceDebugOperations debug,
  }) : _readingProgressUploads = readingProgressUploads,
       _comicDetails = comicDetails,
       _imagePreparation = imagePreparation,
       _image = image,
       _debug = debug;

  @override
  SourceReaderSession acquireReaderSession(String sourceKey) =>
      _imagePreparation.acquireReaderSession(sourceKey);

  @override
  SourceDownloadSession acquireDownloadSession(String sourceKey) =>
      _imagePreparation.acquireDownloadSession(sourceKey);

  final SourceReadingProgressUploads _readingProgressUploads;
  final SourceComicDetailsCapability _comicDetails;
  final SourceImagePreparationCapability _imagePreparation;
  final SourceImageOperations _image;
  final SourceDebugOperations _debug;

  @override
  Future<void> reportReadingProgress(
    Map<String, Object> progress, {
    required String sourceKey,
    SourceTaskOrigin? taskOrigin,
  }) => _readingProgressUploads.report(progress, sourceKey, origin: taskOrigin);

  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadComicDetails(
    comicId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _imagePreparation.prepareChapterImageData(
    imageUrl,
    comicId: comicId,
    epId: epId,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
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
    SourceTaskOrigin? taskOrigin,
  }) => _image.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
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
