part of '../hazuki_source_service.dart';

extension HazukiSourceServiceDebugCapability on HazukiSourceService {
  static const int _maxApplicationLogsKept = 180;
  static const int _maxReaderLogsKept = 180;
  static const int _maxNetworkLogsKept = 120;
  static const int _networkPreviewKeep = 320;
  static const int _networkFullBodyKeep = 1600;
  static const int _readerStringKeep = 220;
  static const int _applicationStringKeep = 320;
  static const int _networkHeadersKeep = 12;

  Future<void> warmUpFavoritesDebugInfo() async {
    if (!_softwareLogCaptureEnabled || !isLogged) {
      return;
    }
    if (_isWarmingUpFavoritesDebug) {
      return;
    }
    _isWarmingUpFavoritesDebug = true;
    try {
      await _collectFavoritesDebugInfoCore();
    } catch (_) {
      // 静默预热，不向 UI 抛错
    } finally {
      _isWarmingUpFavoritesDebug = false;
    }
  }

  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  }) async {
    if (!_softwareLogCaptureEnabled) {
      return _buildDisabledFavoritesDebugInfo();
    }
    if (!forceRefresh && _favoritesDebugCache != null) {
      return _favoritesDebugCache!;
    }
    return _collectFavoritesDebugInfoCore();
  }

  Future<Map<String, dynamic>> _collectFavoritesDebugInfoCore() async {
    if (!_softwareLogCaptureEnabled) {
      return _buildDisabledFavoritesDebugInfo();
    }
    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final info = <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
        'supportsAccount': _sourceMeta?.supportsAccount,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'checks': <String, dynamic>{},
      'calls': <String, dynamic>{},
      'favoritePageLoadResult': <String, dynamic>{},
    };

    final checks = info['checks'] as Map<String, dynamic>;
    checks['hasSource'] = _asBool(engine.evaluate('!!this.__hazuki_source'));
    checks['hasFavorites'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites'),
    );
    checks['multiFolder'] = _jsonSafe(
      engine.evaluate('this.__hazuki_source?.favorites?.multiFolder'),
    );
    checks['hasLoadFolders'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites?.loadFolders'),
    );
    checks['hasLoadComics'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites?.loadComics'),
    );
    checks['hasLoadNext'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites?.loadNext'),
    );

    final calls = info['calls'] as Map<String, dynamic>;
    calls['loadFolders(null)'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadFolders?.(null)',
      name: 'debug_favorites_loadFolders.js',
    );
    calls['loadComics(1, "0")'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadComics?.(1, "0")',
      name: 'debug_favorites_loadComics_0.js',
    );
    calls['loadComics(1, null)'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadComics?.(1, null)',
      name: 'debug_favorites_loadComics_null.js',
    );
    calls['loadNext(null, "0")'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadNext?.(null, "0")',
      name: 'debug_favorites_loadNext.js',
    );

    final pageLoad = await loadFavoriteComics(page: 1, folderId: '0');
    final pageLoadInfo = info['favoritePageLoadResult'] as Map<String, dynamic>;
    pageLoadInfo['errorMessage'] = pageLoad.errorMessage;
    pageLoadInfo['count'] = pageLoad.comics.length;
    pageLoadInfo['firstFive'] = pageLoad.comics
        .take(5)
        .map(
          (comic) => {
            'id': comic.id,
            'title': comic.title,
            'subTitle': comic.subTitle,
            'cover': comic.cover,
          },
        )
        .toList();

    _favoritesDebugCache = info;
    return info;
  }

  Map<String, dynamic> _buildDisabledFavoritesDebugInfo() {
    return <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
        'supportsAccount': _sourceMeta?.supportsAccount,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': false,
      'disabledReason': 'software_log_capture_disabled',
      'checks': <String, dynamic>{},
      'calls': <String, dynamic>{},
      'favoritePageLoadResult': <String, dynamic>{},
    };
  }

  Future<dynamic> _awaitJsResult(dynamic result) async {
    if (result is Future) {
      return await result;
    }
    return result;
  }

  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    if (!_softwareLogCaptureEnabled) {
      return;
    }
    _appendApplicationLog(
      level: level,
      title: title,
      content: content,
      source: source,
    );
  }

  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {
    if (!_softwareLogCaptureEnabled) {
      return;
    }
    _appendReaderLog(
      level: level,
      title: title,
      content: content,
      source: source,
    );
  }

  void _appendReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {
    final now = DateTime.now();
    final normalizedLevel = level.trim().isEmpty ? 'info' : level.trim();
    final titleText = title.trim().isEmpty ? 'Reader' : title.trim();
    final safeContent = _compactReaderLogContent(
      _jsonSafe(content),
      source: source,
      level: normalizedLevel,
    );
    final contentText = _toBodyFull(safeContent) ?? 'null';
    final dedupKey = [
      source,
      normalizedLevel.toLowerCase(),
      titleText,
      contentText,
    ].join('|');

    final existingIndex = _recentReaderLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = _recentReaderLogs[existingIndex];
      existing['mergedCount'] = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['lastSeenAt'] = now.toIso8601String();
      existing['level'] = normalizedLevel;
      existing['title'] = titleText;
      existing['content'] = safeContent;
      existing['contentPreview'] = _toBodyPreview(contentText);
      return;
    }

    _recentReaderLogs.add({
      'time': now.toIso8601String(),
      'lastSeenAt': now.toIso8601String(),
      'mergedCount': 1,
      'dedupKey': dedupKey,
      'source': source,
      'level': normalizedLevel,
      'title': titleText,
      'content': safeContent,
      'contentPreview': _toBodyPreview(contentText),
    });
    if (_recentReaderLogs.length > _maxReaderLogsKept) {
      _recentReaderLogs.removeRange(
        0,
        _recentReaderLogs.length - _maxReaderLogsKept,
      );
    }
  }

  void _appendApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    final now = DateTime.now();
    final normalizedLevel = level.trim().isEmpty ? 'info' : level.trim();
    final titleText = title.trim().isEmpty ? 'Application' : title.trim();
    final safeContent = _compactGenericLogValue(
      _jsonSafe(content),
      maxStringLength: _applicationStringKeep,
      maxItems: 20,
      maxDepth: 4,
    );
    final contentText = _toBodyFull(safeContent) ?? 'null';
    final dedupKey = [
      source,
      normalizedLevel.toLowerCase(),
      titleText,
      contentText,
    ].join('|');

    final existingIndex = _recentApplicationLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = _recentApplicationLogs[existingIndex];
      existing['mergedCount'] = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['lastSeenAt'] = now.toIso8601String();
      existing['level'] = normalizedLevel;
      existing['title'] = titleText;
      existing['content'] = safeContent;
      existing['contentPreview'] = _toBodyPreview(contentText);
      return;
    }

    _recentApplicationLogs.add({
      'time': now.toIso8601String(),
      'lastSeenAt': now.toIso8601String(),
      'mergedCount': 1,
      'dedupKey': dedupKey,
      'source': source,
      'level': normalizedLevel,
      'title': titleText,
      'content': safeContent,
      'contentPreview': _toBodyPreview(contentText),
    });
    if (_recentApplicationLogs.length > _maxApplicationLogsKept) {
      _recentApplicationLogs.removeRange(
        0,
        _recentApplicationLogs.length - _maxApplicationLogsKept,
      );
    }
  }

  void _appendNetworkLog({
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
    if (!_softwareLogCaptureEnabled) {
      return;
    }
    final endedAt = DateTime.now();
    final durationMs = endedAt.difference(startedAt).inMilliseconds;
    if (_shouldSkipNetworkLogStorage(
      source: source,
      category: category,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    )) {
      return;
    }
    final isImportant = _isImportantNetworkLogForStorage(
      source: source,
      category: category,
      url: url,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    );
    final requestHeadersSafe = isImportant
        ? _compactNetworkHeaders(_jsonSafe(requestHeaders))
        : null;
    final requestDataSafe = isImportant
        ? _compactNetworkPayload(_jsonSafe(requestData), keep: 420)
        : null;
    final responseHeadersSafe = isImportant
        ? _compactNetworkHeaders(_jsonSafe(responseHeaders))
        : null;
    final responseBodyFull = isImportant
        ? _truncateBody(_toBodyFull(responseBody), keep: _networkFullBodyKeep)
        : null;
    final responseBodyPreview = isImportant
        ? _toBodyPreview(responseBodyFull, keep: _networkPreviewKeep)
        : _toBodyPreview(_toBodyFull(responseBody), keep: 160);

    final dedupKey = [
      category ?? '',
      source,
      method,
      url,
      statusCode?.toString() ?? 'null',
      error ?? '',
      requestHeadersSafe?.toString() ?? '',
      requestDataSafe?.toString() ?? '',
      responseHeadersSafe?.toString() ?? '',
      responseBodyPreview ?? '',
    ].join('|');

    final existingIndex = _recentNetworkLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = _recentNetworkLogs[existingIndex];
      final mergedCount = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['mergedCount'] = mergedCount;
      existing['lastSeenAt'] = endedAt.toIso8601String();
      existing['durationMs'] = durationMs;
      existing['statusCode'] = statusCode;
      existing['error'] = error;
      existing['responseBodyPreview'] = responseBodyPreview;
      existing['responseBodyFull'] = responseBodyFull;
      existing['responseHeaders'] = responseHeadersSafe;
      existing['requestData'] = requestDataSafe;
      existing['requestHeaders'] = requestHeadersSafe;
      _networkLogDedupedCount++;
      return;
    }

    final logEntry = <String, dynamic>{
      'time': endedAt.toIso8601String(),
      'lastSeenAt': endedAt.toIso8601String(),
      'mergedCount': 1,
      'dedupKey': dedupKey,
      'source': source,
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': durationMs,
      'requestHeaders': requestHeadersSafe,
      'requestData': requestDataSafe,
      'responseHeaders': responseHeadersSafe,
      'responseBodyPreview': responseBodyPreview,
      'responseBodyFull': responseBodyFull,
      'error': error,
    };
    if (category != null) {
      logEntry['category'] = category;
    }
    _recentNetworkLogs.add(logEntry);
    if (_recentNetworkLogs.length > _maxNetworkLogsKept) {
      _recentNetworkLogs.removeRange(
        0,
        _recentNetworkLogs.length - _maxNetworkLogsKept,
      );
    }
  }

  bool _shouldSkipNetworkLogStorage({
    required String source,
    required String? category,
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedCategory = (category ?? '').toLowerCase();
    final normalizedError = (error ?? '').trim().toLowerCase();
    final hasError = normalizedError.isNotEmpty && normalizedError != 'null';
    if (hasError) {
      return false;
    }
    if (statusCode != null && statusCode >= 400) {
      return false;
    }
    if (durationMs >= 2500) {
      return false;
    }
    if (normalizedCategory == 'image_download') {
      return true;
    }
    return false;
  }

  bool _isImportantNetworkLogForStorage({
    required String source,
    required String? category,
    required String url,
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedSource = source.toLowerCase();
    final normalizedCategory = (category ?? '').toLowerCase();
    final normalizedUrl = url.toLowerCase();
    final normalizedError = (error ?? '').toLowerCase();

    if (normalizedError.isNotEmpty && normalizedError != 'null') {
      return true;
    }
    if (statusCode != null && statusCode >= 400) {
      return true;
    }
    if (durationMs >= 2500) {
      return true;
    }
    if (normalizedCategory == 'image_download') {
      return false;
    }
    if (normalizedSource.contains('login') ||
        normalizedSource.contains('avatar') ||
        normalizedSource.contains('source_version')) {
      return true;
    }
    if (normalizedUrl.contains('/login') ||
        normalizedUrl.contains('/favorite') ||
        normalizedUrl.contains('/user') ||
        normalizedUrl.contains('/daily') ||
        normalizedUrl.contains('/daily_chk') ||
        normalizedUrl.contains('index.json') ||
        normalizedUrl.contains('/jm.js')) {
      return true;
    }
    return false;
  }

  String? _toBodyFull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is List<int>) {
      return '[bytes length=${value.length}]';
    }
    return value.toString();
  }

  String? _toBodyPreview(String? fullBody, {int keep = 800}) {
    if (fullBody == null) {
      return null;
    }
    if (fullBody.length <= keep) {
      return fullBody;
    }
    final omitted = fullBody.length - keep;
    return '${fullBody.substring(0, keep)}... [omitted $omitted chars]';
  }

  String? _truncateBody(String? fullBody, {required int keep}) {
    if (fullBody == null) {
      return null;
    }
    if (fullBody.length <= keep) {
      return fullBody;
    }
    final omitted = fullBody.length - keep;
    return '${fullBody.substring(0, keep)}... [omitted $omitted chars]';
  }

  dynamic _compactNetworkHeaders(dynamic value) {
    if (value is! Map) {
      return _compactGenericLogValue(
        value,
        maxStringLength: 160,
        maxItems: _networkHeadersKeep,
        maxDepth: 2,
      );
    }
    final filtered = <String, dynamic>{};
    const allowed = {
      'content-type',
      'content-length',
      'location',
      'cache-control',
      'set-cookie',
      'user-agent',
      'accept',
      'accept-language',
      'referer',
      'origin',
      'cookie',
      'authorization',
    };
    for (final entry in value.entries.take(_networkHeadersKeep)) {
      final key = entry.key.toString();
      final lower = key.toLowerCase();
      if (!allowed.contains(lower)) {
        continue;
      }
      if (lower == 'cookie' || lower == 'authorization' || lower == 'set-cookie') {
        filtered[key] = '[redacted]';
        continue;
      }
      filtered[key] = _compactGenericLogValue(
        entry.value,
        maxStringLength: 160,
        maxItems: 4,
        maxDepth: 2,
      );
    }
    return filtered;
  }

  dynamic _compactNetworkPayload(dynamic value, {required int keep}) {
    return _compactGenericLogValue(
      value,
      maxStringLength: keep,
      maxItems: 8,
      maxDepth: 4,
    );
  }

  dynamic _compactReaderLogContent(
    dynamic value, {
    required String source,
    required String level,
  }) {
    final compacted = _compactGenericLogValue(
      value,
      maxStringLength: _readerStringKeep,
      maxItems: 80,
      maxDepth: 5,
    );
    if (compacted is! Map) {
      return compacted;
    }

    final normalizedSource = source.toLowerCase();
    final normalizedLevel = level.toLowerCase();
    final keepCoreKeys = <String>{
      'sessionId',
      'comicId',
      'epId',
      'chapterTitle',
      'chapterIndex',
      'readerMode',
      'currentPageIndex',
      'currentPage',
      'pageIndicatorIndex',
      'totalPages',
      'trigger',
      'pageIndex',
      'page',
      'setting',
      'value',
      'brightnessPercent',
      'error',
      'imageCount',
      'imageUrl',
      'savedPath',
      'enabled',
      'notificationType',
      'depth',
      'diagnosticSequence',
      'previousListPixels',
      'currentListPixels',
      'listDeltaPixels',
      'jumpedToTop',
      'largeJump',
      'resolvedPageIndex',
      'resolvedPage',
      'aspectRatio',
      'isBeforeCurrentPage',
    };

    final keepVerboseKeys = <String>{
      'loadImagesError',
      'listViewportDimension',
      'listExtentBefore',
      'listExtentAfter',
      'listAtEdge',
      'listOutOfRange',
      'listUserDirection',
      'nearbyRenderedItems',
      'activeProgrammaticListScrollReason',
      'activeProgrammaticListTargetIndex',
      'lastCompletedProgrammaticListTargetIndex',
      'lastObservedListPixels',
      'zoomScale',
      'activePointerCount',
      'providerCacheSize',
      'providerFutureCacheSize',
      'aspectRatioCacheSize',
      'prefetchAheadRunning',
      'activeUnscrambleTasks',
      'listUserScrollInProgress',
      'controlsVisible',
      'tapToTurnPage',
      'pageIndicator',
      'pinchToZoom',
      'longPressToSave',
      'immersiveMode',
      'keepScreenOn',
      'customBrightness',
      'brightnessValue',
      'loadingImages',
      'noImageModeEnabled',
      'isZoomed',
      'zoomInteracting',
      'listPixels',
      'listMaxScrollExtent',
      'listMinScrollExtent',
      'pageControllerPage',
    };

    final shouldKeepVerbose =
        normalizedLevel == 'warning' ||
        normalizedLevel == 'error' ||
        normalizedSource == 'reader_position';

    final filtered = <String, dynamic>{};
    for (final entry in compacted.entries) {
      final key = entry.key.toString();
      if (keepCoreKeys.contains(key) ||
          (shouldKeepVerbose && keepVerboseKeys.contains(key))) {
        filtered[key] = entry.value;
      }
    }

    if (filtered['nearbyRenderedItems'] is List && normalizedLevel == 'info') {
      filtered.remove('nearbyRenderedItems');
    }

    return filtered;
  }

  dynamic _compactGenericLogValue(
    dynamic value, {
    required int maxStringLength,
    required int maxItems,
    required int maxDepth,
    int depth = 0,
  }) {
    if (value == null) {
      return null;
    }
    if (depth >= maxDepth) {
      if (value is Map) {
        return '[map omitted]';
      }
      if (value is Iterable && value is! String) {
        return '[list omitted]';
      }
    }
    if (value is String) {
      return _truncateBody(value, keep: maxStringLength);
    }
    if (value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      var kept = 0;
      for (final entry in value.entries) {
        if (kept >= maxItems) {
          result['__truncated__'] = '+${value.length - maxItems} keys';
          break;
        }
        final normalized = _compactGenericLogValue(
          entry.value,
          maxStringLength: maxStringLength,
          maxItems: maxItems,
          maxDepth: maxDepth,
          depth: depth + 1,
        );
        if (normalized != null) {
          result[entry.key.toString()] = normalized;
          kept++;
        }
      }
      return result;
    }
    if (value is Iterable) {
      final items = value.toList(growable: false);
      final limited = <dynamic>[];
      final takeCount = items.length > maxItems ? maxItems : items.length;
      for (var i = 0; i < takeCount; i++) {
        limited.add(
          _compactGenericLogValue(
            items[i],
            maxStringLength: maxStringLength,
            maxItems: maxItems,
            maxDepth: maxDepth,
            depth: depth + 1,
          ),
        );
      }
      if (items.length > maxItems) {
        limited.add('[+${items.length - maxItems} items]');
      }
      return limited;
    }
    return _truncateBody(value.toString(), keep: maxStringLength);
  }

  int _estimatePayloadBytes(Object? value) {
    if (value == null) {
      return 0;
    }
    try {
      return utf8.encode(jsonEncode(value)).length;
    } catch (_) {
      return utf8.encode(value.toString()).length;
    }
  }

  Future<Map<String, dynamic>> collectNetworkDebugInfo() async {
    final approxBytes = _recentNetworkLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    final info = <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': _softwareLogCaptureEnabled,
      'networkLogStats': {
        'keptCount': _recentNetworkLogs.length,
        'dedupedCount': _networkLogDedupedCount,
        'approxBytes': approxBytes,
      },
      'lastLoginDebugInfo': _lastLoginDebugInfo,
      'lastSourceVersionDebugInfo': _lastSourceVersionDebugInfo,
      'recentNetworkLogs': _recentNetworkLogs.map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('dedupKey');
        return copy;
      }).toList(),
    };
    return info;
  }

  Future<Map<String, dynamic>> collectApplicationDebugInfo() async {
    final approxBytes = _recentApplicationLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    final info = <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': _softwareLogCaptureEnabled,
      'applicationLogStats': {
        'keptCount': _recentApplicationLogs.length,
        'approxBytes': approxBytes,
      },
      'recentApplicationLogs': _recentApplicationLogs.map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('dedupKey');
        return copy;
      }).toList(),
    };
    return info;
  }

  Future<Map<String, dynamic>> collectReaderDebugInfo() async {
    final approxBytes = _recentReaderLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    final info = <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': _softwareLogCaptureEnabled,
      'readerLogStats': {
        'keptCount': _recentReaderLogs.length,
        'approxBytes': approxBytes,
      },
      'recentReaderLogs': _recentReaderLogs.map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('dedupKey');
        return copy;
      }).toList(),
    };
    return info;
  }

  Future<Map<String, dynamic>> _debugJsCall({
    required String code,
    required String name,
  }) async {
    final engine = _engine;
    if (engine == null) {
      return {'ok': false, 'error': 'engine is null'};
    }

    try {
      final result = engine.evaluate(code, name: name);
      final resolved = await _awaitJsResult(
        result,
      ).timeout(const Duration(seconds: 20));
      return {'ok': true, 'data': _jsonSafe(resolved)};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  dynamic _jsonSafe(dynamic value) {
    try {
      return jsonDecode(jsonEncode(value));
    } catch (_) {
      return value?.toString();
    }
  }
}
