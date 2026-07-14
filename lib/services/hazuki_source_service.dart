import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/preferences/hazuki_preference_keys.dart';
import '../models/hazuki_models.dart';
import 'source/common/source_json_coerce.dart';
import 'source/common/source_prefs_keys.dart';
import 'source/category/source_category_capability.dart';
import 'source/comic/source_comic_details_cache.dart';
import 'source/comic/comic_details_capability.dart';
import 'source/account/source_daily_check_in_capability.dart';
import 'source/account/source_relogin_coordinator.dart';
import 'source/debug/debug_log_capability.dart';
import 'source/debug/debug_log_internals.dart';
import 'source/explore_capability.dart';
import 'source/favorites/source_favorites_capability.dart';
import 'source/image/image_cache_capability.dart';
import 'source/image/source_image_preparation_capability.dart';
import 'source/models/source_contract_models.dart';
import 'source/models/source_identity.dart';
import 'source/runtime/explore_cache_capability.dart';
import 'source/runtime/line_settings_capability.dart';
import 'source/runtime/source_secure_session_storage.dart';
import 'source/runtime/source_runtime_facade.dart';
import 'source/runtime/source_runtime_handle.dart';
import 'source/runtime/source_runtime_host.dart';
import 'source/runtime/source_runtime_registry.dart';

export 'source/models/source_contract_models.dart';
export 'source/models/source_identity.dart';
export 'source/runtime/source_cookie_store.dart';
export 'source/runtime/source_cache_store.dart';
export 'source/runtime/source_runtime_kernel.dart';
export 'source/runtime/source_runtime_facade.dart';
export 'source/runtime/source_runtime_handle.dart';
export 'source/runtime/source_runtime_registry.dart';
export 'source/runtime/source_session_store.dart';
export 'source/debug/source_debug_log_store.dart';

part 'source/account/account_session_capability.dart';

part 'source/comments/comments_avatar_support.dart';
part 'source/comments/comments_capability.dart';

part 'source/debug/debug_favorites_capability.dart';
part 'source/debug/debug_report_capability.dart';

part 'source/runtime/cookie_store_support.dart';
part 'source/runtime/js_bridge_support.dart';
part 'source/runtime/source_bootstrap_support.dart';
part 'source/runtime/source_file_management_capability.dart';
part 'source/runtime/source_loader_capability.dart';
part 'source/runtime/source_runtime_support.dart';
part 'source/runtime/version_update_capability.dart';

const _jmSourceUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/jm.js',
];

const _copyMangaSourceUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/copy_manga.js',
];

const _picacgSourceUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/picacg.js',
];

const _sourceIndexUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json',
];

const _bundledInitAssetPath = 'assets/init.js';

const List<SourceCatalogEntry> hazukiAllowedSourceCatalog = [
  SourceCatalogEntry(
    key: hazukiDefaultSourceKey,
    name: 'JMComic',
    fileName: 'jm.js',
    directUrls: _jmSourceUrls,
  ),
  SourceCatalogEntry(
    key: 'copy_manga',
    name: 'CopyManga',
    fileName: 'copy_manga.js',
    directUrls: _copyMangaSourceUrls,
  ),
  SourceCatalogEntry(
    key: 'picacg',
    name: 'Picacg',
    fileName: 'picacg.js',
    directUrls: _picacgSourceUrls,
  ),
];

class HazukiSourceService extends ChangeNotifier {
  HazukiSourceService({SourceSecureSessionStorage? secureSessionStorage})
    : _secureSessionStorage =
          secureSessionStorage ?? FlutterSourceSecureSessionStorage() {
    _runtimeHost = SourceRuntimeHost(
      catalog: hazukiAllowedSourceCatalog,
      defaultSourceKey: hazukiDefaultSourceKey,
      secureSessionStorage: _secureSessionStorage,
      ensureSourceInitialized: ensureSourceInitialized,
      currentAccountForSource: currentAccountForSource,
      isLoggedForSource: isLoggedForSource,
    );
    _runtimeHost.addListener(notifyListeners);
    _reloginCoordinator = SourceReloginCoordinator(
      loginWithStoredAccount: (context, {required account, required password}) {
        final facade = (context as SourceFacadeReloginContext).facade;
        return _loginWithFacade(facade, account: account, password: password);
      },
    );
    _dailyCheckInCapability = SourceDailyCheckInCapability(
      runtimeHost: _runtimeHost,
      reloginCoordinator: _reloginCoordinator,
    );
    _comicDetailsCache = SourceComicDetailsCache(runtimeHost: _runtimeHost);
    _comicDetailsCapability = SourceComicDetailsCapability(
      runtimeHost: _runtimeHost,
      cache: _comicDetailsCache,
      reloginCoordinator: _reloginCoordinator,
      translateSourceText: _translateSourceText,
    );
    _exploreCapability = SourceExploreCapability(
      runtimeHost: _runtimeHost,
      translateSourceText: _translateSourceText,
    );
    _categoryCapability = SourceCategoryCapability(
      runtimeHost: _runtimeHost,
      translateSourceText: _translateSourceText,
      parseExploreComics: _parseExploreComics,
    );
    _imagePreparationCapability = SourceImagePreparationCapability(
      runtimeHost: _runtimeHost,
      downloadImageBytes: downloadImageBytes,
    );
    _favoritesCapability = SourceFavoritesCapability(
      runtimeHost: _runtimeHost,
      reloginCoordinator: _reloginCoordinator,
      parseExploreComics: _parseExploreComics,
      updateComicDetailsFavoriteState:
          ({required sourceKey, required comicId, required isFavorite}) {
            final scopedKey = SourceScopedComicId(
              sourceKey: sourceKey,
              comicId: comicId,
            ).storageKey;
            final cached = _getComicDetailsFromMemoryCache(
              scopedKey,
              sourceKey: sourceKey,
            );
            if (cached != null) {
              _comicDetailsCapability.updateFavoriteStateInMemoryCache(
                cached.scopedId,
                isFavorite: isFavorite,
              );
            }
          },
      notifyCloudFavoritesChanged: notifyCloudFavoritesChanged,
    );
  }

  final SourceSecureSessionStorage _secureSessionStorage;
  late final SourceRuntimeHost _runtimeHost;
  late final SourceReloginCoordinator _reloginCoordinator;
  late final SourceDailyCheckInCapability _dailyCheckInCapability;
  late final SourceComicDetailsCache _comicDetailsCache;
  late final SourceComicDetailsCapability _comicDetailsCapability;
  late final SourceExploreCapability _exploreCapability;
  late final SourceCategoryCapability _categoryCapability;
  late final SourceImagePreparationCapability _imagePreparationCapability;
  late final SourceFavoritesCapability _favoritesCapability;

  SourceRuntimeRegistry get runtimeRegistry => _runtimeHost.runtimeRegistry;

  final StreamController<void> _cloudFavoritesChangedController =
      StreamController<void>.broadcast();
  Stream<void> get cloudFavoritesChangedStream =>
      _cloudFavoritesChangedController.stream;

  void notifyCloudFavoritesChanged() {
    _cloudFavoritesChangedController.add(null);
  }

  SourceRuntimeHandle get _activeHandle => _runtimeHost.activeHandle;

  SourceRuntimeHandle _handleFor(String sourceKey) {
    return _runtimeHost.handleFor(sourceKey);
  }

  Dio get dio => _activeHandle.dio;
  HazukiSourceFacade get facade => _activeHandle.facade;
  LineSettingsCapability get lineSettings => _activeHandle.lineSettings;

  @visibleForTesting
  dynamic handleJsMessageForTesting(
    SourceRuntimeHandle handle,
    dynamic message,
  ) {
    return _handleJsMessageForHandle(handle, message);
  }

  Future<Map<String, dynamic>> getLineSettingsSnapshot() =>
      lineSettings.getSnapshot();

  Future<void> updateLineSetting(String key, dynamic value) =>
      lineSettings.updateSetting(key, value);

  Object? loadActiveSourceSetting(String key) =>
      facade.loadSourceSetting(activeSourceKey, key);

  Future<void> updateActiveSourceSetting(String key, dynamic value) =>
      facade.saveSourceSetting(activeSourceKey, key, value);

  Object? loadSourceSetting(String sourceKey, String key) {
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    return _handleFor(
      resolvedSourceKey,
    ).facade.loadSourceSetting(resolvedSourceKey, key);
  }

  Future<void> updateSourceSetting(
    String sourceKey,
    String key,
    dynamic value,
  ) {
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final targetFacade = _handleFor(resolvedSourceKey).facade;
    return targetFacade.ensurePrefs().then(
      (_) => targetFacade.saveSourceSetting(resolvedSourceKey, key, value),
    );
  }

  Future<void> clearCopyMangaDeviceInfo() async {
    const sourceKey = 'copy_manga';
    final handle = _handleFor(sourceKey);
    await handle.facade.deleteSourceData(sourceKey, '_deviceinfo');
    await handle.facade.deleteSourceData(sourceKey, '_device');
    await handle.facade.deleteSourceData(sourceKey, '_pseudoid');

    final engine = handle.runtime.engine;
    if (engine != null && activeSourceKey == sourceKey) {
      final hasRefreshAppApi = handle.facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.refreshAppApi'),
      );
      if (hasRefreshAppApi) {
        final dynamic result = engine.evaluate(
          'this.__hazuki_source.refreshAppApi()',
          name: 'copy_manga_refresh_app_api.js',
        );
        await handle.facade.js.resolve(result);
      }
    }
  }

  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) => lineSettings.refresh(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
  );

  ImageCacheCapability get imageCache => _activeHandle.imageCache;
  ExploreCacheCapability get exploreCache => _activeHandle.exploreCache;
  DebugLogCapability get debugLog => _activeHandle.debugLog;

  ImageCacheCapability _imageCacheForSourceRequest(String sourceKey) {
    final requested = sourceKey.trim();
    if (requested.isEmpty) {
      return imageCache;
    }
    return _handleFor(requested).imageCache;
  }

  void addDebugLog({
    required String type,
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => debugLog.addDebugLog(
    type: type,
    level: level,
    title: title,
    content: content,
    source: source,
  );

  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => debugLog.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );

  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => debugLog.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );

  void appendNetworkLogEntry({
    required String method,
    required String url,
    required int? statusCode,
    required String? error,
    required DateTime startedAt,
    String source = 'js_http',
    String? category,
    Map<String, dynamic>? requestHeaders,
    Object? requestData,
    Map<String, dynamic>? responseHeaders,
    Object? responseBody,
  }) => debugLog.appendNetworkLogEntry(
    method: method,
    url: url,
    statusCode: statusCode,
    error: error,
    startedAt: startedAt,
    source: source,
    category: category,
    requestHeaders: requestHeaders,
    requestData: requestData,
    responseHeaders: responseHeaders,
    responseBody: responseBody,
  );

  void appendNetworkLogEntryForHandle(
    SourceRuntimeHandle handle, {
    required String method,
    required String url,
    required int? statusCode,
    required String? error,
    required DateTime startedAt,
    String source = 'js_http',
    String? category,
    Map<String, dynamic>? requestHeaders,
    Object? requestData,
    Map<String, dynamic>? responseHeaders,
    Object? responseBody,
  }) => handle.debugLog.appendNetworkLogEntry(
    method: method,
    url: url,
    statusCode: statusCode,
    error: error,
    startedAt: startedAt,
    source: source,
    category: category,
    requestHeaders: requestHeaders,
    requestData: requestData,
    responseHeaders: responseHeaders,
    responseBody: responseBody,
  );

  int get imageCacheMaxBytes => imageCache.maxBytes;
  Future<void> setImageCacheMaxBytes(int value) =>
      imageCache.setMaxBytes(value);
  String get imageCacheAutoCleanMode => imageCache.autoCleanMode;
  Future<void> setImageCacheAutoCleanMode(String mode) =>
      imageCache.setAutoCleanMode(mode);
  Future<Map<String, dynamic>> getImageCacheStatus() => imageCache.getStatus();
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      _imageCacheForSourceRequest(
        sourceKey,
      ).peekFromMemory(url, sourceKey: sourceKey);
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _imageCacheForSourceRequest(
    sourceKey,
  ).evictFromMemory(urls, sourceKey: sourceKey);

  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    int memoryCount = 0,
    String sourceKey = '',
  }) => _imageCacheForSourceRequest(sourceKey).prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
    sourceKey: sourceKey,
  );

  Future<Uint8List> downloadImageBytes(
    String url, {
    String? comicId,
    String? epId,
    bool keepInMemory = true,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) => _imageCacheForSourceRequest(sourceKey).downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );

  Future<void> clearImageCache() => imageCache.clear();
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _imageCacheForSourceRequest(
    sourceKey,
  ).evictEntries(urls, sourceKey: sourceKey);

  FlutterQjs? get _engine => _activeHandle.runtime.engine;

  String get _statusText => _activeHandle.runtime.statusText;

  SourceRuntimeState get _runtimeState => _activeHandle.runtime.runtimeState;

  SourceMeta? get _sourceMeta => _activeHandle.runtime.sourceMeta;

  bool get _softwareLogCaptureEnabled =>
      _activeHandle.debug.softwareLogCaptureEnabled;

  String get statusText => _statusText;
  SourceRuntimeState get sourceRuntimeState => _runtimeState;
  SourceMeta? get sourceMeta => _sourceMeta;
  String get activeSourceKey => _runtimeHost.activeSourceKey;
  bool get isActiveJmSource => isHazukiJmSourceKey(activeSourceKey);
  bool get isActiveCopyMangaSource =>
      isHazukiCopyMangaSourceKey(activeSourceKey);
  bool get isActiveDailyCheckInSource =>
      isHazukiJmSourceKey(activeSourceKey) ||
      isHazukiPicacgSourceKey(activeSourceKey);
  bool get isInitialized => _engine != null && _sourceMeta != null;
  bool get softwareLogCaptureEnabled => _softwareLogCaptureEnabled;

  SourceCatalogEntry _definitionForSourceKey(String sourceKey) {
    return _runtimeHost.definitionFor(sourceKey);
  }

  String _normalizeAllowedSourceKey(String sourceKey) {
    return _runtimeHost.normalize(sourceKey);
  }

  Future<void> loadActiveSourcePreference() =>
      _runtimeHost.loadActiveSourcePreference();

  Future<void> activateSource(String sourceKey) =>
      _runtimeHost.activateSource(sourceKey);

  void clearLocalizedSourceTextCaches() {
    exploreCache.clearMemory();
    facade.cache.clearCategoryTagGroupsMemoryCache();
  }

  String _translateSourceText(String text, {String sourceKey = ''}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return text;
    }

    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? activeSourceKey
        : sourceKey.trim();
    final handle = _handleFor(resolvedSourceKey);
    final engine = handle.runtime.engine;
    if (engine == null) {
      return text;
    }

    final localeTag = _sourceTranslationLocaleTag(handle.session.prefs);
    if (localeTag == null) {
      return text;
    }

    try {
      final translated = engine.evaluate(
        'this.__hazuki_source.translation?.[${jsonEncode(localeTag)}]?.[${jsonEncode(trimmed)}]',
      );
      final value = translated?.toString().trim() ?? '';
      return value.isEmpty ? text : value;
    } catch (_) {
      return text;
    }
  }

  String? _sourceTranslationLocaleTag(SharedPreferences? prefs) {
    final saved = prefs?.getString(hazukiLocalePreferenceKey);
    final languageCode = switch (saved) {
      'zh' => 'zh',
      'en' => 'en',
      _ => PlatformDispatcher.instance.locale.languageCode,
    };
    return languageCode == 'zh' ? 'zh_CN' : null;
  }

  String? currentAccountForSource(String sourceKey) {
    final handle = _handleFor(sourceKey);
    final displayName = handle.session
        .loadSourceData(handle.sourceKey, 'display_name')
        ?.toString()
        .trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final accountData = handle.session.loadAccountDataSync(
      handle.runtime.sourceMeta,
      fallbackSourceKey: handle.sourceKey,
    );
    if (accountData == null || accountData.isEmpty) {
      return null;
    }
    return accountData.first;
  }

  bool isLoggedForSource(String sourceKey) {
    final handle = _handleFor(sourceKey);
    return handle.session.loadAccountDataSync(
          handle.runtime.sourceMeta,
          fallbackSourceKey: handle.sourceKey,
        ) !=
        null;
  }

  String _resolveActiveSourceKey([String? requestedSourceKey]) =>
      resolveActiveSourceKey(requestedSourceKey);

  String resolveActiveSourceKey([String? requestedSourceKey]) {
    final requested = requestedSourceKey?.trim() ?? '';
    return requested.isNotEmpty
        ? _normalizeAllowedSourceKey(requested)
        : activeSourceKey;
  }

  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) => _exploreCapability.load(forceRefresh: forceRefresh);

  Future<bool> isDailyCheckInCompletedToday() =>
      _dailyCheckInCapability.isCompletedToday();

  Future<DailyCheckInResult> performDailyCheckIn() =>
      _dailyCheckInCapability.perform();

  ComicDetailsData? _getComicDetailsFromMemoryCache(
    String comicId, {
    String sourceKey = '',
  }) => _comicDetailsCache.get(comicId, sourceKey: sourceKey);

  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _comicDetailsCapability.loadComicDetails(comicId, sourceKey: sourceKey);

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _comicDetailsCapability.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
  );

  bool get supportComicLike => _comicDetailsCapability.supportComicLike;

  bool supportComicLikeForSource(String sourceKey) =>
      _comicDetailsCapability.supportComicLikeForSource(sourceKey);

  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) => _comicDetailsCapability.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
  );

  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) => _categoryCapability.loadTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
  );

  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() =>
      _categoryCapability.loadRankingOptions();

  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) => _categoryCapability.loadRankingComics(
    rankingOption: rankingOption,
    page: page,
  );

  Future<List<CategoryRankingOption>> loadCategoryRankingOptionsByViewMore({
    required String viewMoreUrl,
  }) => _categoryCapability.loadRankingOptionsByViewMore(
    viewMoreUrl: viewMoreUrl,
  );

  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) =>
      _categoryCapability.loadOptionGroupsByViewMore(viewMoreUrl: viewMoreUrl);

  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) => _categoryCapability.loadComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
  );

  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _favoritesCapability.favoriteSingleFolderForSingleComicForSource(
        sourceKey,
      );

  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      _favoritesCapability.supportFavoriteFolderAddForSource(sourceKey);

  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      _favoritesCapability.supportFavoriteFolderDeleteForSource(sourceKey);

  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      _favoritesCapability.supportFavoriteFolderLoadForSource(sourceKey);

  bool supportFavoriteToggleForSource(String sourceKey) =>
      _favoritesCapability.supportFavoriteToggleForSource(sourceKey);

  bool get favoriteSingleFolderForSingleComic =>
      _favoritesCapability.favoriteSingleFolderForSingleComic;
  bool get supportFavoriteFolderManagement =>
      _favoritesCapability.supportFavoriteFolderManagement;
  bool get supportFavoriteFolderAdd =>
      _favoritesCapability.supportFavoriteFolderAdd;
  bool get supportFavoriteFolderDelete =>
      _favoritesCapability.supportFavoriteFolderDelete;
  bool get supportFavoriteFolderLoad =>
      _favoritesCapability.supportFavoriteFolderLoad;
  String get favoriteSortOrder => _favoritesCapability.favoriteSortOrder;
  List<String> get favoriteSortOrders =>
      _favoritesCapability.favoriteSortOrders;
  bool get supportFavoriteSortOrder =>
      _favoritesCapability.supportFavoriteSortOrder;
  bool get supportFavoriteLoadComics =>
      _favoritesCapability.supportFavoriteLoadComics;
  bool get supportFavoriteLoadNext =>
      _favoritesCapability.supportFavoriteLoadNext;
  bool get supportFavoriteToggle => _favoritesCapability.supportFavoriteToggle;
  bool get supportCommentSend => _favoritesCapability.supportCommentSend;
  bool get supportCommentLike => _favoritesCapability.supportCommentLike;

  Future<void> setFavoriteSortOrder(String order) =>
      _favoritesCapability.setFavoriteSortOrder(order);

  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) => _favoritesCapability.loadFavoriteComics(page: page, folderId: folderId);

  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) => _favoritesCapability.loadFavoriteFolders(
    comicId: comicId,
    sourceKey: sourceKey,
  );

  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) =>
      _favoritesCapability.addFavoriteFolder(name, sourceKey: sourceKey);

  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) =>
      _favoritesCapability.deleteFavoriteFolder(folderId, sourceKey: sourceKey);

  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) => _favoritesCapability.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    favoriteId: favoriteId,
    sourceKey: sourceKey,
  );

  Future<T> _runWithReloginRetry<T>(
    Future<T> Function() action, {
    HazukiSourceFacade? targetFacade,
  }) => _reloginCoordinator.runWithReloginRetry(
    action,
    context: SourceFacadeReloginContext(targetFacade ?? facade),
  );

  Future<bool> _ensureFavoriteSessionReady({
    HazukiSourceFacade? targetFacade,
  }) => _reloginCoordinator.ensureFavoriteSessionReady(
    SourceFacadeReloginContext(targetFacade ?? facade),
  );

  Future<bool> _tryReloginFromStoredAccount({
    bool force = false,
    HazukiSourceFacade? targetFacade,
  }) => _reloginCoordinator.tryReloginFromStoredAccount(
    SourceFacadeReloginContext(targetFacade ?? facade),
    force: force,
  );

  bool isLocalImagePath(String value) =>
      _imagePreparationCapability.isLocalImagePath(value);

  String normalizeLocalImagePath(String value) =>
      _imagePreparationCapability.normalizeLocalImagePath(value);

  int calculateJmImageSegments(
    String epId,
    String imageUrl, {
    String sourceKey = '',
  }) => _imagePreparationCapability.calculateJmImageSegments(
    epId,
    imageUrl,
    sourceKey: sourceKey,
  );

  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) => _imagePreparationCapability.prepareChapterImageData(
    imageUrl,
    comicId: comicId,
    epId: epId,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
  );

  List<ExploreComic> _parseExploreComics(List list, {String sourceKey = ''}) {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? activeSourceKey
        : sourceKey.trim();
    final comics = <ExploreComic>[];
    for (final comic in list) {
      if (comic is! Map) {
        continue;
      }
      final comicMap = Map<String, dynamic>.from(comic);
      comics.add(
        ExploreComic(
          id: comicMap['id']?.toString() ?? '',
          title: comicMap['title']?.toString() ?? '',
          subTitle: (comicMap['subTitle'] ?? comicMap['subtitle'] ?? '')
              .toString(),
          cover: comicMap['cover']?.toString() ?? '',
          sourceKey: resolvedSourceKey,
        ),
      );
    }
    return comics;
  }

  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? activeSourceKey
        : _normalizeAllowedSourceKey(sourceKey);
    await ensureSourceInitialized(resolvedSourceKey);

    final facade = _handleFor(resolvedSourceKey).facade;
    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const SearchComicsResult(comics: [], maxPage: 0);
    }

    final normalizedPage = page < 1 ? 1 : page;
    final normalizedOrder = _normalizeSearchOptionForSource(
      order,
      sourceKey: resolvedSourceKey,
    );

    final hasSearch = jsAsBool(
      engine.evaluate('!!this.__hazuki_source.search'),
    );
    final hasSearchLoad = jsAsBool(
      engine.evaluate('!!this.__hazuki_source.search?.load'),
    );
    if (!hasSearch || !hasSearchLoad) {
      throw Exception('search_not_supported');
    }

    final optionsArg = jsonEncode([normalizedOrder]);
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.search.load(${jsonEncode(normalizedKeyword)}, $optionsArg, $normalizedPage)',
      name: 'source_search.js',
    );
    final dynamic resolved = await facade.js.resolve(result);

    if (resolved is! Map) {
      return const SearchComicsResult(comics: [], maxPage: null);
    }

    final map = Map<String, dynamic>.from(resolved);
    final comicsRaw = map['comics'];
    final List<ExploreComic> comics = comicsRaw is List
        ? _parseExploreComics(comicsRaw, sourceKey: resolvedSourceKey)
        : const <ExploreComic>[];

    final maxPageRaw = map['maxPage'];
    final maxPage = switch (maxPageRaw) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(maxPageRaw?.toString() ?? ''),
    };

    return SearchComicsResult(comics: comics, maxPage: maxPage);
  }

  String _normalizeSearchOptionForSource(
    String order, {
    required String sourceKey,
  }) {
    final normalized = order.trim();
    if (isHazukiCopyMangaSourceKey(sourceKey)) {
      const copySearchModes = {'-', 'name', 'author', 'local'};
      return copySearchModes.contains(normalized) ? normalized : '-';
    }
    if (isHazukiPicacgSourceKey(sourceKey)) {
      const picacgSortModes = {'dd', 'da', 'ld', 'vd'};
      return picacgSortModes.contains(normalized) ? normalized : 'dd';
    }
    return normalized.isEmpty ? 'mr' : normalized;
  }

  @override
  void dispose() {
    _runtimeHost.removeListener(notifyListeners);
    _runtimeHost.dispose();
    unawaited(_cloudFavoritesChangedController.close());
    super.dispose();
  }
}
