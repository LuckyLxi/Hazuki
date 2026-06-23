import 'package:flutter/foundation.dart';

import '../../models/hazuki_models.dart';
import '../hazuki_source_service.dart';

export '../hazuki_source_service.dart'
    show
        PreparedChapterImageData,
        DailyCheckInResult,
        SourceCatalogEntry,
        SourceRuntimeState,
        hazukiDefaultSourceKey,
        isHazukiCopyMangaSourceKey,
        isHazukiJmSourceKey,
        isHazukiPicacgSourceKey;

/// Narrow source surface used by search controllers.
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

abstract interface class SourceAccountGateway implements Listenable {
  String get activeSourceKey;
  bool get isLogged;
  bool get isInitialized;
  bool get isActiveDailyCheckInSource;
  String? get currentAccount;
  SourceRuntimeState get sourceRuntimeState;

  Future<void> ensureInitialized({String? sourceKey});
  Future<void> loadActiveSourcePreference();
  Future<void> login({required String account, required String password});
  Future<void> logout();
  Future<String?> loadCurrentAvatarUrl();
  Future<bool> isDailyCheckInCompletedToday();
  Future<DailyCheckInResult> performDailyCheckIn();
}

abstract interface class SourceDebugGateway {
  bool get softwareLogCaptureEnabled;
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  });
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  });
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type);
  void clearCapturedLogs();
}

/// Image loading and cache surface shared by widgets and non-UI services.
abstract interface class SourceImageGateway {
  String get activeSourceKey;

  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''});
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    String sourceKey = '',
  });
}

abstract interface class SourceRecommendationGateway
    implements SourceImageGateway, SourceDebugGateway {}

abstract interface class SourceDailyRecommendationGateway
    implements SourceSearchGateway, SourceImageGateway {
  bool get isInitialized;
}

abstract interface class SourceSyncGateway {
  String get activeSourceKey;
  Future<bool> hasCustomEditedActiveSource();
  Future<String?> readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content);
  Future<void> reloadFromLocalSourceFiles();
}

/// Runtime and source-file administration used by app/settings composition.
abstract interface class SourceRuntimeGateway implements Listenable {
  String get activeSourceKey;
  bool get isActiveJmSource;
  bool get isActiveCopyMangaSource;
  bool get isLogged;
  bool get isInitialized;
  bool get isActiveDailyCheckInSource;
  String? get currentAccount;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get runtimeState;
  List<SourceCatalogEntry> get allowedSources;

  bool isLoggedForSource(String sourceKey);
  String? currentAccountForSource(String sourceKey);
  Future<void> loadActiveSourcePreference();
  Future<void> ensureInitialized({String? sourceKey});
  Future<void> activateSource(String sourceKey);
  Future<void> prewarmInBackground();
  Future<void> warmUpFavoritesDebugInfo();
  Future<void> login({required String account, required String password});
  Future<void> logout();
  Future<String?> loadCurrentAvatarUrl();
  Future<bool> isDailyCheckInCompletedToday();
  Future<DailyCheckInResult> performDailyCheckIn();

  Future<bool> hasLocalSourceFile(String sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  });
  Future<void> deleteLocalSourceFile(String sourceKey);
  Future<String> loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content);
  Future<bool> hasCustomEditedActiveSource();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  });
  Future<bool> loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled);
  Future<void> clearCopyMangaDeviceInfo();
}

/// Category/ranking surface used by category feature pages.
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

/// Comment mutations and capability checks.
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

/// Source operations coordinated by the comic-detail feature.
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

/// Narrow source surface used by discover controllers.
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

/// Narrow source surface used by favorite controllers.
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

/// Narrow source surface used by reader controllers.
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
    String sourceKey = '',
  });
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
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

/// Narrow source surface used by settings controllers.
abstract interface class SourceSettingsGateway {
  String get activeSourceKey;
  bool get isActiveCopyMangaSource;

  Object? loadSourceSetting(String sourceKey, String key);
  Future<void> updateSourceSetting(String sourceKey, String key, dynamic value);
  Object? loadActiveSourceSetting(String key);
  Future<void> updateActiveSourceSetting(String key, dynamic value);
  Future<Map<String, dynamic>> getLineSettingsSnapshot();
  Future<void> updateLineSetting(String key, dynamic value);
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  });
  Future<Map<String, dynamic>> getImageCacheStatus();
  Future<void> setImageCacheMaxBytes(int value);
  Future<void> setImageCacheAutoCleanMode(String mode);
  Future<void> clearImageCache();
}

/// Transitional adapter. It keeps [HazukiSourceService] compatible while
/// consumers depend on only the capability they need.
class HazukiSourceCapabilities
    implements
        SourceSearchGateway,
        SourceDiscoverGateway,
        SourceFavoriteGateway,
        SourceReaderGateway,
        SourceSettingsGateway,
        SourceAccountGateway,
        SourceDebugGateway,
        SourceImageGateway,
        SourceRecommendationGateway,
        SourceDailyRecommendationGateway,
        SourceSyncGateway,
        SourceRuntimeGateway,
        SourceCategoryGateway,
        SourceCommentsGateway,
        SourceComicDetailGateway {
  const HazukiSourceCapabilities(this._service);

  final HazukiSourceService _service;

  @override
  void addListener(VoidCallback listener) => _service.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _service.removeListener(listener);

  @override
  String get activeSourceKey => _service.activeSourceKey;

  @override
  bool get isActiveJmSource => _service.isActiveJmSource;

  @override
  bool get isLogged => _service.isLogged;

  @override
  bool get isInitialized => _service.isInitialized;

  @override
  bool get isActiveDailyCheckInSource => _service.isActiveDailyCheckInSource;

  @override
  String? get currentAccount => _service.currentAccount;

  @override
  SourceRuntimeState get sourceRuntimeState => _service.sourceRuntimeState;

  @override
  List<SourceCatalogEntry> get allowedSources =>
      _service.runtimeRegistry.allowedSources;

  @override
  void logRuntimeRetryRequested(String source) =>
      _service.logRuntimeRetryRequested(source);

  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) => _service.searchComics(
    keyword: keyword,
    page: page,
    order: order,
    sourceKey: sourceKey,
  );

  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _service.loadComicDetails(comicId, sourceKey: sourceKey);

  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) => _service.loadExploreSections(forceRefresh: forceRefresh);

  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) => _service.loadCategoryOptionGroupsByViewMore(viewMoreUrl: viewMoreUrl);

  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) => _service.loadCategoryComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
  );

  @override
  bool get supportFavoriteFolderDelete => _service.supportFavoriteFolderDelete;
  @override
  bool get supportFavoriteFolderAdd => _service.supportFavoriteFolderAdd;
  @override
  bool get supportFavoriteFolderLoad => _service.supportFavoriteFolderLoad;
  @override
  bool get supportFavoriteSortOrder => _service.supportFavoriteSortOrder;
  @override
  bool get supportFavoriteToggle => _service.supportFavoriteToggle;
  @override
  bool get favoriteSingleFolderForSingleComic =>
      _service.favoriteSingleFolderForSingleComic;
  @override
  String get favoriteSortOrder => _service.favoriteSortOrder;
  @override
  List<String> get favoriteSortOrders => _service.favoriteSortOrders;
  @override
  Stream<void> get cloudFavoritesChangedStream =>
      _service.cloudFavoritesChangedStream;

  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      _service.ensureInitialized(sourceKey: sourceKey);

  @override
  Future<void> loadActiveSourcePreference() =>
      _service.loadActiveSourcePreference();

  @override
  Future<void> activateSource(String sourceKey) =>
      _service.activateSource(sourceKey);

  @override
  Future<void> login({required String account, required String password}) =>
      _service.login(account: account, password: password);

  @override
  Future<void> logout() => _service.logout();

  @override
  Future<String?> loadCurrentAvatarUrl() => _service.loadCurrentAvatarUrl();

  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      _service.isDailyCheckInCompletedToday();

  @override
  Future<DailyCheckInResult> performDailyCheckIn() =>
      _service.performDailyCheckIn();

  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) => _service.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);

  @override
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) => _service.loadFavoriteComics(page: page, folderId: folderId);

  @override
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) =>
      _service.addFavoriteFolder(name, sourceKey: sourceKey);

  @override
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) =>
      _service.deleteFavoriteFolder(folderId, sourceKey: sourceKey);

  @override
  Future<void> setFavoriteSortOrder(String order) =>
      _service.setFavoriteSortOrder(order);

  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _service.loadChapterImages(
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
  }) => _service.prepareChapterImageData(
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
  }) => _service.downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    sourceKey: sourceKey,
  );

  @override
  bool isLocalImagePath(String value) => _service.isLocalImagePath(value);

  @override
  String normalizeLocalImagePath(String value) =>
      _service.normalizeLocalImagePath(value);

  @override
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _service.evictImageBytesFromMemory(urls, sourceKey: sourceKey);

  @override
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _service.evictImageCacheEntries(urls, sourceKey: sourceKey);

  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => _service.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );

  @override
  bool get softwareLogCaptureEnabled => _service.softwareLogCaptureEnabled;

  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _service.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );

  @override
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      _service.collectTypedDebugInfo(type);

  @override
  bool get isActiveCopyMangaSource => _service.isActiveCopyMangaSource;

  @override
  Object? loadSourceSetting(String sourceKey, String key) =>
      _service.loadSourceSetting(sourceKey, key);

  @override
  Future<void> updateSourceSetting(
    String sourceKey,
    String key,
    dynamic value,
  ) => _service.updateSourceSetting(sourceKey, key, value);

  @override
  Object? loadActiveSourceSetting(String key) =>
      _service.loadActiveSourceSetting(key);

  @override
  Future<void> updateActiveSourceSetting(String key, dynamic value) =>
      _service.updateActiveSourceSetting(key, value);

  @override
  Future<Map<String, dynamic>> getLineSettingsSnapshot() =>
      _service.getLineSettingsSnapshot();

  @override
  Future<void> updateLineSetting(String key, dynamic value) =>
      _service.updateLineSetting(key, value);

  @override
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) => _service.refreshLines(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
  );

  @override
  Future<Map<String, dynamic>> getImageCacheStatus() =>
      _service.getImageCacheStatus();

  @override
  Future<void> setImageCacheMaxBytes(int value) =>
      _service.setImageCacheMaxBytes(value);

  @override
  Future<void> setImageCacheAutoCleanMode(String mode) =>
      _service.setImageCacheAutoCleanMode(mode);

  @override
  Future<void> clearImageCache() => _service.clearImageCache();

  @override
  void clearCapturedLogs() => _service.facade.clearCapturedLogs();

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      _service.peekImageBytesFromMemory(url, sourceKey: sourceKey);

  @override
  SourceMeta? get sourceMeta => _service.sourceMeta;

  @override
  SourceRuntimeState get runtimeState => _service.runtimeState;

  @override
  bool isLoggedForSource(String sourceKey) =>
      _service.isLoggedForSource(sourceKey);

  @override
  String? currentAccountForSource(String sourceKey) =>
      _service.currentAccountForSource(sourceKey);

  @override
  Future<void> prewarmInBackground() => _service.prewarmInBackground();

  @override
  Future<void> warmUpFavoritesDebugInfo() =>
      _service.warmUpFavoritesDebugInfo();

  @override
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _service.hasLocalSourceFile(sourceKey);

  @override
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) => _service.downloadSourceFile(sourceKey, onProgress: onProgress);

  @override
  Future<void> deleteLocalSourceFile(String sourceKey) =>
      _service.deleteLocalSourceFile(sourceKey);

  @override
  Future<String> loadEditableActiveSource() =>
      _service.loadEditableActiveSource();

  @override
  Future<void> saveEditedActiveSource(String content) =>
      _service.saveEditedActiveSource(content);

  @override
  Future<bool> hasCustomEditedActiveSource() =>
      _service.hasCustomEditedActiveSource();

  @override
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) => _service.downloadActiveSourceAndReload(onProgress: onProgress);

  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _service.loadSoftwareLogCaptureEnabled();

  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _service.setSoftwareLogCaptureEnabled(enabled);

  @override
  Future<void> clearCopyMangaDeviceInfo() =>
      _service.clearCopyMangaDeviceInfo();

  @override
  Future<String?> readLocalActiveSourceIfExists() =>
      _service.readLocalActiveSourceIfExists();

  @override
  Future<void> writeLocalActiveSource(String content) =>
      _service.writeLocalActiveSource(content);

  @override
  Future<void> reloadFromLocalSourceFiles() =>
      _service.reloadFromLocalSourceFiles();

  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) => _service.loadCategoryTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
  );

  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() =>
      _service.loadCategoryRankingOptions();

  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) => _service.loadCategoryRankingComics(
    rankingOption: rankingOption,
    page: page,
  );

  @override
  bool get supportCommentSend => _service.supportCommentSend;

  @override
  bool get supportCommentLike => _service.supportCommentLike;

  @override
  bool supportCommentSendForSource(String sourceKey) =>
      _service.supportCommentSendForSource(sourceKey);

  @override
  bool supportCommentLikeForSource(String sourceKey) =>
      _service.supportCommentLikeForSource(sourceKey);

  @override
  bool supportCommentRepliesForSource(String sourceKey) =>
      _service.supportCommentRepliesForSource(sourceKey);

  @override
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) => _service.loadCommentsPage(
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
  }) => _service.sendComment(
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
  }) => _service.likeComment(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    commentId: commentId,
    isLike: isLike,
  );

  @override
  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      _service.supportFavoriteFolderLoadForSource(sourceKey);

  @override
  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      _service.supportFavoriteFolderAddForSource(sourceKey);

  @override
  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      _service.supportFavoriteFolderDeleteForSource(sourceKey);

  @override
  bool supportFavoriteToggleForSource(String sourceKey) =>
      _service.supportFavoriteToggleForSource(sourceKey);

  @override
  bool supportComicLikeForSource(String sourceKey) =>
      _service.supportComicLikeForSource(sourceKey);

  @override
  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _service.favoriteSingleFolderForSingleComicForSource(sourceKey);

  @override
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
    String sourceKey = '',
  }) => _service.prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
    sourceKey: sourceKey,
  );

  @override
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) => _service.toggleFavorite(
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
  }) => _service.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
  );
}
