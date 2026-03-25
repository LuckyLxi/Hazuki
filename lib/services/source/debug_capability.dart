part of '../hazuki_source_service.dart';

extension HazukiSourceServiceDebugCapability on HazukiSourceService {
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
    final safeContent = _jsonSafe(content);
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
    if (_recentReaderLogs.length > 600) {
      _recentReaderLogs.removeRange(0, _recentReaderLogs.length - 600);
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
    final safeContent = _jsonSafe(content);
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
    if (_recentApplicationLogs.length > 300) {
      _recentApplicationLogs.removeRange(
        0,
        _recentApplicationLogs.length - 300,
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
    final isImportant = _isImportantNetworkLogForStorage(
      source: source,
      url: url,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    );
    final requestHeadersSafe = isImportant ? _jsonSafe(requestHeaders) : null;
    final requestDataSafe = isImportant ? _jsonSafe(requestData) : null;
    final responseHeadersSafe = isImportant ? _jsonSafe(responseHeaders) : null;
    final responseBodyFull = isImportant ? _toBodyFull(responseBody) : null;
    final responseBodyPreview = isImportant
        ? _toBodyPreview(responseBodyFull)
        : _toBodyPreview(_toBodyFull(responseBody));

    final dedupKey = [
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
      _networkLogDedupedCount++;
      return;
    }

    _recentNetworkLogs.add({
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
    });
    if (_recentNetworkLogs.length > 300) {
      _recentNetworkLogs.removeRange(0, _recentNetworkLogs.length - 300);
    }
  }

  bool _isImportantNetworkLogForStorage({
    required String source,
    required String url,
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedSource = source.toLowerCase();
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

  String? _toBodyPreview(String? fullBody) {
    if (fullBody == null) {
      return null;
    }
    if (fullBody.length <= 800) {
      return fullBody;
    }
    return '${fullBody.substring(0, 800)}...';
  }

  Future<Map<String, dynamic>> collectNetworkDebugInfo() async {
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
