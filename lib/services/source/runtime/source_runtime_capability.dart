import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import '../../../models/source_meta.dart';
import '../account/source_relogin_coordinator.dart';
import '../common/source_json_coerce.dart';
import '../common/source_prefs_keys.dart';
import '../models/source_contract_models.dart';
import '../models/source_identity.dart';
import 'source_js_bridge_cookie_capability.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_storage.dart';

/// Owns source initialization, scripts, file lifecycle, and update behavior.
class SourceRuntimeCapability {
  SourceRuntimeCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceScriptStorage scriptStorage,
    required SourceJsBridgeCookieCapability jsBridgeCookieCapability,
    required SourceRuntimeStateController runtimeStateController,
    required SourceReloginCoordinator reloginCoordinator,
    required String bundledInitAssetPath,
    required List<String> sourceIndexUrls,
  }) : _runtimeHost = runtimeHost,
       _scriptStorage = scriptStorage,
       _jsBridgeCookieCapability = jsBridgeCookieCapability,
       _runtimeStateController = runtimeStateController,
       _reloginCoordinator = reloginCoordinator,
       _bundledInitAssetPath = bundledInitAssetPath,
       _sourceIndexUrls = sourceIndexUrls;

  final SourceRuntimeHost _runtimeHost;
  final SourceScriptStorage _scriptStorage;
  final SourceJsBridgeCookieCapability _jsBridgeCookieCapability;
  final SourceRuntimeStateController _runtimeStateController;
  final SourceReloginCoordinator _reloginCoordinator;
  final String _bundledInitAssetPath;
  final List<String> _sourceIndexUrls;

  SourceRuntimeHandle get _activeHandle => _runtimeHost.activeHandle;
  SourceRuntimeHandle _handleFor(String sourceKey) =>
      _runtimeHost.handleFor(sourceKey);
  HazukiSourceFacade get facade => _activeHandle.facade;
  String get activeSourceKey => _runtimeHost.activeSourceKey;
  SourceMeta? get sourceMeta => _activeHandle.runtime.sourceMeta;
  bool get isInitialized =>
      _activeHandle.runtime.engine != null &&
      _activeHandle.runtime.sourceMeta != null;

  SourceCatalogEntry _definitionForSourceKey(String sourceKey) =>
      _runtimeHost.definitionFor(sourceKey);
  String _normalizeAllowedSourceKey(String sourceKey) =>
      _runtimeHost.normalize(sourceKey);

  Future<void> activateSource(String sourceKey) =>
      _runtimeHost.activateSource(sourceKey);

  void _configureDioCookieBridge([SourceRuntimeHandle? handle]) =>
      _jsBridgeCookieCapability.configureDioCookieBridge(handle);

  dynamic _handleJsMessageForHandle(
    SourceRuntimeHandle handle,
    dynamic message,
  ) => _jsBridgeCookieCapability.handleJsMessageForHandle(handle, message);

  Future<void> prewarmInBackground() async {
    final handle = _activeHandle;
    if (_isHandleInitialized(handle)) return;
    final pending = handle.facade.initFuture;
    if (pending != null) {
      await pending;
      return;
    }
    await _initHandle(handle, prewarm: true);
  }

  void logRuntimeRetryRequested(String source) {
    facade.addApplicationLog(
      level: 'info',
      title: 'Source retry requested',
      source: 'source_runtime',
      content: {'trigger': source, ...facade.runtimeState.toDebugMap()},
    );
  }

  void _setRuntimeBusyState(
    SourceRuntimePhase phase,
    SourceRuntimeStep step, {
    String? debugDetail,
    String? statusText,
    HazukiSourceFacade? targetFacade,
  }) => _runtimeStateController.setBusy(
    targetFacade ?? facade,
    phase,
    step,
    debugDetail: debugDetail,
    statusText: statusText,
  );

  void _setRuntimeReadyState({
    required _SourceLoadResult result,
    required SourceMeta meta,
    HazukiSourceFacade? targetFacade,
  }) => _runtimeStateController.setReady(
    targetFacade ?? facade,
    message: result.message,
    meta: meta,
  );

  void _setRuntimeFailedState(
    Object error, {
    SourceRuntimeStep? step,
    HazukiSourceFacade? targetFacade,
  }) => _runtimeStateController.setFailed(
    targetFacade ?? facade,
    error,
    step: step,
  );

  void _setRuntimeWaitingForRestartState({
    required String statusText,
    String? debugDetail,
    HazukiSourceFacade? targetFacade,
  }) => _runtimeStateController.setWaitingForRestart(
    targetFacade ?? facade,
    statusText: statusText,
    debugDetail: debugDetail,
  );

  Future<bool> _tryReloginFromStoredAccount({
    bool force = false,
    HazukiSourceFacade? targetFacade,
  }) => _reloginCoordinator.tryReloginFromStoredAccount(
    SourceFacadeReloginContext(targetFacade ?? facade),
    force: force,
  );

  Future<bool> loadSoftwareLogCaptureEnabled() async {
    final facade = this.facade;
    final prefs = await facade.ensurePrefs();
    facade.debug.softwareLogCaptureEnabled =
        prefs.getBool(SourcePrefsKeys.softwareLogCaptureEnabled) ?? false;
    if (!facade.softwareLogCaptureEnabled) {
      _clearCapturedLogs();
    }
    return facade.softwareLogCaptureEnabled;
  }

  Future<void> setSoftwareLogCaptureEnabled(bool enabled) async {
    final facade = this.facade;
    facade.debug.softwareLogCaptureEnabled = enabled;
    if (!enabled) {
      _clearCapturedLogs();
    }
    final prefs = await facade.ensurePrefs();
    await prefs.setBool(SourcePrefsKeys.softwareLogCaptureEnabled, enabled);
  }

  void _clearCapturedLogs() {
    final facade = this.facade;
    facade.clearCapturedLogs();
    facade.lastLoginDebugInfo = null;
    facade.lastSourceVersionDebugInfo = null;
  }

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  }) async {
    final handle = _activeHandle;
    await _initHandle(
      handle,
      onSourceDownloadProgress: onSourceDownloadProgress,
      prewarm: prewarm,
    );
  }

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

  Future<void> ensureInitialized({String? sourceKey}) async {
    if (sourceKey != null && sourceKey.trim().isNotEmpty) {
      await activateSource(sourceKey);
    }
    await _ensureHandleInitialized(_activeHandle);
  }

  Future<void> ensureSourceInitialized(String sourceKey) async {
    final handle = _handleFor(sourceKey);
    await _ensureHandleInitialized(handle);
  }

  Future<void> _ensureHandleInitialized(SourceRuntimeHandle handle) async {
    final facade = handle.facade;
    if (_isHandleInitialized(handle)) {
      return;
    }

    final inFlight = facade.initFuture;
    if (inFlight == null) {
      await _initHandle(handle, prewarm: false);
    } else {
      await inFlight;
    }

    if (_isHandleInitialized(handle)) {
      return;
    }

    facade.initFuture = null;
    await _initHandle(handle, prewarm: false);

    if (!_isHandleInitialized(handle)) {
      throw Exception('source_not_initialized:${facade.statusText}');
    }
  }

  bool _isHandleInitialized(SourceRuntimeHandle handle) {
    return handle.runtime.engine != null && handle.runtime.sourceMeta != null;
  }

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
      _setRuntimeBusyState(
        busyPhase,
        SourceRuntimeStep.loadingCache,
        statusText: prewarm ? 'source_prewarming' : 'source_initializing',
        debugDetail: 'loading_cache',
        targetFacade: facade,
      );
      final prefs = await facade.ensurePrefs();
      facade.debug.softwareLogCaptureEnabled =
          prefs.getBool(SourcePrefsKeys.softwareLogCaptureEnabled) ?? false;
      _configureDioCookieBridge(handle);
      await handle.imageCache.init();
      await handle.exploreCache.init();
      _setRuntimeBusyState(
        busyPhase,
        SourceRuntimeStep.downloadingSource,
        debugDetail: 'downloading_source',
        targetFacade: facade,
      );
      final result = await _downloadOrLoadSourceFiles(
        handle: handle,
        onProgress: onSourceDownloadProgress,
      );
      _setRuntimeBusyState(
        busyPhase,
        SourceRuntimeStep.creatingEngine,
        debugDetail: 'creating_engine',
        targetFacade: facade,
      );
      final meta = await _loadSourceMetadata(result.jmFile, handle: handle);
      facade.runtime.sourceMeta = meta;
      _setRuntimeReadyState(result: result, meta: meta, targetFacade: facade);
    } catch (e) {
      _setRuntimeFailedState(e, targetFacade: facade);
    }
  }

  Future<String?> _downloadFromUrls(
    List<String> urls, {
    String source = 'source_fetch',
    HazukiSourceFacade? targetFacade,
  }) async {
    if (urls.isEmpty) {
      return null;
    }

    final facade = targetFacade ?? this.facade;

    Future<String?> requestOnce(String url) async {
      final startedAt = DateTime.now();
      final requestUrl = facade.httpGateway.normalizeUrl(url);
      try {
        final response = await facade.httpGateway.request<String>(
          requestUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
            extra: {'skipNetworkDebugLog': true, 'hazukiLogCategory': source},
          ),
        );
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: response.statusCode,
          error: null,
          startedAt: startedAt,
          category: source,
          responseHeaders: response.headers.map,
          responseBody: response.data,
        );
        if (response.statusCode == 200 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data;
        }
      } catch (e) {
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: null,
          error: e.toString(),
          startedAt: startedAt,
          category: source,
        );
      }
      return null;
    }

    final completer = Completer<String?>();
    var finished = false;

    void tryComplete(String? value) {
      if (finished || value == null) {
        return;
      }
      finished = true;
      completer.complete(value);
    }

    Future<void> runAll() async {
      final futures = urls.map((url) async {
        final result = await requestOnce(url);
        if (result != null) {
          tryComplete(result);
        }
      }).toList();
      await Future.wait(futures);
      if (!finished) {
        completer.complete(null);
      }
    }

    runAll();
    return completer.future;
  }

  Future<String?> _downloadFromUrlsWithProgress(
    List<String> urls, {
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
    HazukiSourceFacade? targetFacade,
  }) async {
    final facade = targetFacade ?? this.facade;
    for (final url in urls) {
      final startedAt = DateTime.now();
      final requestUrl = facade.httpGateway.normalizeUrl(url);
      try {
        final response = await facade.httpGateway.request<String>(
          requestUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
            extra: {'skipNetworkDebugLog': true, 'hazukiLogCategory': source},
          ),
          onReceiveProgress: onProgress,
        );
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: response.statusCode,
          error: null,
          startedAt: startedAt,
          category: source,
          responseHeaders: response.headers.map,
          responseBody: response.data,
        );
        if (response.statusCode == 200 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data;
        }
      } catch (e) {
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: null,
          error: e.toString(),
          startedAt: startedAt,
          category: source,
        );
      }
    }
    return null;
  }

  String _extractSourceClassName(String script) {
    final regex = RegExp(
      r'class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+ComicSource',
    );
    final match = regex.firstMatch(script);
    if (match == null) {
      /*
      throw Exception('jm.js 閺嶇厧绱￠弮鐘虫櫏閿涙碍婀幍鎯у煂 extends ComicSource 閻ㄥ嫮琚€规矮绠?);
      */
      throw Exception('source_class_not_found');
    }
    return match.group(1)!;
  }

  Map<String, dynamic> _parseSettingsDefaultMap(dynamic raw) {
    if (raw is! Map) {
      return {};
    }

    final defaults = <String, dynamic>{};
    final settingMap = Map<String, dynamic>.from(raw);
    for (final entry in settingMap.entries) {
      final value = entry.value;
      if (value is Map && value.containsKey('default')) {
        defaults[entry.key] = value['default'];
      }
    }
    return defaults;
  }

  Future<_SourceLoadResult> _ensureLocalSourceFiles({
    bool requireJmFile = true,
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final jmFile = await _scriptStorage.ensureLocalSourceFile(
      targetHandle.sourceKey,
    );

    if (requireJmFile && !await jmFile.exists()) {
      throw Exception('source_local_jm_missing');
    }

    return _SourceLoadResult(
      jmFile: jmFile,
      message: 'source_loaded_from_local_cache',
    );
  }

  Future<_SourceLoadResult> _downloadOrLoadSourceFiles({
    void Function(int received, int total)? onProgress,
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final localFiles = await _ensureLocalSourceFiles(
      requireJmFile: false,
      handle: targetHandle,
    );
    final jmFile = localFiles.jmFile;

    if (await jmFile.exists()) {
      return _SourceLoadResult(
        jmFile: jmFile,
        message: 'source_loaded_from_local_cache',
      );
    }

    final jmScript = await _downloadFromUrlsWithProgress(
      await _resolveActiveSourceDownloadUrls(handle: targetHandle),
      onProgress: onProgress,
      targetFacade: targetHandle.facade,
    );
    if (jmScript != null && jmScript.trim().isNotEmpty) {
      await _scriptStorage.write(targetHandle.sourceKey, jmScript);
      return _SourceLoadResult(
        jmFile: jmFile,
        message: 'source_downloaded_on_first_launch',
      );
    }

    throw Exception('source_download_failed_without_cache');
  }

  Future<_SourceLoadResult> _downloadSourceFiles({
    void Function(int received, int total)? onProgress,
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final localFiles = await _ensureLocalSourceFiles(
      requireJmFile: false,
      handle: targetHandle,
    );
    final jmFile = localFiles.jmFile;

    final jmScript = await _downloadFromUrlsWithProgress(
      await _resolveActiveSourceDownloadUrls(handle: targetHandle),
      onProgress: onProgress,
      targetFacade: targetHandle.facade,
    );
    if (jmScript != null && jmScript.trim().isNotEmpty) {
      await _scriptStorage.write(targetHandle.sourceKey, jmScript);
      return _SourceLoadResult(
        jmFile: jmFile,
        message: 'source_downloaded_manually',
      );
    }

    throw Exception('source_download_failed_without_cache');
  }

  Future<SourceMeta> _loadSourceMetadata(
    File jmFile, {
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final facade = targetHandle.facade;
    if (facade.handle.isDisposed) {
      throw Exception('source_runtime_disposed');
    }
    final initScript = await rootBundle.loadString(_bundledInitAssetPath);
    final jmScript = await jmFile.readAsString();
    final className = _extractSourceClassName(jmScript);

    final engine = FlutterQjs(hostPromiseRejectionHandler: (_) {});
    try {
      engine.dispatch();

      final setGlobal =
          engine.evaluate('(k, v) => { this[k] = v; }') as JSInvokable;
      setGlobal.invoke([
        'sendMessage',
        (dynamic message) => _handleJsMessageForHandle(targetHandle, message),
      ]);
      setGlobal.invoke(['appVersion', '1.0.0']);
      setGlobal.free();

      engine.evaluate(initScript, name: 'init.js');
      engine.evaluate(jmScript, name: 'jm.js');
      engine.evaluate(
        "this.__hazuki_source = new $className();",
        name: 'create_source.js',
      );

      final name = (engine.evaluate('this.__hazuki_source.name') ?? '')
          .toString();
      final key = (engine.evaluate('this.__hazuki_source.key') ?? '')
          .toString();
      final version = (engine.evaluate('this.__hazuki_source.version') ?? '')
          .toString();
      final supportsAccount = jsAsBool(
        engine.evaluate('!!this.__hazuki_source.account?.login'),
      );

      if (name.isEmpty || key.isEmpty || version.isEmpty) {
        throw Exception('source_metadata_incomplete');
      }
      final settingsDefaults = _parseSettingsDefaultMap(
        engine.evaluate('this.__hazuki_source.settings ?? {}'),
      );

      final meta = SourceMeta(
        name: name,
        key: key,
        version: version,
        supportsAccount: supportsAccount,
        settingsDefaults: settingsDefaults,
      );

      _setRuntimeBusyState(
        facade.runtimeState.phase,
        SourceRuntimeStep.runningSourceInit,
        debugDetail: 'running_source_init',
        targetFacade: facade,
      );
      final oldMeta = facade.sourceMeta;
      facade.runtime.sourceMeta = meta;
      try {
        final initResult = engine.evaluate(
          'this.__hazuki_source.init?.()',
          name: 'source_init.js',
        );
        if (initResult is Future) {
          await initResult;
        }
        if (facade.handle.isDisposed) {
          throw Exception('source_runtime_disposed');
        }
      } catch (_) {
        facade.runtime.sourceMeta = oldMeta;
        rethrow;
      }
      final oldEngine = facade.runtime.engine;
      facade.runtime.engine = engine;
      oldEngine?.close();
      return meta;
    } catch (_) {
      engine.close();
      rethrow;
    }
  }

  Future<List<String>> _resolveActiveSourceDownloadUrls({
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final definition = _definitionForSourceKey(targetHandle.sourceKey);
    final directUrls = definition.directUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (directUrls.isNotEmpty) {
      return directUrls;
    }

    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_catalog_index',
      targetFacade: targetHandle.facade,
    );
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      return definition.fallbackUrls();
    }

    try {
      final decoded = jsonDecode(indexRaw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) {
            continue;
          }
          final map = Map<String, dynamic>.from(item);
          if (!definition.matchesIndexEntry(map)) {
            continue;
          }
          final rawUrl = map['url']?.toString().trim();
          if (rawUrl != null && rawUrl.isNotEmpty) {
            return [rawUrl];
          }
          final fileName =
              map['fileName']?.toString().trim() ?? definition.fileName;
          if (fileName.isNotEmpty) {
            return [
              'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/$fileName',
            ];
          }
        }
      }
    } catch (_) {}

    return definition.fallbackUrls();
  }

  Future<String?> readLocalActiveSourceIfExists() async {
    return readLocalSourceIfExists(activeSourceKey);
  }

  Future<String?> readLocalSourceIfExists(String sourceKey) async {
    return _scriptStorage.readIfExists(sourceKey);
  }

  Future<String?> readLocalJmSourceIfExists() async {
    return readLocalActiveSourceIfExists();
  }

  Future<String> loadEditableActiveSource() async {
    return loadEditableSource(activeSourceKey);
  }

  Future<String> loadEditableJmSource() async {
    return loadEditableActiveSource();
  }

  Future<void> writeLocalActiveSource(String content) async {
    await writeLocalSource(activeSourceKey, content);
  }

  Future<void> writeLocalJmSource(String content) async {
    await writeLocalActiveSource(content);
  }

  Future<void> saveEditedActiveSource(String content) async {
    await saveEditedSource(activeSourceKey, content);
  }

  Future<void> saveEditedJmSource(String content) async {
    await saveEditedActiveSource(content);
  }

  Future<String> loadEditableSource(String sourceKey) async {
    final handle = _handleFor(sourceKey);
    return handle.runOperation(() async {
      final result = await _downloadOrLoadSourceFiles(handle: handle);
      return result.jmFile.readAsString();
    });
  }

  Future<void> writeLocalSource(String sourceKey, String content) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    await _scriptStorage.write(normalizedSourceKey, content);
    await _setCustomEditedSourceFlag(normalizedSourceKey, true);
  }

  Future<void> saveEditedSource(String sourceKey, String content) async {
    final handle = _handleFor(sourceKey);
    await handle.runOperation(() async {
      final facade = handle.facade;
      await _downloadOrLoadSourceFiles(handle: handle);
      await _scriptStorage.write(handle.sourceKey, content);
      await _setCustomEditedSourceFlag(
        handle.sourceKey,
        true,
        targetFacade: facade,
      );
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'local_source_editor',
        'sourceKey': handle.sourceKey,
        'outcome': 'edited_waiting_for_restart',
      };
      _setRuntimeWaitingForRestartState(
        statusText: 'source_edited_waiting_for_restart',
        debugDetail: 'local_source_editor',
        targetFacade: facade,
      );
    });
  }

  Future<bool> hasLocalJmSourceFile() async {
    return hasLocalSourceFile(activeSourceKey);
  }

  Future<bool> hasLocalSourceFile(String sourceKey) async {
    return _scriptStorage.exists(sourceKey);
  }

  Future<void> deleteLocalSourceFile(String sourceKey) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    if (normalizedSourceKey == activeSourceKey) {
      throw StateError('source_delete_active_not_allowed');
    }

    await _scriptStorage.delete(normalizedSourceKey);
    await _setCustomEditedSourceFlag(normalizedSourceKey, false);
    _runtimeHost.remove(normalizedSourceKey);
  }

  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final handle = _handleFor(normalizedSourceKey);
    await handle.runOperation(() async {
      final facade = handle.facade;
      facade.lastReloginAt = null;
      handle.exploreCache.clearMemory();
      facade.cache.clearCategoryTagGroupsMemoryCache();
      final result = await _downloadSourceFiles(
        handle: handle,
        onProgress: onProgress,
      );
      await _setCustomEditedSourceFlag(
        handle.sourceKey,
        false,
        targetFacade: facade,
      );
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'manual_source_download',
        'sourceKey': handle.sourceKey,
        'outcome': result.message,
      };
    });
    await activateSource(normalizedSourceKey);
  }

  Future<bool> hasCustomEditedActiveSource() async {
    return hasCustomEditedSource(activeSourceKey);
  }

  Future<bool> hasCustomEditedSource(String sourceKey) async {
    return _scriptStorage.isCustomEdited(sourceKey);
  }

  Future<bool> hasCustomEditedJmSource() async {
    return hasCustomEditedActiveSource();
  }

  Future<void> _setCustomEditedSourceFlag(
    String sourceKey,
    bool value, {
    HazukiSourceFacade? targetFacade,
  }) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    if (targetFacade == null) {
      await _scriptStorage.setCustomEdited(normalizedSourceKey, value);
      return;
    }
    final prefs = await targetFacade.ensurePrefs();
    await prefs.setBool(
      SourcePrefsKeys.customEditedSource(normalizedSourceKey),
      value,
    );
    if (normalizedSourceKey == hazukiDefaultSourceKey) {
      await prefs.setBool(SourcePrefsKeys.customEditedJmSource, value);
    }
  }

  Future<void> reloadFromLocalSourceFiles() async {
    final handle = _activeHandle;
    await handle.runOperation(() async {
      final facade = handle.facade;
      if (facade.isRefreshingSource) {
        throw Exception('source_reload_in_progress');
      }
      facade.isRefreshingSource = true;
      try {
        _setRuntimeBusyState(
          SourceRuntimePhase.loading,
          SourceRuntimeStep.loadingCache,
          statusText: 'source_reloading_from_local_restore',
          debugDetail: 'cloud_sync_restore',
          targetFacade: facade,
        );
        facade.lastReloginAt = null;
        facade.favoritesDebugCache = null;
        handle.exploreCache.clearMemory();
        facade.cache.clearCategoryTagGroupsMemoryCache();
        final result = await _ensureLocalSourceFiles(handle: handle);
        _setRuntimeBusyState(
          SourceRuntimePhase.loading,
          SourceRuntimeStep.creatingEngine,
          debugDetail: 'creating_engine',
          targetFacade: facade,
        );
        final meta = await _loadSourceMetadata(result.jmFile, handle: handle);
        facade.runtime.sourceMeta = meta;
        _setRuntimeReadyState(result: result, meta: meta, targetFacade: facade);
        if (activeSourceKey == handle.sourceKey && facade.isLogged) {
          await _tryReloginFromStoredAccount(force: true);
        }
      } finally {
        facade.isRefreshingSource = false;
      }
    });
  }

  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() async {
    return checkJmSourceVersionFromCloud();
  }

  Future<SourceVersionCheckResult?> checkJmSourceVersionFromCloud() async {
    final handle = _activeHandle;
    return handle.runOperation(() => _checkSourceVersionFromCloud(handle));
  }

  Future<SourceVersionCheckResult?> _checkSourceVersionFromCloud(
    SourceRuntimeHandle handle,
  ) async {
    final facade = handle.facade;
    final sourceKey = handle.sourceKey;
    final sourceDefinition = _definitionForSourceKey(sourceKey);
    final sourceName = _sourceUpdateDisplayName(
      sourceDefinition,
      targetFacade: facade,
    );
    final jmFile = await _scriptStorage.sourceFileFor(sourceKey);
    final sourceDir = jmFile.parent;
    if (!await jmFile.exists()) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': false,
        'outcome': 'local_jm_missing',
      };
      return null;
    }

    final localVersion = await _readJmVersionFromFile(jmFile);
    final remoteVersionDirect = await _resolveRemoteJmVersion(
      sourceKey: sourceKey,
      sourceName: sourceName,
      sourceDefinition: sourceDefinition,
      targetFacade: facade,
    );
    if (remoteVersionDirect != null && remoteVersionDirect.isNotEmpty) {
      final hasUpdate = _isVersionGreater(remoteVersionDirect, localVersion);
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'remoteVersion': remoteVersionDirect,
        'hasUpdate': hasUpdate,
        'remoteVersionSource':
            facade.lastSourceVersionDebugInfo?['resolvedFrom'] ?? 'unknown',
        'outcome': hasUpdate ? 'update_available' : 'no_update',
      };
      return SourceVersionCheckResult(
        sourceKey: sourceKey,
        sourceName: sourceName,
        localVersion: localVersion,
        remoteVersion: remoteVersionDirect,
        hasUpdate: hasUpdate,
      );
    }

    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      targetFacade: facade,
    );
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_download_empty',
      };
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(indexRaw);
    } catch (_) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_decode_failed',
      };
      return null;
    }
    if (decoded is! List) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_not_list',
      };
      return null;
    }

    String? remoteVersion;
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      if (!sourceDefinition.matchesIndexEntry(map)) {
        continue;
      }
      remoteVersion = map['version']?.toString().trim();
      break;
    }

    if (remoteVersion == null || remoteVersion.isEmpty) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'remote_version_not_found_in_index',
      };
      return null;
    }

    final hasUpdate = _isVersionGreater(remoteVersion, localVersion);
    facade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'sourceKey': sourceKey,
      'sourceName': sourceName,
      'sourceDir': sourceDir.path,
      'localJmExists': true,
      'localVersion': localVersion,
      'remoteVersion': remoteVersion,
      'hasUpdate': hasUpdate,
      'remoteVersionSource': 'index_fallback_parse',
      'outcome': hasUpdate ? 'update_available' : 'no_update',
    };

    return SourceVersionCheckResult(
      sourceKey: sourceKey,
      sourceName: sourceName,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      hasUpdate: hasUpdate,
    );
  }

  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) async {
    final handle = _activeHandle;
    return handle.runOperation(
      () => _downloadSourceAndMarkForRestart(handle, onProgress: onProgress),
    );
  }

  Future<bool> _downloadSourceAndMarkForRestart(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    final facade = handle.facade;
    await _scriptStorage.ensureLocalSourceFile(handle.sourceKey);

    final jmScript = await _downloadFromUrlsWithProgress(
      await _resolveActiveSourceDownloadUrls(handle: handle),
      onProgress: onProgress,
      targetFacade: facade,
    );
    if (jmScript == null || jmScript.trim().isEmpty) {
      return false;
    }

    final downloadedVersion = _extractSourceVersion(jmScript);
    await _scriptStorage.write(handle.sourceKey, jmScript);
    await _setCustomEditedSourceFlag(
      handle.sourceKey,
      false,
      targetFacade: facade,
    );

    facade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'downloaded_jm_script',
      'remoteVersion': downloadedVersion,
      'outcome': 'downloaded_waiting_for_restart',
    };
    _setRuntimeWaitingForRestartState(
      statusText: 'source_downloaded_waiting_for_restart|$downloadedVersion',
      debugDetail: 'downloaded_jm_script',
      targetFacade: facade,
    );
    return true;
  }

  Future<bool> downloadJmSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) {
    return downloadActiveSourceAndReload(onProgress: onProgress);
  }

  Future<bool> refreshSourceOnNetworkRecovery() async {
    final handle = _activeHandle;
    return handle.runOperation(() => _refreshSourceOnNetworkRecovery(handle));
  }

  Future<bool> _refreshSourceOnNetworkRecovery(
    SourceRuntimeHandle handle,
  ) async {
    final facade = handle.facade;
    if (facade.isRefreshingSource) {
      return false;
    }
    facade.isRefreshingSource = true;
    try {
      _setRuntimeBusyState(
        facade.runtimeState.hasFailure
            ? SourceRuntimePhase.retrying
            : SourceRuntimePhase.loading,
        SourceRuntimeStep.downloadingSource,
        statusText: 'source_refreshing_after_network_recovery',
        debugDetail: 'network_recovery',
        targetFacade: facade,
      );
      facade.lastReloginAt = null;
      facade.favoritesDebugCache = null;
      handle.exploreCache.clearMemory();
      facade.cache.clearCategoryTagGroupsMemoryCache();
      facade.runtime.sourceMeta = null;
      final result = await _downloadOrLoadSourceFiles(handle: handle);
      final meta = await _loadSourceMetadata(result.jmFile, handle: handle);
      facade.runtime.sourceMeta = meta;
      _setRuntimeReadyState(result: result, meta: meta, targetFacade: facade);
      if (activeSourceKey == handle.sourceKey && facade.isLogged) {
        await _tryReloginFromStoredAccount(force: true);
      }
      return true;
    } catch (e) {
      _setRuntimeFailedState(e, targetFacade: facade);
      return false;
    } finally {
      facade.isRefreshingSource = false;
    }
  }

  Future<String> _readJmVersionFromFile(File jmFile) async {
    final content = await jmFile.readAsString();
    return _extractSourceVersion(content);
  }

  Future<String?> _resolveRemoteJmVersion({
    required String sourceKey,
    required String sourceName,
    required SourceCatalogEntry sourceDefinition,
    required HazukiSourceFacade targetFacade,
  }) async {
    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_version_index',
      targetFacade: targetFacade,
    );
    if (indexRaw != null && indexRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(indexRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) {
              continue;
            }
            final map = Map<String, dynamic>.from(item);
            final key = map['key']?.toString().trim().toLowerCase();
            final fileName = map['fileName']?.toString().trim().toLowerCase();
            final normalizedMap = <String, dynamic>{
              ...map,
              'key': key,
              'fileName': fileName,
            };
            if (!sourceDefinition.matchesIndexEntry(normalizedMap)) {
              continue;
            }
            final version = map['version']?.toString().trim();
            if (version != null && version.isNotEmpty) {
              targetFacade.lastSourceVersionDebugInfo = {
                'checkedAt': DateTime.now().toIso8601String(),
                'resolvedFrom': 'index_json',
                'sourceKey': sourceKey,
                'sourceName': sourceName,
                'matchedKey': key,
                'matchedFileName': fileName,
                'remoteVersion': version,
              };
              return version;
            }
          }
        }
      } catch (_) {}
    }

    final remoteScript = await _downloadFromUrls(
      await _resolveSourceVersionDownloadUrls(
        sourceDefinition,
        targetFacade: targetFacade,
      ),
      source: 'source_version_script',
      targetFacade: targetFacade,
    );
    if (remoteScript == null || remoteScript.trim().isEmpty) {
      targetFacade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'failed',
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'outcome': 'remote_script_empty',
      };
      return null;
    }
    final version = _extractSourceVersion(remoteScript);
    targetFacade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'source_script',
      'sourceKey': sourceKey,
      'sourceName': sourceName,
      'remoteVersion': version,
    };
    return version;
  }

  Future<List<String>> _resolveSourceVersionDownloadUrls(
    SourceCatalogEntry definition, {
    HazukiSourceFacade? targetFacade,
  }) async {
    final directUrls = definition.directUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (directUrls.isNotEmpty) {
      return directUrls;
    }

    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_version_download_index',
      targetFacade: targetFacade,
    );
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      return definition.fallbackUrls();
    }

    try {
      final decoded = jsonDecode(indexRaw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) {
            continue;
          }
          final map = Map<String, dynamic>.from(item);
          if (!definition.matchesIndexEntry(map)) {
            continue;
          }
          final rawUrl = map['url']?.toString().trim();
          if (rawUrl != null && rawUrl.isNotEmpty) {
            return [rawUrl];
          }
          final fileName =
              map['fileName']?.toString().trim() ?? definition.fileName;
          if (fileName.isNotEmpty) {
            return [
              'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/$fileName',
            ];
          }
        }
      }
    } catch (_) {}

    return definition.fallbackUrls();
  }

  String _sourceUpdateDisplayName(
    SourceCatalogEntry definition, {
    HazukiSourceFacade? targetFacade,
  }) {
    final metaName =
        (targetFacade?.sourceMeta ?? sourceMeta)?.name.trim() ?? '';
    if (metaName.isNotEmpty) {
      return metaName;
    }
    return definition.name;
  }

  String _extractSourceVersion(String script) {
    final match = RegExp(
      "version\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
    ).firstMatch(script);
    return match?.group(1) ?? '0.0.0';
  }

  bool _isVersionGreater(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) {
        return true;
      }
      if (va < vb) {
        return false;
      }
    }
    return false;
  }
}

class _SourceLoadResult {
  const _SourceLoadResult({required this.jmFile, required this.message});

  final File jmFile;
  final String message;
}
