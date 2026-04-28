part of '../hazuki_source_service.dart';

extension SourceBootstrapSupport on HazukiSourceService {
  Future<bool> loadSoftwareLogCaptureEnabled() async {
    final facade = this.facade;
    final prefs = await facade.ensurePrefs();
    facade.debug.softwareLogCaptureEnabled =
        prefs.getBool(HazukiSourceService._softwareLogCaptureEnabledKey) ??
        false;
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
    await prefs.setBool(
      HazukiSourceService._softwareLogCaptureEnabledKey,
      enabled,
    );
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
    final facade = this.facade;
    final inFlight = facade.initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initInternal(
      onSourceDownloadProgress: onSourceDownloadProgress,
      prewarm: prewarm,
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

  Future<void> ensureInitialized() async {
    final facade = this.facade;
    if (isInitialized) {
      return;
    }

    final inFlight = facade.initFuture;
    if (inFlight == null) {
      await init();
    } else {
      await inFlight;
    }

    if (isInitialized) {
      return;
    }

    facade.initFuture = null;
    await init();

    if (!isInitialized) {
      throw Exception('source_not_initialized:${facade.statusText}');
    }
  }

  Future<void> _initInternal({
    void Function(int received, int total)? onSourceDownloadProgress,
    required bool prewarm,
  }) async {
    final facade = this.facade;
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
      );
      final prefs = await facade.ensurePrefs();
      facade.debug.softwareLogCaptureEnabled =
          prefs.getBool(HazukiSourceService._softwareLogCaptureEnabledKey) ??
          false;
      _configureDioCookieBridge();
      await _initImageCache();
      await _initDiscoverCache();
      _setRuntimeBusyState(
        busyPhase,
        SourceRuntimeStep.downloadingSource,
        debugDetail: 'downloading_source',
      );
      final result = await _downloadOrLoadSourceFiles(
        onProgress: onSourceDownloadProgress,
      );
      _setRuntimeBusyState(
        busyPhase,
        SourceRuntimeStep.creatingEngine,
        debugDetail: 'creating_engine',
      );
      final meta = await _loadSourceMetadata(result.jmFile);
      facade.runtime.sourceMeta = meta;
      _setRuntimeReadyState(result: result, meta: meta);
    } catch (e) {
      _setRuntimeFailedState(e);
    }
  }

  Future<String?> _downloadFromUrls(
    List<String> urls, {
    String source = 'source_fetch',
  }) async {
    if (urls.isEmpty) {
      return null;
    }

    Future<String?> requestOnce(String url) async {
      final startedAt = DateTime.now();
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
            extra: {'skipNetworkDebugLog': true, 'hazukiLogCategory': source},
          ),
        );
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
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
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
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
  }) async {
    for (final url in urls) {
      final startedAt = DateTime.now();
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
            extra: {'skipNetworkDebugLog': true, 'hazukiLogCategory': source},
          ),
          onReceiveProgress: onProgress,
        );
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
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
        _appendNetworkLog(
          source: source,
          method: 'GET',
          url: url,
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
