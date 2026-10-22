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
import 'source_task_registry.dart';
import 'source_runtime_load_control.dart';
import 'source_session_store.dart';
import '../account/source_login_interaction.dart';
import '../interaction/source_ui_scope.dart';
import '../interaction/source_ui_service.dart';
import '../models/source_task.dart';
import '../../logging/app_log_store.dart';

/// [recover] 为真表示消耗了本次单次自动恢复额度；为假表示故障已锁存。
typedef SourceRuntimeFailureHandler =
    void Function(
      SourceRuntimeHandle handle,
      SourceRuntimeFailed failure, {
      required bool recover,
    });

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
    SourceTaskRegistry? tasks,
    bool Function(SourceRuntimeHandle handle)? canCacheImages,
    this.onRuntimeFailed,
  }) : _ensureInitialized = ensureInitialized,
       _notifyRuntimeStateChanged = notifyRuntimeStateChanged,
       _secureStorage = secureStorage,
       appLogStore = appLogStore ?? AppLogStore(),
       tasks = tasks ?? SourceTaskRegistry(),
       _ownsTasks = tasks == null,
       _canCacheImages = canCacheImages;

  final SourceTaskRegistry tasks;
  final bool _ownsTasks;
  final bool Function(SourceRuntimeHandle handle)? _canCacheImages;

  @override
  final String sourceKey;
  final SourceSecureSessionStorage _secureStorage;
  SourceSecureSessionStorage get secureStorage => _secureStorage;
  String? pluginDirectory;
  SourceLoginPresenter? loginPresenter;
  SourceLoginCancellation? loginCancellation;
  SourceRuntimeLoadControl? loadControl;
  final Map<String, void Function()> hostExecutionGuards = {};
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
  final SourceRuntimeFailureHandler? onRuntimeFailed;
  bool _autoRecoveryAvailable = true;
  SourceRuntimeFailed? _runtimeFault;
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
    onDelete: session.deleteBrowserUserAgent,
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
    bool cancelled = false,
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
      cancelled: cancelled,
    );
  });
  late final SourceHttpGateway httpGateway = SourceHttpGateway(
    dio: dio,
    sourceKey: sourceKey,
    cookieStore: cookieStore,
    networkLogSink: networkLogSink,
    browserUserAgents: session.loadBrowserUserAgents,
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
  late final ImageCacheCapability imageCache = ImageCacheCapability(
    facade,
    tasks: tasks,
    canCache: () => !_disposed && (_canCacheImages?.call(this) ?? true),
  );
  late final ExploreCacheCapability exploreCache = ExploreCacheCapability(
    facade,
  );
  late final DebugLogCapability debugLog = DebugLogCapability(appLogStore);

  @override
  bool get isDisposed => _disposed;
  bool get isDisposalRequested => _disposeRequested || _disposed;

  bool get recreationRequested => _recreationRequested;

  /// 自动恢复额度用尽后锁存的故障；只能由显式手动入口解除。
  SourceRuntimeFailed? get runtimeFault => _runtimeFault;

  /// 最近一次已发布实例的故障；发布新实例后清空。
  SourceRuntimeFailed? get lastRuntimeFailure => _lastRuntimeFailure;
  SourceRuntimeFailed? _lastRuntimeFailure;

  /// 监听已发布实例的故障。回调须与实例处于同一错误 zone，否则其关闭错误
  /// 无法传给收尾监听；只解除加载时继承的交互 scope。
  void watchEngine(SourceScriptEngine engine) {
    _lastRuntimeFailure = null;
    engine.whenFailed
        .then<void>(
          (failure) => SourceUiScope.withoutInteractionSync(
            () => _engineFailed(engine, failure),
          ),
        )
        .ignore();
  }

  void _engineFailed(SourceScriptEngine engine, SourceRuntimeFailed failure) {
    // 旧实例或已退役 handle 的迟到故障一律忽略。
    if (_disposed || _disposeRequested || !identical(runtime.engine, engine)) {
      return;
    }
    runtime.engine = null;
    _lastRuntimeFailure = failure;
    // 故障实例由 worker 自行释放；仅未正常清理的退出仍作为收尾失败报告。
    final closing = engine.whenClosed.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (failure.kind == SourceRuntimeFailureKind.exitedWithoutCleanup) {
          Error.throwWithStackTrace(error, stack);
        }
      },
    );
    closing.ignore();
    _engineClosures.add(closing);
    final recover = _autoRecoveryAvailable;
    if (recover) {
      _autoRecoveryAvailable = false;
    } else {
      _runtimeFault = failure;
    }
    try {
      onRuntimeFailed?.call(this, failure, recover: recover);
    } catch (_) {
      // 恢复调度失败不能影响故障隔离。
    }
  }

  /// 恢复后的实例成功完成业务操作，重新获得单次自动恢复额度。
  void noteOperationSucceeded() {
    if (runtime.engine != null && _runtimeFault == null) {
      _autoRecoveryAvailable = true;
    }
  }

  /// 显式手动重试、重新加载或重新下载脚本时解除锁存。
  void clearRuntimeFault() {
    _runtimeFault = null;
    _autoRecoveryAvailable = true;
  }

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
    if (_ownsTasks) tasks.dispose();

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
    hostExecutionGuards.clear();
    session.clearMemory();
    cache.clearMemory();
    htmlBridge.clear();
  }
}

class _OperationLease {
  bool active = true;
}
