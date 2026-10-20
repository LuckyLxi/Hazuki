import 'dart:async';

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
import 'source_html_bridge.dart';
import 'source_runtime_coordinator.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_kernel.dart';
import 'source_secure_session_storage.dart';
import 'source_script_engine.dart';
import 'source_session_store.dart';
import '../account/source_login_interaction.dart';
import '../interaction/source_ui_service.dart';
import '../../logging/app_log_store.dart';

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
    AppLogStore? appLogStore,
  }) : _ensureInitialized = ensureInitialized,
       _notifyRuntimeStateChanged = notifyRuntimeStateChanged,
       _secureStorage = secureStorage,
       appLogStore = appLogStore ?? AppLogStore();

  @override
  final String sourceKey;
  final SourceSecureSessionStorage _secureStorage;
  SourceSecureSessionStorage get secureStorage => _secureStorage;
  String? pluginDirectory;
  SourceLoginPresenter? loginPresenter;
  SourceLoginCancellation? loginCancellation;
  final Future<void> Function(String sourceKey) _ensureInitialized;
  final void Function(String sourceKey) _notifyRuntimeStateChanged;
  final Dio dio = _createSourceDio();
  final AppLogStore appLogStore;
  late final SourceRuntimeKernel runtime = SourceRuntimeKernel(
    operationGuard: (operation) => runOperation(operation),
    onMetadataChanged: () => _notifyRuntimeStateChanged(sourceKey),
  );
  final Completer<void> _whenDisposed = Completer<void>();
  Future<void> get whenDisposed => _whenDisposed.future;
  SourceHtmlBridge htmlBridge = SourceHtmlBridge();
  bool _disposed = false;
  bool _disposeRequested = false;
  bool _recreationRequested = false;
  int _activeOperationCount = 0;
  final Object _operationZoneKey = Object();
  final Set<SourceScriptEngine> _retiredEngines = {};

  /// Includes candidate engines that are not published as runtime.engine yet.
  final Set<String> loadingRuntimeIds = {};
  final List<Future<void>> _engineClosures = [];
  late final SourceSessionStore session = SourceSessionStore(
    sourceKey: sourceKey,
    secureStorage: _secureStorage,
  );
  final SourceCacheStore cache = SourceCacheStore();
  final SourceDebugLogStore debug = SourceDebugLogStore();

  late final SourceJsBridge js = SourceJsBridge(runtime, this);
  @override
  late final SourceCookieStore cookieStore = SourceCookieStore(
    loadCookies: session.loadCookieStore,
    saveCookies: (cookies) async {
      if (_disposed || loginCancellation?.isCancelled == true) return;
      await session.saveCookieStore(cookies);
    },
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
    Map<String, Object?>? taskContext,
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
      taskContext: taskContext,
    );
  });
  late final SourceHttpGateway httpGateway = SourceHttpGateway(
    dio: dio,
    sourceKey: sourceKey,
    cookieStore: cookieStore,
    networkLogSink: networkLogSink,
    onResponseStatus: _onResponseStatus,
  );
  late final HazukiSourceFacade facade = HazukiSourceFacade(
    handle: this,
    runtime: runtime,
    session: session,
    cache: cache,
    debug: debug,
    appLogStore: appLogStore,
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
  late final DebugLogCapability debugLog = DebugLogCapability(appLogStore);

  @override
  bool get isDisposed => _disposed;
  bool get isDisposalRequested => _disposeRequested || _disposed;

  bool get recreationRequested => _recreationRequested;

  void _onResponseStatus(int statusCode) {
    final statuses = runtime.sourceMeta?.presentation['recreateOnStatus'];
    if (statuses is List && statuses.contains(statusCode)) {
      _recreationRequested = true;
    }
  }

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) async {
    // An admitted operation can continue across awaits after switching source.
    // The proxy's nested lease must not reject the remainder of that operation.
    final inherited = Zone.current[_operationZoneKey] as _OperationLease?;
    final admitted = inherited?.active == true;
    if (_disposed || (_disposeRequested && !admitted)) {
      throw StateError('source_runtime_disposed:$sourceKey');
    }
    _activeOperationCount += 1;
    final lease = admitted ? inherited! : _OperationLease();
    try {
      return await runZoned(operation, zoneValues: {_operationZoneKey: lease});
    } finally {
      _activeOperationCount -= 1;
      if (!admitted) lease.active = false;
      if (_disposeRequested && _activeOperationCount == 0) {
        _disposeNow();
      } else if (_activeOperationCount == 0) {
        _closeRetiredEngines();
      }
    }
  }

  /// Existing operations retain the old instance until their leases finish.
  void retireEngine(SourceScriptEngine engine) {
    _retiredEngines.add(engine);
    if (_activeOperationCount == 0) _closeRetiredEngines();
  }

  void _closeRetiredEngines() {
    for (final engine in _retiredEngines) {
      closeEngine(engine);
    }
    _retiredEngines.clear();
  }

  /// Closes a private or cancelled candidate engine without waiting for leases.
  /// Disposal still waits for its worker to finish releasing native resources.
  Future<void> closeEngine(SourceScriptEngine engine) {
    final closing = engine.close();
    closing.ignore();
    _engineClosures.add(closing);
    return closing;
  }

  @override
  void requestDispose() {
    for (final id in loadingRuntimeIds.toList()) {
      SourceUiService.instance.cancelRuntime(id);
    }
    final engine = runtime.engine;
    if (engine != null) {
      SourceUiService.instance.cancelRuntime(engine.runtimeId);
    }
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
    if (engine != null) _retiredEngines.add(engine);
    _closeRetiredEngines();
    final closing = Future.wait(_engineClosures);
    closing.then<void>(
      (_) {
        if (!_whenDisposed.isCompleted) _whenDisposed.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!_whenDisposed.isCompleted) {
          _whenDisposed.completeError(error, stack);
        }
      },
    );
    _whenDisposed.future.ignore();
    session.clearMemory();
    cache.clearMemory();
    htmlBridge.clear();
  }
}

class _OperationLease {
  bool active = true;
}
