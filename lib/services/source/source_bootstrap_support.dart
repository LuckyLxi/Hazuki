part of '../hazuki_source_service.dart';

extension SourceBootstrapSupport on HazukiSourceService {
  Future<bool> loadSoftwareLogCaptureEnabled() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    _softwareLogCaptureEnabled =
        prefs.getBool(HazukiSourceService._softwareLogCaptureEnabledKey) ??
        false;
    if (!_softwareLogCaptureEnabled) {
      _clearCapturedLogs();
    }
    return _softwareLogCaptureEnabled;
  }

  Future<void> setSoftwareLogCaptureEnabled(bool enabled) async {
    _softwareLogCaptureEnabled = enabled;
    if (!enabled) {
      _clearCapturedLogs();
    }
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(
      HazukiSourceService._softwareLogCaptureEnabledKey,
      enabled,
    );
  }

  void _clearCapturedLogs() {
    _favoritesDebugCache = null;
    _recentNetworkLogs.clear();
    _recentApplicationLogs.clear();
    _recentReaderLogs.clear();
    _networkLogDedupedCount = 0;
    _lastLoginDebugInfo = null;
    _lastSourceVersionDebugInfo = null;
  }

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
  }) async {
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initInternal(
      onSourceDownloadProgress: onSourceDownloadProgress,
    );
    _initFuture = future;
    await future;
  }

  Future<void> ensureInitialized() async {
    if (isInitialized) {
      return;
    }

    final inFlight = _initFuture;
    if (inFlight == null) {
      await init();
    } else {
      await inFlight;
    }

    if (isInitialized) {
      return;
    }

    _initFuture = null;
    await init();

    if (!isInitialized) {
      throw Exception('source_not_initialized:$_statusText');
    }
  }

  Future<void> _initInternal({
    void Function(int received, int total)? onSourceDownloadProgress,
  }) async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _softwareLogCaptureEnabled =
          _prefs?.getBool(HazukiSourceService._softwareLogCaptureEnabledKey) ??
          false;
      _configureDioCookieBridge();
      await _initImageCache();
      await _initDiscoverCache();
      final result = await _downloadOrLoadSourceFiles(
        onProgress: onSourceDownloadProgress,
      );
      final meta = await _loadSourceMetadata(result.initFile, result.jmFile);
      _sourceMeta = meta;
      _statusText =
          '${result.message}|${meta.name}|${meta.key}|${meta.version}';
    } catch (e) {
      _statusText = 'source_init_failed:$e';
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
  const _SourceLoadResult({
    required this.initFile,
    required this.jmFile,
    required this.message,
  });

  final File initFile;
  final File jmFile;
  final String message;
}
