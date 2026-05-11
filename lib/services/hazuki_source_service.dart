import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/api.dart' show KeyParameter;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/chapter_title_resolver.dart';
import '../models/hazuki_models.dart';
import 'source/common/source_json_coerce.dart';
import 'source/common/source_prefs_keys.dart';
import 'source/debug/source_network_log_sink.dart';
import 'source/http/source_http_gateway.dart';
import 'source/runtime/line_settings_capability.dart';

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

part 'source/debug/debug_capability.dart';
part 'source/debug/debug_favorites_capability.dart';
part 'source/debug/debug_log_storage_capability.dart';
part 'source/debug/debug_report_capability.dart';

part 'source/favorites/favorites_capability.dart';
part 'source/favorites/favorites_collection_capability.dart';
part 'source/favorites/favorites_management_capability.dart';

part 'source/image/image_cache_capability.dart';
part 'source/image/image_cache_download_capability.dart';
part 'source/image/image_cache_maintenance_capability.dart';
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

const _sourceIndexUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json',
];

const _bundledInitAssetPath = 'assets/init.js';

enum DailyCheckInStatus { success, alreadyCheckedIn, skipped }

class DailyCheckInResult {
  const DailyCheckInResult._(this.status, [this.message]);

  const DailyCheckInResult.success([String? message])
    : this._(DailyCheckInStatus.success, message);

  const DailyCheckInResult.alreadyCheckedIn([String? message])
    : this._(DailyCheckInStatus.alreadyCheckedIn, message);

  const DailyCheckInResult.skipped([String? message])
    : this._(DailyCheckInStatus.skipped, message);

  final DailyCheckInStatus status;
  final String? message;

  bool get isSuccess => status == DailyCheckInStatus.success;
  bool get isAlreadyCheckedIn => status == DailyCheckInStatus.alreadyCheckedIn;
  bool get isSkipped => status == DailyCheckInStatus.skipped;
}

enum SourceRuntimePhase {
  idle,
  prewarming,
  loading,
  ready,
  failed,
  retrying,
  waitingForRestart,
}

enum SourceRuntimeStep {
  none,
  loadingCache,
  downloadingSource,
  creatingEngine,
  runningSourceInit,
}

@immutable
class SourceRuntimeState {
  const SourceRuntimeState({
    required this.phase,
    required this.step,
    required this.statusText,
    required this.updatedAt,
    this.debugDetail,
    this.error,
  });

  const SourceRuntimeState.idle()
    : this(
        phase: SourceRuntimePhase.idle,
        step: SourceRuntimeStep.none,
        statusText: 'source_idle',
        updatedAt: null,
      );

  final SourceRuntimePhase phase;
  final SourceRuntimeStep step;
  final String statusText;
  final DateTime? updatedAt;
  final String? debugDetail;
  final String? error;

  bool get isBusy =>
      phase == SourceRuntimePhase.prewarming ||
      phase == SourceRuntimePhase.loading ||
      phase == SourceRuntimePhase.retrying;
  bool get isReady => phase == SourceRuntimePhase.ready;
  bool get hasFailure => phase == SourceRuntimePhase.failed;
  bool get canRetry => phase == SourceRuntimePhase.failed;
  bool get isWaitingForRestart => phase == SourceRuntimePhase.waitingForRestart;
  bool get shouldSurfaceOnPage => isBusy || hasFailure || isWaitingForRestart;

  Map<String, dynamic> toDebugMap() {
    return <String, dynamic>{
      'phase': phase.name,
      'step': step.name,
      'statusText': statusText,
      'updatedAt': updatedAt?.toIso8601String(),
      'debugDetail': debugDetail,
      'error': error,
      'canRetry': canRetry,
      'shouldSurfaceOnPage': shouldSurfaceOnPage,
    };
  }
}

class HazukiSourceService extends ChangeNotifier {
  HazukiSourceService();

  final Dio dio = Dio(
    BaseOptions(
      responseType: ResponseType.plain,
      validateStatus: (status) => true,
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 35),
    ),
  );

  final SourceRuntimeKernel _runtimeKernel = SourceRuntimeKernel();
  final SourceSessionStore _sessionStore = SourceSessionStore();
  final SourceCacheStore _cacheStore = SourceCacheStore();
  final SourceDebugLogStore _debugLogStore = SourceDebugLogStore();
  late final SourceJsBridge _jsBridge = SourceJsBridge._(this);
  late final SourceNetworkLogSink _networkLogSink = SourceNetworkLogSink(this);
  late final SourceHttpGateway _httpGateway = SourceHttpGateway(this);
  late final HazukiSourceFacade facade = HazukiSourceFacade._(
    service: this,
    runtime: _runtimeKernel,
    session: _sessionStore,
    cache: _cacheStore,
    debug: _debugLogStore,
    js: _jsBridge,
    networkLogSink: _networkLogSink,
    httpGateway: _httpGateway,
  );

  late final LineSettingsCapability lineSettings = LineSettingsCapability(
    facade,
  );

  Future<Map<String, dynamic>> getLineSettingsSnapshot() =>
      lineSettings.getSnapshot();

  Future<void> updateLineSetting(String key, dynamic value) =>
      lineSettings.updateSetting(key, value);

  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) => lineSettings.refresh(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
  );

  FlutterQjs? get _engine => _runtimeKernel.engine;

  String get _statusText => _runtimeKernel.statusText;

  SourceRuntimeState get _runtimeState => _runtimeKernel.runtimeState;

  SourceMeta? get _sourceMeta => _runtimeKernel.sourceMeta;

  bool get _softwareLogCaptureEnabled =>
      _debugLogStore.softwareLogCaptureEnabled;

  LinkedHashMap<String, Uint8List> get _imageBytesCache =>
      _cacheStore.imageBytesCache;
  Map<String, Future<Uint8List>> get _imageDownloadInFlight =>
      _cacheStore.imageDownloadInFlight;
  LinkedHashMap<String, ComicDetailsData> get _comicDetailsMemoryCache =>
      _cacheStore.comicDetailsMemoryCache;

  List<ExploreSection>? get _exploreSectionsMemoryCache =>
      _cacheStore.exploreSectionsMemoryCache;
  set _exploreSectionsMemoryCache(List<ExploreSection>? value) =>
      _cacheStore.exploreSectionsMemoryCache = value;

  DateTime? get _exploreSectionsMemoryCachedAt =>
      _cacheStore.exploreSectionsMemoryCachedAt;
  set _exploreSectionsMemoryCachedAt(DateTime? value) =>
      _cacheStore.exploreSectionsMemoryCachedAt = value;

  Directory? get _imageCacheDir => _cacheStore.imageCacheDir;
  set _imageCacheDir(Directory? value) => _cacheStore.imageCacheDir = value;

  Directory? get _comicDetailsCacheDir => _cacheStore.comicDetailsCacheDir;
  set _comicDetailsCacheDir(Directory? value) =>
      _cacheStore.comicDetailsCacheDir = value;

  Directory? get _discoverCacheDir => _cacheStore.discoverCacheDir;
  set _discoverCacheDir(Directory? value) =>
      _cacheStore.discoverCacheDir = value;

  String get statusText => _statusText;
  SourceRuntimeState get sourceRuntimeState => _runtimeState;
  SourceMeta? get sourceMeta => _sourceMeta;
  String get activeSourceKey => _sourceMeta?.key.trim() ?? '';
  bool get isInitialized => _engine != null && _sourceMeta != null;
  bool get softwareLogCaptureEnabled => _softwareLogCaptureEnabled;

  void _notifyRuntimeStateChanged() {
    notifyListeners();
  }

  String _resolveActiveSourceKey([String? requestedSourceKey]) {
    final requested = requestedSourceKey?.trim() ?? '';
    final active = activeSourceKey;
    if (requested.isNotEmpty && active.isNotEmpty && requested != active) {
      throw Exception('source_mismatch:$requested:$active');
    }
    return requested.isNotEmpty ? requested : active;
  }

  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
  }) async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const SearchComicsResult(comics: [], maxPage: 0);
    }

    final normalizedPage = page < 1 ? 1 : page;
    final normalizedOrder = order.trim().isEmpty ? 'mr' : order.trim();

    final hasSearch = jsAsBool(engine.evaluate('!!this.__hazuki_source.search'));
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
    final dynamic resolved = await _awaitJsResult(result);

    if (resolved is! Map) {
      return const SearchComicsResult(comics: [], maxPage: null);
    }

    final map = Map<String, dynamic>.from(resolved);
    final comicsRaw = map['comics'];
    final List<ExploreComic> comics = comicsRaw is List
        ? _parseExploreComics(comicsRaw)
        : const <ExploreComic>[];

    final maxPageRaw = map['maxPage'];
    final maxPage = switch (maxPageRaw) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(maxPageRaw?.toString() ?? ''),
    };

    return SearchComicsResult(comics: comics, maxPage: maxPage);
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

  bool shouldSkipRelogin(Duration minInterval) {
    final last = lastReloginAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) < minInterval;
  }
}

class SourceSessionStore {
  SharedPreferences? prefs;

  Future<SharedPreferences> ensurePrefs() async {
    return prefs ??= await SharedPreferences.getInstance();
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
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return null;
    }
    return loadSourceStore(sourceKey)[dataKey];
  }

  Future<void> saveSourceData(
    String sourceKey,
    String dataKey,
    dynamic data,
  ) async {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    final store = loadSourceStore(sourceKey);
    store[dataKey] = data;
    await saveSourceStore(sourceKey, store);
  }

  Future<void> deleteSourceData(String sourceKey, String dataKey) async {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    final store = loadSourceStore(sourceKey);
    store.remove(dataKey);
    await saveSourceStore(sourceKey, store);
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

  List<String>? loadAccountDataSync(SourceMeta? sourceMeta) {
    final key = sourceMeta?.key;
    if (key == null) {
      return null;
    }

    final accountData = loadSourceData(key, 'account');
    if (accountData is List && accountData.length >= 2) {
      return [accountData[0].toString(), accountData[1].toString()];
    }
    return null;
  }

  List<_Cookie> _loadCookieStore() {
    final currentPrefs = prefs;
    if (currentPrefs == null) {
      return [];
    }

    final raw = currentPrefs.getString('cookie_store_v1');
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
    final currentPrefs = prefs;
    if (currentPrefs == null) {
      return;
    }
    await currentPrefs.setString(
      'cookie_store_v1',
      jsonEncode(cookies.map((e) => e.toMap()).toList()),
    );
  }
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
  DateTime? _lastAgeCleanupAt;
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
    lastSourceVersionDebugInfoStorage = softwareLogCaptureEnabled ? value : null;
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
  SourceJsBridge._(this._service);

  final HazukiSourceService _service;

  FlutterQjs? get engine => _service._engine;

  dynamic evaluate(String code, {String? name}) {
    return engine?.evaluate(code, name: name);
  }

  Future<dynamic> resolve(dynamic value) {
    return _awaitJsResult(value);
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
    required this.runtime,
    required this.session,
    required this.cache,
    required this.debug,
    required this.js,
    required this.networkLogSink,
    required this.httpGateway,
  }) : _service = service;

  final HazukiSourceService _service;
  final SourceRuntimeKernel runtime;
  final SourceSessionStore session;
  final SourceCacheStore cache;
  final SourceDebugLogStore debug;
  final SourceJsBridge js;
  final SourceNetworkLogSink networkLogSink;
  final SourceHttpGateway httpGateway;

  Future<void> ensureInitialized() => _service.ensureInitialized();

  Future<SharedPreferences> ensurePrefs() => session.ensurePrefs();

  bool get isLogged => _service.isLogged;

  SourceMeta? get sourceMeta => _service.sourceMeta;

  bool get softwareLogCaptureEnabled => _service.softwareLogCaptureEnabled;

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

  void notifyRuntimeStateChanged() => _service._notifyRuntimeStateChanged();

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
    _service.addApplicationLog(
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
      session.loadAccountDataSync(sourceMeta);

  List<_Cookie> _loadCookieStore() => session._loadCookieStore();

  Future<void> _saveCookieStore(List<_Cookie> cookies) {
    return session._saveCookieStore(cookies);
  }

  Future<Directory> ensureImageCacheDir() => _service._ensureImageCacheDir();

  Future<int> computeImageCacheSizeBytes() =>
      _service._computeImageCacheSizeBytes();

  Future<void> enforceImageCachePolicy({bool force = false}) {
    return _service._enforceImageCachePolicy(force: force);
  }

  Uri resolveImageBaseUri(String imageUrl, Uri baseUri) {
    final imageUri = Uri.tryParse(imageUrl);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      return imageUri;
    }
    return baseUri;
  }
}
