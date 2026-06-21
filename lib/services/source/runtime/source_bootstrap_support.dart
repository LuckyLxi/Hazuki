part of '../../hazuki_source_service.dart';

extension SourceBootstrapSupport on HazukiSourceService {
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
      throw Exception('jm.js 鏍煎紡鏃犳晥锛氭湭鎵惧埌 extends ComicSource 鐨勭被瀹氫箟');
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
}

class _SourceLoadResult {
  const _SourceLoadResult({required this.jmFile, required this.message});

  final File jmFile;
  final String message;
}
