import '../common/source_prefs_keys.dart';
import '../models/source_contract_models.dart';
import 'source_js_bridge_cookie_capability.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_loader.dart';
import 'source_runtime_state_controller.dart';

/// Coordinates source activation and the runtime initialization state machine.
class SourceRuntimeInitializationOperations {
  SourceRuntimeInitializationOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeLoadClient runtimeLoader,
    required SourceJsBridgeCookieCapability jsBridgeCookieCapability,
    required SourceRuntimeStateController runtimeStateController,
  }) : _runtimeHost = runtimeHost,
       _runtimeLoader = runtimeLoader,
       _jsBridgeCookieCapability = jsBridgeCookieCapability,
       _runtimeStateController = runtimeStateController;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeLoadClient _runtimeLoader;
  final SourceJsBridgeCookieCapability _jsBridgeCookieCapability;
  final SourceRuntimeStateController _runtimeStateController;

  Future<void> activateSource(String sourceKey) =>
      _runtimeHost.activateSource(sourceKey);

  Future<void> prewarmInBackground() async {
    final handle = _runtimeHost.activeHandle;
    if (_isHandleInitialized(handle)) return;
    final pending = handle.facade.initFuture;
    if (pending != null) {
      await pending;
      return;
    }
    await _initHandle(handle, prewarm: true);
  }

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  }) => _initHandle(
    _runtimeHost.activeHandle,
    onSourceDownloadProgress: onSourceDownloadProgress,
    prewarm: prewarm,
  );

  Future<void> ensureInitialized({String? sourceKey}) async {
    if (sourceKey != null && sourceKey.trim().isNotEmpty) {
      await activateSource(sourceKey);
    }
    await _ensureHandleInitialized(_runtimeHost.activeHandle);
  }

  Future<void> ensureSourceInitialized(String sourceKey) =>
      _ensureHandleInitialized(_runtimeHost.handleFor(sourceKey));

  Future<void> _initHandle(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onSourceDownloadProgress,
    required bool prewarm,
  }) async {
    final facade = handle.facade;
    final inFlight = facade.initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = handle.runOperation(
      () => _initInternal(
        handle,
        onSourceDownloadProgress: onSourceDownloadProgress,
        prewarm: prewarm,
      ),
    );
    facade.initFuture = future;
    try {
      await future;
    } finally {
      if (identical(facade.initFuture, future)) {
        facade.initFuture = null;
      }
    }
  }

  Future<void> _ensureHandleInitialized(SourceRuntimeHandle handle) async {
    final facade = handle.facade;
    if (_isHandleInitialized(handle)) return;

    final inFlight = facade.initFuture;
    if (inFlight == null) {
      await _initHandle(handle, prewarm: false);
    } else {
      await inFlight;
    }

    if (_isHandleInitialized(handle)) return;

    facade.initFuture = null;
    await _initHandle(handle, prewarm: false);

    if (!_isHandleInitialized(handle)) {
      throw Exception('source_not_initialized:${facade.statusText}');
    }
  }

  bool _isHandleInitialized(SourceRuntimeHandle handle) =>
      handle.runtime.engine != null && handle.runtime.sourceMeta != null;

  Future<void> _initInternal(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onSourceDownloadProgress,
    required bool prewarm,
  }) async {
    final facade = handle.facade;
    final busyPhase = switch (facade.runtimeState.phase) {
      SourceRuntimePhase.failed => SourceRuntimePhase.retrying,
      _ when prewarm => SourceRuntimePhase.prewarming,
      _ => SourceRuntimePhase.loading,
    };

    try {
      _runtimeStateController.setBusy(
        facade,
        busyPhase,
        SourceRuntimeStep.loadingCache,
        statusText: prewarm ? 'source_prewarming' : 'source_initializing',
        debugDetail: 'loading_cache',
      );
      final prefs = await facade.ensurePrefs();
      facade.debug.softwareLogCaptureEnabled =
          prefs.getBool(SourcePrefsKeys.softwareLogCaptureEnabled) ?? false;
      _jsBridgeCookieCapability.configureDioCookieBridge(handle);
      await handle.imageCache.init();
      await handle.exploreCache.init();
      _runtimeStateController.setBusy(
        facade,
        busyPhase,
        SourceRuntimeStep.downloadingSource,
        debugDetail: 'downloading_source',
      );
      final result = await _runtimeLoader.downloadOrLoad(
        handle,
        onProgress: onSourceDownloadProgress,
      );
      _runtimeStateController.setBusy(
        facade,
        busyPhase,
        SourceRuntimeStep.creatingEngine,
        debugDetail: 'creating_engine',
      );
      final meta = await _runtimeLoader.loadMetadata(handle, result.sourceFile);
      facade.runtime.sourceMeta = meta;
      _runtimeStateController.setReady(
        facade,
        message: result.message,
        meta: meta,
      );
    } catch (error) {
      _runtimeStateController.setFailed(facade, error);
    }
  }
}
