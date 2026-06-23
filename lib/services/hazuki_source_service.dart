import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

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

import '../shared/chapter_title_resolver.dart';
import '../shared/preferences/hazuki_preference_keys.dart';
import '../models/hazuki_models.dart';
import 'source/common/source_json_coerce.dart';
import 'source/common/source_prefs_keys.dart';
import 'source/debug/debug_log_capability.dart';
import 'source/debug/debug_log_internals.dart';
import 'source/debug/source_network_log_sink.dart';
import 'source/http/source_http_gateway.dart';
import 'source/image/image_cache_capability.dart';
import 'source/models/source_contract_models.dart';
import 'source/models/source_identity.dart';
import 'source/runtime/explore_cache_capability.dart';
import 'source/runtime/line_settings_capability.dart';
import 'source/runtime/source_secure_session_storage.dart';
import 'network/hazuki_network.dart';

export 'source/models/source_contract_models.dart';
export 'source/models/source_identity.dart';

part 'source/explore_capability.dart';

part 'source/account/account_session_capability.dart';
part 'source/account/account_session_retry_support.dart';
part 'source/account/check_in_capability.dart';

part 'source/category/category_capability.dart';
part 'source/category/category_ranking_capability.dart';
part 'source/category/category_view_more_capability.dart';

part 'source/comic/comic_details_cache_support.dart';
part 'source/comic/comic_details_capability.dart';

part 'source/comments/comments_avatar_support.dart';
part 'source/comments/comments_capability.dart';

part 'source/debug/debug_favorites_capability.dart';
part 'source/debug/debug_report_capability.dart';

part 'source/favorites/favorites_capability.dart';
part 'source/favorites/favorites_collection_capability.dart';
part 'source/favorites/favorites_management_capability.dart';

part 'source/image/image_prepare_capability.dart';
part 'source/image/image_prepare_segment_support.dart';
part 'source/image/image_prepare_unscramble_support.dart';

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

Dio _createSourceDio() {
  return createHazukiDio(
    baseOptions: BaseOptions(
      responseType: ResponseType.plain,
      validateStatus: (status) => true,
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 35),
    ),
  );
}

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

class SourceRuntimeRegistry extends ChangeNotifier {
  SourceRuntimeRegistry._();

  HazukiSourceService? _service;

  void _bind(HazukiSourceService service) {
    _service = service;
  }

  HazukiSourceService get _boundService {
    final service = _service;
    if (service == null) {
      throw StateError('source_runtime_registry_not_bound');
    }
    return service;
  }

  List<SourceCatalogEntry> get allowedSources => hazukiAllowedSourceCatalog;

  String get activeSourceKey => _boundService.activeSourceKey;

  SourceCatalogEntry activeSourceDefinition() => definitionFor(activeSourceKey);

  SourceCatalogEntry definitionFor(String sourceKey) {
    return _boundService._definitionForSourceKey(sourceKey);
  }

  bool isAllowedSourceKey(String sourceKey) {
    final normalized = sourceKey.trim();
    return allowedSources.any((entry) => entry.normalizedKey == normalized);
  }

  Future<void> loadActiveSourcePreference() {
    return _boundService.loadActiveSourcePreference();
  }

  Future<void> activateSource(String sourceKey) {
    return _boundService.activateSource(sourceKey);
  }

  Future<void> ensureInitialized({String? sourceKey}) {
    return _boundService.ensureInitialized(sourceKey: sourceKey);
  }

  String? currentAccountForSource(String sourceKey) {
    return _boundService.currentAccountForSource(sourceKey);
  }

  bool isLoggedForSource(String sourceKey) {
    return _boundService.isLoggedForSource(sourceKey);
  }

  void _notify() {
    notifyListeners();
  }
}

class SourceRuntimeHandle {
  SourceRuntimeHandle({required this.service, required this.sourceKey});

  final HazukiSourceService service;
  final String sourceKey;
  final Dio dio = _createSourceDio();
  final SourceRuntimeKernel runtime = SourceRuntimeKernel();
  bool _disposed = false;
  bool _disposeRequested = false;
  int _activeOperationCount = 0;
  late final SourceSessionStore session = SourceSessionStore(
    sourceKey: sourceKey,
    secureStorage: service._secureSessionStorage,
  );
  final SourceCacheStore cache = SourceCacheStore();
  final SourceDebugLogStore debug = SourceDebugLogStore();
  bool dioCookieBridgeConfigured = false;

  late final SourceJsBridge js = SourceJsBridge._(this);
  late final SourceNetworkLogSink networkLogSink = SourceNetworkLogSink(
    service,
    this,
  );
  late final SourceHttpGateway httpGateway = SourceHttpGateway(service, this);
  late final HazukiSourceFacade facade = HazukiSourceFacade._(
    service: service,
    handle: this,
    runtime: runtime,
    session: session,
    cache: cache,
    debug: debug,
    js: js,
    networkLogSink: networkLogSink,
    httpGateway: httpGateway,
  );
  late final LineSettingsCapability lineSettings = LineSettingsCapability(
    facade,
  );
  late final ImageCacheCapability imageCache = ImageCacheCapability(this);
  late final ExploreCacheCapability exploreCache = ExploreCacheCapability(this);
  late final DebugLogCapability debugLog = DebugLogCapability(facade);

  bool get isDisposed => _disposed;

  Future<T> runOperation<T>(Future<T> Function() operation) async {
    if (_disposed || _disposeRequested) {
      throw StateError('source_runtime_disposed:$sourceKey');
    }
    _activeOperationCount += 1;
    try {
      return await operation();
    } finally {
      _activeOperationCount -= 1;
      if (_disposeRequested && _activeOperationCount == 0) {
        _disposeNow();
      }
    }
  }

  void requestDispose() {
    if (_disposed || _disposeRequested) {
      return;
    }
    _disposeRequested = true;
    if (_activeOperationCount == 0) {
      _disposeNow();
    }
  }

  void _disposeNow() {
    if (_disposed) {
      return;
    }
    _disposed = true;

    final engine = runtime.engine;
    runtime
      ..engine = null
      ..initFuture = null
      ..sourceMeta = null
      ..lastReloginAt = null
      ..transientAvatarUrl = null;
    try {
      dio.close(force: true);
    } catch (_) {}
    try {
      engine?.close();
    } catch (_) {}
    session.clearMemory();
    cache.clearMemory();
    debug.clearCapturedLogs();
  }
}

class HazukiSourceService extends ChangeNotifier {
  HazukiSourceService({SourceSecureSessionStorage? secureSessionStorage})
    : _secureSessionStorage =
          secureSessionStorage ?? FlutterSourceSecureSessionStorage() {
    runtimeRegistry._bind(this);
  }

  final SourceRuntimeRegistry runtimeRegistry = SourceRuntimeRegistry._();
  final SourceSecureSessionStorage _secureSessionStorage;
  final Map<String, SourceRuntimeHandle> _runtimeHandles =
      <String, SourceRuntimeHandle>{};
  String _activeSourceKey = hazukiDefaultSourceKey;
  Future<void> _activationTail = Future<void>.value();

  final StreamController<void> _cloudFavoritesChangedController =
      StreamController<void>.broadcast();
  Stream<void> get cloudFavoritesChangedStream =>
      _cloudFavoritesChangedController.stream;

  void notifyCloudFavoritesChanged() {
    _cloudFavoritesChangedController.add(null);
  }

  SourceRuntimeHandle get _activeHandle => _handleFor(_activeSourceKey);

  SourceRuntimeHandle _handleFor(String sourceKey) {
    final normalized = _normalizeAllowedSourceKey(sourceKey);
    return _runtimeHandles.putIfAbsent(
      normalized,
      () => SourceRuntimeHandle(service: this, sourceKey: normalized),
    );
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
    String sourceKey = '',
  }) => _imageCacheForSourceRequest(sourceKey).downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
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

  Directory? get _comicDetailsCacheDir =>
      _activeHandle.cache.comicDetailsCacheDir;
  set _comicDetailsCacheDir(Directory? value) =>
      _activeHandle.cache.comicDetailsCacheDir = value;

  String get statusText => _statusText;
  SourceRuntimeState get sourceRuntimeState => _runtimeState;
  SourceMeta? get sourceMeta => _sourceMeta;
  String get activeSourceKey => _activeSourceKey;
  bool get isActiveJmSource => isHazukiJmSourceKey(_activeSourceKey);
  bool get isActiveCopyMangaSource =>
      isHazukiCopyMangaSourceKey(_activeSourceKey);
  bool get isActiveDailyCheckInSource =>
      isHazukiJmSourceKey(_activeSourceKey) ||
      isHazukiPicacgSourceKey(_activeSourceKey);
  bool get isInitialized => _engine != null && _sourceMeta != null;
  bool get softwareLogCaptureEnabled => _softwareLogCaptureEnabled;

  void _notifyRuntimeStateChanged() {
    notifyListeners();
    runtimeRegistry._notify();
  }

  SourceCatalogEntry _definitionForSourceKey(String sourceKey) {
    final normalized = _normalizeAllowedSourceKey(sourceKey);
    return hazukiAllowedSourceCatalog.firstWhere(
      (entry) => entry.normalizedKey == normalized,
    );
  }

  String _normalizeAllowedSourceKey(String sourceKey) {
    final normalized = sourceKey.trim().isEmpty
        ? hazukiDefaultSourceKey
        : sourceKey.trim();
    final allowed = hazukiAllowedSourceCatalog.any(
      (entry) => entry.normalizedKey == normalized,
    );
    if (!allowed) {
      throw Exception('source_not_allowed:$normalized');
    }
    return normalized;
  }

  Future<void> loadActiveSourcePreference() async {
    final load = _activationTail.then<void>(
      (_) => _loadActiveSourcePreferenceSerially(),
      onError: (_, _) => _loadActiveSourcePreferenceSerially(),
    );
    _activationTail = load;
    await load;
  }

  Future<void> _loadActiveSourcePreferenceSerially() async {
    final prefs = await _activeHandle.session.ensurePrefs();
    for (final source in hazukiAllowedSourceCatalog) {
      final session = _handleFor(source.key).session;
      session.prefs = prefs;
      await session.ensurePrefs();
    }
    final saved = prefs.getString(SourcePrefsKeys.activeSourceKey);
    if (saved != null && saved.trim().isNotEmpty) {
      final normalized = saved.trim();
      final allowed = hazukiAllowedSourceCatalog.any(
        (entry) => entry.normalizedKey == normalized,
      );
      if (allowed) {
        _activeSourceKey = normalized;
      } else {
        _activeSourceKey = hazukiDefaultSourceKey;
        await prefs.setString(
          SourcePrefsKeys.activeSourceKey,
          hazukiDefaultSourceKey,
        );
      }
    }
  }

  Future<void> activateSource(String sourceKey) async {
    final normalized = _normalizeAllowedSourceKey(sourceKey);
    final activation = _activationTail.then<void>(
      (_) => _activateSourceSerially(normalized),
      onError: (_, _) => _activateSourceSerially(normalized),
    );
    _activationTail = activation;
    await activation;
  }

  Future<void> _activateSourceSerially(String normalized) async {
    if (normalized == _activeSourceKey) {
      return;
    }
    final previousSourceKey = _activeSourceKey;
    final previousHandle = _runtimeHandles[previousSourceKey];
    final nextHandle = _handleFor(normalized);
    final prefs = await nextHandle.session.ensurePrefs();
    await prefs.setString(SourcePrefsKeys.activeSourceKey, normalized);
    _activeSourceKey = normalized;
    if (identical(_runtimeHandles[previousSourceKey], previousHandle)) {
      _runtimeHandles.remove(previousSourceKey);
      previousHandle?.requestDispose();
    }
    notifyListeners();
    runtimeRegistry._notify();
  }

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
}

class SourceRuntimeKernel {
  FlutterQjs? engine;
  Future<void>? initFuture;
  String statusText = 'source_idle';
  SourceRuntimeState runtimeState = const SourceRuntimeState.idle();
  SourceMeta? sourceMeta;
  bool isRefreshingSource = false;
  DateTime? lastReloginAt;
  String? transientAvatarUrl;

  bool shouldSkipRelogin(Duration minInterval) {
    final last = lastReloginAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) < minInterval;
  }
}

class SourceSessionStore {
  SourceSessionStore({
    required this.sourceKey,
    required SourceSecureSessionStorage secureStorage,
  }) : _secureStorage = secureStorage;

  final String sourceKey;
  final SourceSecureSessionStorage _secureStorage;
  final Map<String, _SecureSourceSessionData> _secureCache =
      <String, _SecureSourceSessionData>{};
  SharedPreferences? prefs;

  void clearMemory() {
    _secureCache.clear();
    prefs = null;
  }

  Future<SharedPreferences> ensurePrefs() async {
    final current = prefs ??= await SharedPreferences.getInstance();
    await _migrateLegacySessionData(current);
    await _loadSecureSessionData(sourceKey);
    return current;
  }

  Map<String, dynamic> loadSourceStore(String sourceKey) {
    final currentPrefs = prefs;
    if (currentPrefs == null || sourceKey.isEmpty) {
      return {};
    }

    final raw = currentPrefs.getString('source_data_$sourceKey');
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveSourceStore(
    String sourceKey,
    Map<String, dynamic> store,
  ) async {
    final currentPrefs = prefs;
    if (currentPrefs == null || sourceKey.isEmpty) {
      return;
    }
    await currentPrefs.setString('source_data_$sourceKey', jsonEncode(store));
  }

  dynamic loadSourceData(String sourceKey, String dataKey) {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty || dataKey.isEmpty) {
      return null;
    }
    if (dataKey == 'account') {
      return _secureDataFor(normalizedSourceKey).account ??
          loadSourceStore(normalizedSourceKey)['account'];
    }
    if (dataKey == 'token') {
      return _secureDataFor(normalizedSourceKey).token ??
          loadSourceStore(normalizedSourceKey)['token'];
    }
    return loadSourceStore(normalizedSourceKey)[dataKey];
  }

  Future<void> saveSourceData(
    String sourceKey,
    String dataKey,
    dynamic data,
  ) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    if (dataKey == 'account') {
      final accountData = _normalizeAccountData(data);
      if (accountData == null) {
        await deleteSourceData(normalizedSourceKey, dataKey);
        return;
      }
      await _secureStorage.write(
        SourceSecureSessionStorageKeys.account(normalizedSourceKey),
        jsonEncode(accountData),
      );
      _secureDataFor(normalizedSourceKey).account = accountData;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    if (dataKey == 'token') {
      final token = data?.toString();
      if (token == null || token.isEmpty) {
        await deleteSourceData(normalizedSourceKey, dataKey);
        return;
      }
      await _secureStorage.write(
        SourceSecureSessionStorageKeys.token(normalizedSourceKey),
        token,
      );
      _secureDataFor(normalizedSourceKey).token = token;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    final store = loadSourceStore(normalizedSourceKey);
    store[dataKey] = data;
    await saveSourceStore(normalizedSourceKey, store);
  }

  Future<void> deleteSourceData(String sourceKey, String dataKey) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    if (dataKey == 'account') {
      await _secureStorage.delete(
        SourceSecureSessionStorageKeys.account(normalizedSourceKey),
      );
      _secureDataFor(normalizedSourceKey).account = null;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    if (dataKey == 'token') {
      await _secureStorage.delete(
        SourceSecureSessionStorageKeys.token(normalizedSourceKey),
      );
      _secureDataFor(normalizedSourceKey).token = null;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    final store = loadSourceStore(normalizedSourceKey);
    store.remove(dataKey);
    await saveSourceStore(normalizedSourceKey, store);
  }

  dynamic loadSourceSetting({
    required String sourceKey,
    required String settingKey,
    required SourceMeta? sourceMeta,
  }) {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return null;
    }

    final store = loadSourceStore(sourceKey);
    final settings = store['settings'];
    if (settings is Map && settings.containsKey(settingKey)) {
      return settings[settingKey];
    }

    if (sourceMeta?.key == sourceKey) {
      return sourceMeta?.settingsDefaults[settingKey];
    }

    return null;
  }

  Future<void> saveSourceSetting(
    String sourceKey,
    String settingKey,
    dynamic value,
  ) async {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return;
    }
    final store = loadSourceStore(sourceKey);
    final settingsRaw = store['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};
    settings[settingKey] = value;
    store['settings'] = settings;
    await saveSourceStore(sourceKey, store);
  }

  List<String>? loadAccountDataSync(
    SourceMeta? sourceMeta, {
    String? fallbackSourceKey,
  }) {
    final key = (sourceMeta?.key ?? fallbackSourceKey ?? sourceKey).trim();
    if (key.isEmpty) {
      return null;
    }

    final accountData = loadSourceData(key, 'account');
    if (accountData is List && accountData.length >= 2) {
      return [accountData[0].toString(), accountData[1].toString()];
    }
    return null;
  }

  List<_Cookie> _loadCookieStore() {
    final raw =
        _secureDataFor(sourceKey).cookiesRaw ??
        prefs?.getString(_cookieStoreKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => _Cookie.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveCookieStore(List<_Cookie> cookies) async {
    if (cookies.isEmpty) {
      await _secureStorage.delete(
        SourceSecureSessionStorageKeys.cookies(sourceKey),
      );
      _secureDataFor(sourceKey).cookiesRaw = null;
      await prefs?.remove(_cookieStoreKey);
      return;
    }
    final raw = jsonEncode(cookies.map((e) => e.toMap()).toList());
    await _secureStorage.write(
      SourceSecureSessionStorageKeys.cookies(sourceKey),
      raw,
    );
    _secureDataFor(sourceKey).cookiesRaw = raw;
    await prefs?.remove(_cookieStoreKey);
  }

  String get _cookieStoreKey => 'cookie_store_v2_${sourceKey.trim()}';

  Future<void> _migrateLegacySessionData(SharedPreferences prefs) async {
    await prefs.remove('cookie_store_v1');
    if (prefs.getBool(SourcePrefsKeys.sourceSecureSessionMigration) == true) {
      return;
    }

    var migrationComplete = true;

    for (final key in prefs.getKeys().where(_isSourceDataPrefsKey).toList()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      final migratedSourceKey = key.substring('source_data_'.length);
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final sanitized = Map<String, dynamic>.from(decoded);
        var changed = false;

        if (sanitized.containsKey('account')) {
          final accountData = _normalizeAccountData(sanitized['account']);
          if (accountData != null) {
            try {
              await _secureStorage.write(
                SourceSecureSessionStorageKeys.account(migratedSourceKey),
                jsonEncode(accountData),
              );
              _secureDataFor(migratedSourceKey).account = accountData;
              sanitized.remove('account');
              changed = true;
            } catch (_) {
              migrationComplete = false;
            }
          } else {
            sanitized.remove('account');
            changed = true;
          }
        }

        if (sanitized.containsKey('token')) {
          final token = sanitized['token']?.toString();
          if (token != null && token.isNotEmpty) {
            try {
              await _secureStorage.write(
                SourceSecureSessionStorageKeys.token(migratedSourceKey),
                token,
              );
              _secureDataFor(migratedSourceKey).token = token;
              sanitized.remove('token');
              changed = true;
            } catch (_) {
              migrationComplete = false;
            }
          } else {
            sanitized.remove('token');
            changed = true;
          }
        }

        if (changed) {
          await prefs.setString(key, jsonEncode(sanitized));
        }
      } catch (_) {
        migrationComplete = false;
      }
    }

    for (final key in prefs.getKeys().where(_isCookiePrefsKey).toList()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        await prefs.remove(key);
        continue;
      }
      final migratedSourceKey = key.substring('cookie_store_v2_'.length);
      try {
        await _secureStorage.write(
          SourceSecureSessionStorageKeys.cookies(migratedSourceKey),
          raw,
        );
        _secureDataFor(migratedSourceKey).cookiesRaw = raw;
        await prefs.remove(key);
      } catch (_) {
        migrationComplete = false;
      }
    }

    if (migrationComplete) {
      await prefs.setBool(SourcePrefsKeys.sourceSecureSessionMigration, true);
      await prefs.setBool(SourcePrefsKeys.sourceSessionScopeMigration, true);
    }
  }

  Future<void> _loadSecureSessionData(String sourceKey) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return;
    }
    final data = _secureDataFor(normalizedSourceKey);
    data.account = _decodeAccountData(
      await _safeRead(
        SourceSecureSessionStorageKeys.account(normalizedSourceKey),
      ),
    );
    data.token = await _safeRead(
      SourceSecureSessionStorageKeys.token(normalizedSourceKey),
    );
    data.cookiesRaw = await _safeRead(
      SourceSecureSessionStorageKeys.cookies(normalizedSourceKey),
    );
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _secureStorage.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeLegacySourceDataKey(
    String sourceKey,
    String dataKey,
  ) async {
    final store = loadSourceStore(sourceKey);
    if (!store.containsKey(dataKey)) {
      return;
    }
    store.remove(dataKey);
    await saveSourceStore(sourceKey, store);
  }

  _SecureSourceSessionData _secureDataFor(String sourceKey) {
    return _secureCache.putIfAbsent(
      sourceKey.trim(),
      _SecureSourceSessionData.new,
    );
  }

  static bool _isSourceDataPrefsKey(String key) {
    return key.startsWith('source_data_');
  }

  static bool _isCookiePrefsKey(String key) {
    return key.startsWith('cookie_store_v2_');
  }

  static List<String>? _normalizeAccountData(dynamic value) {
    if (value is! List || value.length < 2) {
      return null;
    }
    return [value[0].toString(), value[1].toString()];
  }

  static List<String>? _decodeAccountData(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return _normalizeAccountData(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

class _SecureSourceSessionData {
  List<String>? account;
  String? token;
  String? cookiesRaw;
}

class SourceCacheStore {
  final LinkedHashMap<String, Uint8List> imageBytesCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> imageDownloadInFlight =
      <String, Future<Uint8List>>{};
  final LinkedHashMap<String, ComicDetailsData> comicDetailsMemoryCache =
      LinkedHashMap<String, ComicDetailsData>();
  final Map<String, Future<ComicDetailsData>> comicDetailsInFlight =
      <String, Future<ComicDetailsData>>{};
  List<ExploreSection>? exploreSectionsMemoryCache;
  DateTime? exploreSectionsMemoryCachedAt;
  List<CategoryTagGroup>? categoryTagGroupsMemoryCache;
  DateTime? categoryTagGroupsMemoryCachedAt;
  Directory? imageCacheDir;
  Directory? comicDetailsCacheDir;
  Directory? discoverCacheDir;

  void clearMemory() {
    imageBytesCache.clear();
    imageDownloadInFlight.clear();
    comicDetailsMemoryCache.clear();
    comicDetailsInFlight.clear();
    exploreSectionsMemoryCache = null;
    exploreSectionsMemoryCachedAt = null;
    categoryTagGroupsMemoryCache = null;
    categoryTagGroupsMemoryCachedAt = null;
    imageCacheDir = null;
    comicDetailsCacheDir = null;
    discoverCacheDir = null;
  }

  Uint8List? touchImageBytes(String rawUrl) {
    final normalizedUrl = rawUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }
    final cached = imageBytesCache[normalizedUrl];
    if (cached == null) {
      return null;
    }
    imageBytesCache.remove(normalizedUrl);
    imageBytesCache[normalizedUrl] = cached;
    return cached;
  }

  void evictImageBytes(Iterable<String> urls) {
    for (final url in urls) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) {
        continue;
      }
      imageBytesCache.remove(normalizedUrl);
    }
  }

  void putImageBytes(String url, Uint8List bytes, {int maxEntries = 80}) {
    imageBytesCache.remove(url);
    imageBytesCache[url] = bytes;
    while (imageBytesCache.length > maxEntries) {
      imageBytesCache.remove(imageBytesCache.keys.first);
    }
  }

  List<CategoryTagGroup>? getCategoryTagGroupsFromMemoryCache(Duration ttl) {
    final groups = categoryTagGroupsMemoryCache;
    final cachedAt = categoryTagGroupsMemoryCachedAt;
    if (groups == null || cachedAt == null) {
      return null;
    }
    if (DateTime.now().difference(cachedAt) > ttl) {
      categoryTagGroupsMemoryCache = null;
      categoryTagGroupsMemoryCachedAt = null;
      return null;
    }
    return groups;
  }

  void clearCategoryTagGroupsMemoryCache() {
    categoryTagGroupsMemoryCache = null;
    categoryTagGroupsMemoryCachedAt = null;
  }

  void putCategoryTagGroupsInMemoryCache(List<CategoryTagGroup> groups) {
    categoryTagGroupsMemoryCache = groups;
    categoryTagGroupsMemoryCachedAt = DateTime.now();
  }
}

class SourceDebugLogStore {
  Map<String, dynamic>? favoritesDebugCache;
  bool isWarmingUpFavoritesDebug = false;
  bool softwareLogCaptureEnabled = false;
  final List<Map<String, dynamic>> recentNetworkLogs = [];
  final List<Map<String, dynamic>> recentApplicationLogs = [];
  final List<Map<String, dynamic>> recentReaderLogs = [];
  final List<Map<String, dynamic>> recentErrorLogs = [];
  final List<Map<String, dynamic>> recentActionLogs = [];
  final List<Map<String, dynamic>> recentSystemLogs = [];
  final List<Map<String, dynamic>> recentPerformanceLogs = [];
  int networkLogDedupedCount = 0;
  DateTime? lastAgeCleanupAt;
  Map<String, dynamic>? lastLoginDebugInfoStorage;
  Map<String, dynamic>? lastSourceVersionDebugInfoStorage;

  Map<String, dynamic>? get lastLoginDebugInfo =>
      softwareLogCaptureEnabled ? lastLoginDebugInfoStorage : null;
  set lastLoginDebugInfo(Map<String, dynamic>? value) {
    lastLoginDebugInfoStorage = softwareLogCaptureEnabled ? value : null;
  }

  Map<String, dynamic>? get lastSourceVersionDebugInfo =>
      softwareLogCaptureEnabled ? lastSourceVersionDebugInfoStorage : null;
  set lastSourceVersionDebugInfo(Map<String, dynamic>? value) {
    lastSourceVersionDebugInfoStorage = softwareLogCaptureEnabled
        ? value
        : null;
  }

  void clearCapturedLogs() {
    favoritesDebugCache = null;
    recentNetworkLogs.clear();
    recentApplicationLogs.clear();
    recentReaderLogs.clear();
    recentErrorLogs.clear();
    recentActionLogs.clear();
    recentSystemLogs.clear();
    recentPerformanceLogs.clear();
    networkLogDedupedCount = 0;
    lastLoginDebugInfoStorage = null;
    lastSourceVersionDebugInfoStorage = null;
  }
}

class SourceJsBridge {
  SourceJsBridge._(this._handle);

  final SourceRuntimeHandle _handle;

  FlutterQjs? get engine => _handle.runtime.engine;

  dynamic evaluate(String code, {String? name}) {
    return engine?.evaluate(code, name: name);
  }

  Future<dynamic> resolve(dynamic value) {
    return awaitJsResult(value);
  }

  bool asBool(dynamic value) => jsAsBool(value);

  int? asInt(dynamic value) => jsAsInt(value);

  String evaluateString(String code) {
    return (evaluate(code) ?? '').toString().trim();
  }
}

class HazukiSourceFacade {
  HazukiSourceFacade._({
    required HazukiSourceService service,
    required this.handle,
    required this.runtime,
    required this.session,
    required this.cache,
    required this.debug,
    required this.js,
    required this.networkLogSink,
    required this.httpGateway,
  }) : _service = service;

  final HazukiSourceService _service;
  final SourceRuntimeHandle handle;
  final SourceRuntimeKernel runtime;
  final SourceSessionStore session;
  final SourceCacheStore cache;
  final SourceDebugLogStore debug;
  final SourceJsBridge js;
  final SourceNetworkLogSink networkLogSink;
  final SourceHttpGateway httpGateway;

  String get sourceKey => handle.sourceKey;

  Future<void> ensureInitialized() =>
      _service.ensureSourceInitialized(sourceKey);

  Future<SharedPreferences> ensurePrefs() => session.ensurePrefs();

  bool get isLogged =>
      session.loadAccountDataSync(sourceMeta, fallbackSourceKey: sourceKey) !=
      null;

  SourceMeta? get sourceMeta => runtime.sourceMeta;

  bool get softwareLogCaptureEnabled => debug.softwareLogCaptureEnabled;

  DateTime? get lastReloginAt => runtime.lastReloginAt;
  set lastReloginAt(DateTime? value) => runtime.lastReloginAt = value;

  bool get isRefreshingSource => runtime.isRefreshingSource;
  set isRefreshingSource(bool value) => runtime.isRefreshingSource = value;

  SourceRuntimeState get runtimeState => runtime.runtimeState;
  set runtimeState(SourceRuntimeState value) => runtime.runtimeState = value;

  String get statusText => runtime.statusText;
  set statusText(String value) => runtime.statusText = value;

  Future<void>? get initFuture => runtime.initFuture;
  set initFuture(Future<void>? value) => runtime.initFuture = value;

  void notifyRuntimeStateChanged() {
    if (_service.activeSourceKey == sourceKey) {
      _service._notifyRuntimeStateChanged();
    } else {
      _service.runtimeRegistry._notify();
    }
  }

  Map<String, dynamic>? get favoritesDebugCache => debug.favoritesDebugCache;
  set favoritesDebugCache(Map<String, dynamic>? value) =>
      debug.favoritesDebugCache = value;

  Map<String, dynamic>? get lastLoginDebugInfo => debug.lastLoginDebugInfo;
  set lastLoginDebugInfo(Map<String, dynamic>? value) =>
      debug.lastLoginDebugInfo = value;

  Map<String, dynamic>? get lastSourceVersionDebugInfo =>
      debug.lastSourceVersionDebugInfo;
  set lastSourceVersionDebugInfo(Map<String, dynamic>? value) =>
      debug.lastSourceVersionDebugInfo = value;

  void clearCapturedLogs() => debug.clearCapturedLogs();

  dynamic loadSourceData(String sourceKey, String dataKey) {
    return session.loadSourceData(sourceKey, dataKey);
  }

  Future<void> saveSourceData(String sourceKey, String dataKey, dynamic data) {
    return session.saveSourceData(sourceKey, dataKey, data);
  }

  Future<void> deleteSourceData(String sourceKey, String dataKey) {
    return session.deleteSourceData(sourceKey, dataKey);
  }

  void addApplicationLog({
    required String title,
    String level = 'info',
    String source = 'app',
    Object? content,
  }) {
    handle.debugLog.addApplicationLog(
      title: title,
      level: level,
      source: source,
      content: content,
    );
  }

  Object? loadSourceSetting(String sourceKey, String settingKey) {
    return session.loadSourceSetting(
      sourceKey: sourceKey,
      settingKey: settingKey,
      sourceMeta: sourceMeta,
    );
  }

  Future<void> saveSourceSetting(
    String sourceKey,
    String settingKey,
    Object? value,
  ) {
    return session.saveSourceSetting(sourceKey, settingKey, value);
  }

  List<String>? loadAccountDataSync() =>
      session.loadAccountDataSync(sourceMeta, fallbackSourceKey: sourceKey);

  List<_Cookie> _loadCookieStore() => session._loadCookieStore();

  Future<void> _saveCookieStore(List<_Cookie> cookies) {
    return session._saveCookieStore(cookies);
  }

  Future<Directory> ensureImageCacheDir() => handle.imageCache.ensureCacheDir();

  Future<int> computeImageCacheSizeBytes() =>
      handle.imageCache.computeSizeBytes();

  Future<void> enforceImageCachePolicy({bool force = false}) {
    return handle.imageCache.enforcePolicy(force: force);
  }

  Uri resolveImageBaseUri(String imageUrl, Uri baseUri) {
    final imageUri = Uri.tryParse(imageUrl);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      return imageUri;
    }
    return baseUri;
  }
}
