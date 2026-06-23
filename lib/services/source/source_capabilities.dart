import 'package:flutter/foundation.dart';

import '../../models/hazuki_models.dart';
import '../hazuki_source_service.dart';

export '../hazuki_source_service.dart'
    show
        PreparedChapterImageData,
        DailyCheckInResult,
        SourceCatalogEntry,
        SourceRuntimeState,
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
        SourceDebugGateway {
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
}
