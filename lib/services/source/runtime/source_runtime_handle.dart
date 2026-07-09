import 'package:dio/dio.dart';

import '../../network/hazuki_network.dart';
import '../debug/debug_log_capability.dart';
import '../debug/source_debug_log_store.dart';
import '../debug/source_network_log_sink.dart';
import '../http/source_http_gateway.dart';
import '../image/image_cache_capability.dart';
import 'explore_cache_capability.dart';
import 'line_settings_capability.dart';
import 'source_cache_store.dart';
import 'source_cookie_store.dart';
import 'source_runtime_coordinator.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_kernel.dart';
import 'source_secure_session_storage.dart';
import 'source_session_store.dart';

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

class SourceRuntimeHandle
    implements SourceRuntimeResource, SourceRuntimeHandleView {
  SourceRuntimeHandle({
    required this.sourceKey,
    required SourceSecureSessionStorage secureStorage,
    required Future<void> Function(String sourceKey) ensureInitialized,
    required void Function(String sourceKey) notifyRuntimeStateChanged,
  }) : _ensureInitialized = ensureInitialized,
       _notifyRuntimeStateChanged = notifyRuntimeStateChanged,
       _secureStorage = secureStorage;

  @override
  final String sourceKey;
  final SourceSecureSessionStorage _secureStorage;
  final Future<void> Function(String sourceKey) _ensureInitialized;
  final void Function(String sourceKey) _notifyRuntimeStateChanged;
  final Dio dio = _createSourceDio();
  final SourceRuntimeKernel runtime = SourceRuntimeKernel();
  bool _disposed = false;
  bool _disposeRequested = false;
  int _activeOperationCount = 0;
  late final SourceSessionStore session = SourceSessionStore(
    sourceKey: sourceKey,
    secureStorage: _secureStorage,
  );
  final SourceCacheStore cache = SourceCacheStore();
  final SourceDebugLogStore debug = SourceDebugLogStore();

  late final SourceJsBridge js = SourceJsBridge(runtime);
  @override
  late final SourceCookieStore cookieStore = SourceCookieStore(
    loadCookies: session.loadCookieStore,
    saveCookies: session.saveCookieStore,
  );
  late final SourceNetworkLogSink networkLogSink = SourceNetworkLogSink(({
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
  }) {
    debugLog.appendNetworkLogEntry(
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
  });
  late final SourceHttpGateway httpGateway = SourceHttpGateway(
    dio: dio,
    sourceKey: sourceKey,
    cookieStore: cookieStore,
    networkLogSink: networkLogSink,
  );
  late final HazukiSourceFacade facade = HazukiSourceFacade(
    handle: this,
    runtime: runtime,
    session: session,
    cache: cache,
    debug: debug,
    js: js,
    networkLogSink: networkLogSink,
    httpGateway: httpGateway,
    ensureInitialized: _ensureInitialized,
    notifyRuntimeStateChanged: _notifyRuntimeStateChanged,
    addApplicationLog:
        ({
          required String title,
          String level = 'info',
          String source = 'app',
          Object? content,
        }) => debugLog.addApplicationLog(
          title: title,
          level: level,
          source: source,
          content: content,
        ),
    ensureImageCacheDir: () => imageCache.ensureCacheDir(),
    computeImageCacheSizeBytes: () => imageCache.computeSizeBytes(),
    enforceImageCachePolicy: ({bool force = false}) =>
        imageCache.enforcePolicy(force: force),
  );
  late final LineSettingsCapability lineSettings = LineSettingsCapability(
    facade,
  );
  late final ImageCacheCapability imageCache = ImageCacheCapability(facade);
  late final ExploreCacheCapability exploreCache = ExploreCacheCapability(
    facade,
  );
  late final DebugLogCapability debugLog = DebugLogCapability(facade);

  @override
  bool get isDisposed => _disposed;

  @override
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

  @override
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
