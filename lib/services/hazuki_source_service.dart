import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/preferences/hazuki_preference_keys.dart';
import '../models/hazuki_models.dart';
import 'source/common/source_json_coerce.dart';
import 'source/category/source_category_capability.dart';
import 'source/comic/source_comic_details_cache.dart';
import 'source/comic/comic_details_capability.dart';
import 'source/account/source_daily_check_in_capability.dart';
import 'source/account/account_session_capability.dart';
import 'source/account/source_relogin_coordinator.dart';
import 'source/comments/comments_capability.dart';
import 'source/debug/debug_log_capability.dart';
import 'source/debug/debug_favorites_capability.dart';
import 'source/debug/debug_report_capability.dart';
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
import 'source/runtime/source_runtime_state_controller.dart';
import 'source/runtime/source_script_storage.dart';
import 'source/runtime/source_js_bridge_cookie_capability.dart';
import 'source/runtime/source_runtime_capability.dart';

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
export 'source/comments/comments_avatar_support.dart'
    show normalizeSourceAvatarUrl;
export 'source/runtime/source_runtime_capability.dart'
    show SourceVersionCheckResult;

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
      ensureSourceInitialized: (sourceKey) =>
          _runtimeCapability.ensureSourceInitialized(sourceKey),
      currentAccountForSource: (sourceKey) =>
          _accountCapability.currentAccountForSource(sourceKey),
      isLoggedForSource: (sourceKey) =>
          _accountCapability.isLoggedForSource(sourceKey),
    );
    _accountCapability = SourceAccountSessionCapability(
      runtimeHost: _runtimeHost,
    );
    _runtimeHost.addListener(notifyListeners);
    _reloginCoordinator = SourceReloginCoordinator(
      loginWithStoredAccount: (context, {required account, required password}) {
        final facade = (context as SourceFacadeReloginContext).facade;
        return _accountCapability.loginWithFacade(
          facade,
          account: account,
          password: password,
        );
      },
    );
    _runtimeCapability = SourceRuntimeCapability(
      runtimeHost: _runtimeHost,
      scriptStorage: _scriptStorage,
      jsBridgeCookieCapability: _jsBridgeCookieCapability,
      runtimeStateController: _runtimeStateController,
      reloginCoordinator: _reloginCoordinator,
      bundledInitAssetPath: _bundledInitAssetPath,
      sourceIndexUrls: _sourceIndexUrls,
    );
    _commentsCapability = SourceCommentsCapability(
      runtimeHost: _runtimeHost,
      reloginCoordinator: _reloginCoordinator,
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
    _favoritesDebugCapability = SourceFavoritesDebugCapability(
      activeFacade: () => facade,
      currentAccount: () => currentAccount,
      ensureFavoriteSessionReady: () => _ensureFavoriteSessionReady(),
      loadFavoriteComics: ({required page, required folderId}) =>
          _favoritesCapability.loadFavoriteComics(
            page: page,
            folderId: folderId,
          ),
    );
    _debugReportCapability = SourceDebugReportCapability(
      activeFacade: () => facade,
      currentAccount: () => currentAccount,
    );
  }

  final SourceSecureSessionStorage _secureSessionStorage;
  late final SourceRuntimeHost _runtimeHost;
  late final SourceAccountSessionCapability _accountCapability;
  late final SourceReloginCoordinator _reloginCoordinator;
  late final SourceRuntimeCapability _runtimeCapability;
  late final SourceCommentsCapability _commentsCapability;
  late final SourceFavoritesDebugCapability _favoritesDebugCapability;
  late final SourceDebugReportCapability _debugReportCapability;
  late final SourceDailyCheckInCapability _dailyCheckInCapability;
  late final SourceComicDetailsCache _comicDetailsCache;
  late final SourceComicDetailsCapability _comicDetailsCapability;
  late final SourceExploreCapability _exploreCapability;
  late final SourceCategoryCapability _categoryCapability;
  late final SourceImagePreparationCapability _imagePreparationCapability;
  late final SourceFavoritesCapability _favoritesCapability;
  late final SourceScriptStorage _scriptStorage = SourceScriptStorage(
    defaultSourceKey: hazukiDefaultSourceKey,
    normalizeSourceKey: _normalizeAllowedSourceKey,
    ensurePreferences: (sourceKey) =>
        _handleFor(sourceKey).facade.ensurePrefs(),
  );
  late final SourceJsBridgeCookieCapability _jsBridgeCookieCapability =
      SourceJsBridgeCookieCapability(activeHandle: () => _activeHandle);
  final SourceRuntimeStateController _runtimeStateController =
      SourceRuntimeStateController();

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
    return _jsBridgeCookieCapability.handleJsMessageForHandle(handle, message);
  }

  String? buildCookieHeader(String url) =>
      _jsBridgeCookieCapability.buildCookieHeader(url);

  String? buildCookieHeaderForHandle(
    SourceRuntimeHandleView handle,
    String url,
  ) => _jsBridgeCookieCapability.buildCookieHeaderForHandle(handle, url);

  Future<void> saveCookiesFromHeadersForHandle(
    SourceRuntimeHandleView handle,
    String url,
    Map<String, List<String>> headers,
  ) => _jsBridgeCookieCapability.saveCookiesFromHeadersForHandle(
    handle,
    url,
    headers,
  );

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
  SourceRuntimeState get runtimeState => facade.runtimeState;

  Future<void> prewarmInBackground() =>
      _runtimeCapability.prewarmInBackground();

  bool isSourceRuntimeRelatedError(Object? error) {
    final raw = (error ?? '').toString().trim().toLowerCase();
    return raw.isNotEmpty &&
        (raw.contains('source_not_initialized') ||
            raw.contains('source_init_failed') ||
            raw.contains('source_download_failed_without_cache') ||
            raw.contains('source_metadata_incomplete') ||
            raw.contains('module handler timeout') ||
            raw.contains('module not found') ||
            raw.contains('discover_load_timeout') ||
            raw.contains('search timeout') ||
            (raw.contains('favorite') && raw.contains('timed out')));
  }

  void logRuntimeRetryRequested(String source) =>
      _runtimeCapability.logRuntimeRetryRequested(source);

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

  Future<bool> _ensureFavoriteSessionReady({
    HazukiSourceFacade? targetFacade,
  }) => _reloginCoordinator.ensureFavoriteSessionReady(
    SourceFacadeReloginContext(targetFacade ?? facade),
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

  bool get isLogged => _accountCapability.isLogged;
  String? get currentAccount => _accountCapability.currentAccount;

  Future<void> login({required String account, required String password}) =>
      _accountCapability.login(account: account, password: password);
  Future<void> logout() => _accountCapability.logout();
  Future<String?> loadCurrentAvatarUrl() =>
      _accountCapability.loadCurrentAvatarUrl();

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  }) => _runtimeCapability.init(
    onSourceDownloadProgress: onSourceDownloadProgress,
    prewarm: prewarm,
  );
  Future<void> ensureInitialized({String? sourceKey}) =>
      _runtimeCapability.ensureInitialized(sourceKey: sourceKey);
  Future<void> ensureSourceInitialized(String sourceKey) =>
      _runtimeCapability.ensureSourceInitialized(sourceKey);
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _runtimeCapability.loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _runtimeCapability.setSoftwareLogCaptureEnabled(enabled);
  Future<bool> hasLocalJmSourceFile() =>
      _runtimeCapability.hasLocalJmSourceFile();
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _runtimeCapability.hasLocalSourceFile(sourceKey);
  Future<void> deleteLocalSourceFile(String sourceKey) =>
      _runtimeCapability.deleteLocalSourceFile(sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) =>
      _runtimeCapability.downloadSourceFile(sourceKey, onProgress: onProgress);
  Future<String?> readLocalActiveSourceIfExists() =>
      _runtimeCapability.readLocalActiveSourceIfExists();
  Future<String?> readLocalSourceIfExists(String sourceKey) =>
      _runtimeCapability.readLocalSourceIfExists(sourceKey);
  Future<String?> readLocalJmSourceIfExists() =>
      _runtimeCapability.readLocalJmSourceIfExists();
  Future<void> writeLocalActiveSource(String content) =>
      _runtimeCapability.writeLocalActiveSource(content);
  Future<void> writeLocalJmSource(String content) =>
      _runtimeCapability.writeLocalJmSource(content);
  Future<void> writeLocalSource(String sourceKey, String content) =>
      _runtimeCapability.writeLocalSource(sourceKey, content);
  Future<String> loadEditableActiveSource() =>
      _runtimeCapability.loadEditableActiveSource();
  Future<String> loadEditableJmSource() =>
      _runtimeCapability.loadEditableJmSource();
  Future<String> loadEditableSource(String sourceKey) =>
      _runtimeCapability.loadEditableSource(sourceKey);
  Future<void> saveEditedActiveSource(String content) =>
      _runtimeCapability.saveEditedActiveSource(content);
  Future<void> saveEditedJmSource(String content) =>
      _runtimeCapability.saveEditedJmSource(content);
  Future<void> saveEditedSource(String sourceKey, String content) =>
      _runtimeCapability.saveEditedSource(sourceKey, content);
  Future<bool> hasCustomEditedActiveSource() =>
      _runtimeCapability.hasCustomEditedActiveSource();
  Future<bool> hasCustomEditedSource(String sourceKey) =>
      _runtimeCapability.hasCustomEditedSource(sourceKey);
  Future<bool> hasCustomEditedJmSource() =>
      _runtimeCapability.hasCustomEditedJmSource();
  Future<void> reloadFromLocalSourceFiles() =>
      _runtimeCapability.reloadFromLocalSourceFiles();
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() =>
      _runtimeCapability.checkActiveSourceVersionFromCloud();
  Future<SourceVersionCheckResult?> checkJmSourceVersionFromCloud() =>
      _runtimeCapability.checkJmSourceVersionFromCloud();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) =>
      _runtimeCapability.downloadActiveSourceAndReload(onProgress: onProgress);
  Future<bool> downloadJmSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) => _runtimeCapability.downloadJmSourceAndReload(onProgress: onProgress);
  Future<bool> refreshSourceOnNetworkRecovery() =>
      _runtimeCapability.refreshSourceOnNetworkRecovery();

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) => _commentsCapability.loadCommentsPage(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
  );
  Future<List<ComicCommentData>> loadComments({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) => _commentsCapability.loadComments(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
  );
  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) => _commentsCapability.sendComment(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    content: content,
    replyTo: replyTo,
  );
  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) => _commentsCapability.likeComment(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    commentId: commentId,
    isLike: isLike,
  );
  bool supportCommentSendForSource(String sourceKey) =>
      _commentsCapability.supportCommentSendForSource(sourceKey);
  bool supportCommentLikeForSource(String sourceKey) =>
      _commentsCapability.supportCommentLikeForSource(sourceKey);
  bool supportCommentRepliesForSource(String sourceKey) =>
      _commentsCapability.supportCommentRepliesForSource(sourceKey);

  Future<void> warmUpFavoritesDebugInfo() =>
      _favoritesDebugCapability.warmUpFavoritesDebugInfo();
  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  }) => _favoritesDebugCapability.collectFavoritesDebugInfo(
    forceRefresh: forceRefresh,
  );
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      _debugReportCapability.collectTypedDebugInfo(type);
  Future<Map<String, dynamic>> collectNetworkDebugInfo() =>
      _debugReportCapability.collectNetworkDebugInfo();
  Future<Map<String, dynamic>> collectApplicationDebugInfo() =>
      _debugReportCapability.collectApplicationDebugInfo();
  Future<Map<String, dynamic>> collectReaderDebugInfo() =>
      _debugReportCapability.collectReaderDebugInfo();

  @override
  void dispose() {
    _runtimeHost.removeListener(notifyListeners);
    _runtimeHost.dispose();
    unawaited(_cloudFavoritesChangedController.close());
    super.dispose();
  }
}
