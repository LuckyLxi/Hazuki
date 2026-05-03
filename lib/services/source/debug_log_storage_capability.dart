part of '../hazuki_source_service.dart';

extension HazukiSourceServiceDebugLogStorageCapability on HazukiSourceService {
  void addDebugLog({
    required String type,
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    if (!facade.softwareLogCaptureEnabled) {
      return;
    }
    _appendTypedDebugLog(
      type: _normalizeDebugLogType(type),
      level: level,
      title: title,
      content: _compactGenericLogValue(
        _jsonSafe(content),
        maxStringLength: _debugApplicationStringKeep,
        maxItems: 24,
        maxDepth: 4,
      ),
      source: source,
    );
  }

  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    if (!facade.softwareLogCaptureEnabled) {
      return;
    }
    _appendApplicationLog(
      level: level,
      title: title,
      content: content,
      source: source,
    );
    _appendTypedDebugLog(
      type: _resolveGenericDebugLogType(
        level: level,
        title: title,
        content: content,
        source: source,
      ),
      level: level,
      title: title,
      content: _compactGenericLogValue(
        _jsonSafe(content),
        maxStringLength: _debugApplicationStringKeep,
        maxItems: 24,
        maxDepth: 4,
      ),
      source: source,
    );
  }

  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {
    if (!facade.softwareLogCaptureEnabled) {
      return;
    }
    _appendReaderLog(
      level: level,
      title: title,
      content: content,
      source: source,
    );
    _appendTypedDebugLog(
      type: _resolveGenericDebugLogType(
        level: level,
        title: title,
        content: content,
        source: source,
      ),
      level: level,
      title: title,
      content: _compactReaderLogContent(
        _jsonSafe(content),
        source: source,
        level: level,
      ),
      source: source,
    );
  }

  void _pruneByAgeIfNeeded() {
    final now = DateTime.now();
    if (facade.debug._lastAgeCleanupAt != null &&
        now.difference(facade.debug._lastAgeCleanupAt!) <
            const Duration(hours: 1)) {
      return;
    }
    facade.debug._lastAgeCleanupAt = now;
    final cutoff = now.subtract(_debugLogMaxAge);
    _pruneListByAge(facade.debug.recentNetworkLogs, cutoff);
    _pruneListByAge(facade.debug.recentApplicationLogs, cutoff);
    _pruneListByAge(facade.debug.recentReaderLogs, cutoff);
    _pruneListByAge(facade.debug.recentErrorLogs, cutoff);
    _pruneListByAge(facade.debug.recentActionLogs, cutoff);
    _pruneListByAge(facade.debug.recentSystemLogs, cutoff);
    _pruneListByAge(facade.debug.recentPerformanceLogs, cutoff);
  }

  void _pruneListByAge(List<Map<String, dynamic>> logs, DateTime cutoff) {
    logs.removeWhere((log) {
      final t = DateTime.tryParse(log['time'] as String? ?? '');
      return t != null && t.isBefore(cutoff);
    });
  }

  void _appendTypedDebugLog({
    required String type,
    required String level,
    required String title,
    required Object? content,
    required String source,
  }) {
    _pruneByAgeIfNeeded();
    final targetLogs = _typedDebugLogsFor(type);
    final now = DateTime.now();
    final normalizedType = _normalizeDebugLogType(type);
    final normalizedLevel = _normalizeDebugLevel(level);
    final sourceText = source.trim().isEmpty ? 'app' : source.trim();
    final titleText = title.trim().isEmpty ? 'Log' : title.trim();
    final safeContent = _jsonSafe(content);
    final contentText = _toBodyFull(safeContent) ?? 'null';
    final dedupKey = [
      normalizedType,
      sourceText,
      normalizedLevel,
      titleText,
      contentText,
    ].join('|');

    final existingIndex = targetLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = targetLogs[existingIndex];
      existing['mergedCount'] = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['lastSeenAt'] = now.toIso8601String();
      existing['level'] = normalizedLevel;
      existing['content'] = safeContent;
      existing['contentPreview'] = _toBodyPreview(contentText, keep: 320);
      return;
    }

    targetLogs.add({
      'type': normalizedType,
      'time': now.toIso8601String(),
      'lastSeenAt': now.toIso8601String(),
      'mergedCount': 1,
      'dedupKey': dedupKey,
      'source': sourceText,
      'level': normalizedLevel,
      'title': titleText,
      'content': safeContent,
      'contentPreview': _toBodyPreview(contentText, keep: 320),
    });
    if (targetLogs.length > _debugMaxTypedLogsKept) {
      targetLogs.removeRange(0, targetLogs.length - _debugMaxTypedLogsKept);
    }
  }

  List<Map<String, dynamic>> _typedDebugLogsFor(String type) {
    return switch (_normalizeDebugLogType(type)) {
      debugLogTypeError => facade.debug.recentErrorLogs,
      debugLogTypeAction => facade.debug.recentActionLogs,
      debugLogTypeSystem => facade.debug.recentSystemLogs,
      debugLogTypePerformance => facade.debug.recentPerformanceLogs,
      _ => facade.debug.recentActionLogs,
    };
  }

  String _normalizeDebugLogType(String type) {
    final normalized = type.trim().toLowerCase();
    if (debugLogTypes.contains(normalized)) {
      return normalized;
    }
    return debugLogTypeAction;
  }

  String _normalizeDebugLevel(String level) {
    final normalized = level.trim().toLowerCase();
    return switch (normalized) {
      'error' => 'error',
      'warn' || 'warning' => 'warn',
      _ => 'info',
    };
  }

  String _resolveGenericDebugLogType({
    required String level,
    required String title,
    required Object? content,
    required String source,
  }) {
    final normalizedLevel = _normalizeDebugLevel(level);
    if (normalizedLevel == 'error') {
      return debugLogTypeError;
    }

    final sourceText = source.toLowerCase();
    final titleText = title.toLowerCase();
    final contentText = (_toBodyFull(_jsonSafe(content)) ?? '').toLowerCase();
    final combined = '$sourceText\n$titleText\n$contentText';

    const errorKeywords = [
      'error',
      'exception',
      'failed',
      'failure',
      'timeout',
      'unauthorized',
      'forbidden',
    ];
    if (errorKeywords.any(combined.contains)) {
      return debugLogTypeError;
    }

    const performanceKeywords = [
      'jank',
      'slow',
      'frame',
      'duration',
      'latency',
      'reader_position',
      'performance',
    ];
    if (performanceKeywords.any(combined.contains)) {
      return debugLogTypePerformance;
    }

    const systemSources = [
      'source_',
      'source_runtime',
      'source_version',
      'source_category',
      'js_',
      'dio_',
      'network',
      'bootstrap',
    ];
    if (systemSources.any(sourceText.contains)) {
      return debugLogTypeSystem;
    }

    return debugLogTypeAction;
  }

  String _resolveNetworkDebugLogType({
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedError = (error ?? '').trim().toLowerCase();
    if (normalizedError.isNotEmpty && normalizedError != 'null') {
      return debugLogTypeError;
    }
    if (statusCode != null && statusCode >= 400) {
      return debugLogTypeError;
    }
    if (durationMs >= 2500) {
      return debugLogTypePerformance;
    }
    return debugLogTypeSystem;
  }

  String _networkDebugLevel({
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedError = (error ?? '').trim().toLowerCase();
    if (normalizedError.isNotEmpty && normalizedError != 'null') {
      return 'error';
    }
    if (statusCode != null && statusCode >= 400) {
      return 'error';
    }
    if ((statusCode != null && statusCode >= 300) || durationMs >= 2500) {
      return 'warn';
    }
    return 'info';
  }

  void _appendReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) {
    final recentReaderLogs = facade.debug.recentReaderLogs;
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

    final existingIndex = recentReaderLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = recentReaderLogs[existingIndex];
      existing['mergedCount'] = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['lastSeenAt'] = now.toIso8601String();
      existing['level'] = normalizedLevel;
      existing['title'] = titleText;
      existing['content'] = safeContent;
      existing['contentPreview'] = _toBodyPreview(contentText);
      return;
    }

    recentReaderLogs.add({
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
    if (recentReaderLogs.length > _debugMaxReaderLogsKept) {
      recentReaderLogs.removeRange(
        0,
        recentReaderLogs.length - _debugMaxReaderLogsKept,
      );
    }
  }

  void _appendApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    final recentApplicationLogs = facade.debug.recentApplicationLogs;
    final now = DateTime.now();
    final normalizedLevel = level.trim().isEmpty ? 'info' : level.trim();
    final titleText = title.trim().isEmpty ? 'Application' : title.trim();
    final safeContent = _compactGenericLogValue(
      _jsonSafe(content),
      maxStringLength: _debugApplicationStringKeep,
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

    final existingIndex = recentApplicationLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = recentApplicationLogs[existingIndex];
      existing['mergedCount'] = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['lastSeenAt'] = now.toIso8601String();
      existing['level'] = normalizedLevel;
      existing['title'] = titleText;
      existing['content'] = safeContent;
      existing['contentPreview'] = _toBodyPreview(contentText);
      return;
    }

    recentApplicationLogs.add({
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
    if (recentApplicationLogs.length > _debugMaxApplicationLogsKept) {
      recentApplicationLogs.removeRange(
        0,
        recentApplicationLogs.length - _debugMaxApplicationLogsKept,
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
    if (!facade.softwareLogCaptureEnabled) {
      return;
    }
    final recentNetworkLogs = facade.debug.recentNetworkLogs;
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
    final keepRequestDetails = _shouldKeepDetailedNetworkRequest(
      statusCode: statusCode,
      error: error,
    );
    final keepResponseDetails = _shouldKeepDetailedNetworkResponse(
      source: source,
      category: category,
      url: url,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    );
    final requestHeadersSafe = keepRequestDetails
        ? _compactNetworkHeaders(_jsonSafe(requestHeaders))
        : null;
    final requestDataSafe = keepRequestDetails
        ? _compactNetworkPayload(_jsonSafe(requestData), keep: 420)
        : null;
    final responseHeadersSafe = keepResponseDetails
        ? _compactNetworkHeaders(_jsonSafe(responseHeaders))
        : null;
    final responseBodyFull = keepResponseDetails
        ? _toBodyPreview(
            _toBodyFull(responseBody),
            keep: _debugNetworkFullBodyKeep,
          )
        : null;
    final responseBodyPreviewSource = keepResponseDetails
        ? responseBodyFull
        : _toBodyPreview(
            _toBodyFull(responseBody),
            keep: _debugNetworkPreviewKeep,
          );
    final responseBodyPreview = isImportant
        ? _toBodyPreview(
            responseBodyPreviewSource,
            keep: _debugNetworkPreviewKeep,
          )
        : _toBodyPreview(_toBodyFull(responseBody), keep: 160);

    final dedupKey = [
      category ?? '',
      source,
      method,
      url,
      statusCode?.toString() ?? 'null',
      error ?? '',
      requestHeadersSafe != null ? jsonEncode(requestHeadersSafe) : '',
      requestDataSafe != null ? jsonEncode(requestDataSafe) : '',
      responseHeadersSafe != null ? jsonEncode(responseHeadersSafe) : '',
      responseBodyPreview ?? '',
    ].join('|');

    final existingIndex = recentNetworkLogs.indexWhere(
      (log) => log['dedupKey'] == dedupKey,
    );
    if (existingIndex >= 0) {
      final existing = recentNetworkLogs[existingIndex];
      existing['mergedCount'] = (existing['mergedCount'] as int? ?? 1) + 1;
      existing['lastSeenAt'] = endedAt.toIso8601String();
      existing['durationMs'] = durationMs;
      existing['statusCode'] = statusCode;
      existing['error'] = error;
      existing['responseBodyPreview'] = responseBodyPreview;
      existing['responseBodyFull'] = responseBodyFull;
      existing['responseHeaders'] = responseHeadersSafe;
      existing['requestData'] = requestDataSafe;
      existing['requestHeaders'] = requestHeadersSafe;
      facade.debug.networkLogDedupedCount++;
      final typedContent = <String, dynamic>{
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'durationMs': durationMs,
        'error': error,
      };
      if (category != null) {
        typedContent['category'] = category;
      }
      if (requestDataSafe != null) {
        typedContent['requestData'] = requestDataSafe;
      }
      if (responseBodyPreview != null) {
        typedContent['responseBodyPreview'] = responseBodyPreview;
      }
      _appendTypedDebugLog(
        type: _resolveNetworkDebugLogType(
          statusCode: statusCode,
          error: error,
          durationMs: durationMs,
        ),
        level: _networkDebugLevel(
          statusCode: statusCode,
          error: error,
          durationMs: durationMs,
        ),
        title: '$method ${statusCode ?? 'ERR'}',
        source: source,
        content: typedContent,
      );
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
    recentNetworkLogs.add(logEntry);
    final typedContent = <String, dynamic>{
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': durationMs,
      'error': error,
    };
    if (category != null) {
      typedContent['category'] = category;
    }
    if (requestDataSafe != null) {
      typedContent['requestData'] = requestDataSafe;
    }
    if (responseBodyPreview != null) {
      typedContent['responseBodyPreview'] = responseBodyPreview;
    }
    _appendTypedDebugLog(
      type: _resolveNetworkDebugLogType(
        statusCode: statusCode,
        error: error,
        durationMs: durationMs,
      ),
      level: _networkDebugLevel(
        statusCode: statusCode,
        error: error,
        durationMs: durationMs,
      ),
      title: '$method ${statusCode ?? 'ERR'}',
      source: source,
      content: typedContent,
    );
    if (recentNetworkLogs.length > _debugMaxNetworkLogsKept) {
      recentNetworkLogs.removeRange(
        0,
        recentNetworkLogs.length - _debugMaxNetworkLogsKept,
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

  bool _shouldKeepDetailedNetworkRequest({
    required int? statusCode,
    required String? error,
  }) {
    final normalizedError = (error ?? '').trim().toLowerCase();
    if (normalizedError.isNotEmpty && normalizedError != 'null') {
      return true;
    }
    if (statusCode != null && statusCode >= 400) {
      return true;
    }
    return false;
  }

  bool _shouldKeepDetailedNetworkResponse({
    required String source,
    required String? category,
    required String url,
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    if (_shouldKeepDetailedNetworkRequest(
      statusCode: statusCode,
      error: error,
    )) {
      return true;
    }

    final normalizedSource = source.toLowerCase();
    final normalizedCategory = (category ?? '').toLowerCase();
    final normalizedUrl = url.toLowerCase();

    if (normalizedCategory == 'image_download') {
      return false;
    }
    if (durationMs >= 4000) {
      return true;
    }
    if (normalizedSource.contains('login')) {
      return true;
    }
    if (normalizedUrl.contains('/login') ||
        normalizedUrl.contains('source://account.login') ||
        normalizedUrl.contains('signin') ||
        normalizedUrl.contains('auth')) {
      return true;
    }
    return false;
  }

  dynamic _compactNetworkHeaders(dynamic value) {
    if (value is! Map) {
      return _compactGenericLogValue(
        value,
        maxStringLength: 160,
        maxItems: _debugNetworkHeadersKeep,
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
    for (final entry in value.entries.take(_debugNetworkHeadersKeep)) {
      final key = entry.key.toString();
      final lower = key.toLowerCase();
      if (!allowed.contains(lower)) {
        continue;
      }
      if (lower == 'cookie' ||
          lower == 'authorization' ||
          lower == 'set-cookie') {
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
      maxStringLength: _debugReaderStringKeep,
      maxItems: 40,
      maxDepth: 4,
    );
    if (compacted is! Map) {
      return compacted;
    }

    final normalizedLevel = level.toLowerCase();
    final keepBaseKeys = <String>{
      'sessionId',
      'epId',
      'readerMode',
      'currentPage',
      'totalPages',
    };

    final keepEventKeys = <String>{
      'trigger',
      'pageIndex',
      'page',
      'fromPageIndex',
      'fromPage',
      'targetPageIndex',
      'targetPage',
      'targetImageIndex',
      'targetImage',
      'targetEpId',
      'targetChapterIndex',
      'targetChapterTitle',
      'setting',
      'value',
      'previousValue',
      'nextValue',
      'brightnessPercent',
      'error',
      'imageCount',
      'incomingImageCount',
      'hasInitialImages',
      'imageUrl',
      'savedPath',
      'enabled',
      'controlsVisible',
      'settingsLoaded',
      'providerCachesCleared',
      'hadCachedChapterDetails',
      'hasVisibleContext',
      'listHasClients',
      'reason',
      'offset',
      'attempt',
      'animate',
      'path',
      'syncPath',
      'notificationType',
      'overscroll',
      'velocity',
      'depth',
      'diagnosticSequence',
      'previousListPixels',
      'currentListPixels',
      'listDeltaPixels',
      'jumpedToTop',
      'largeJump',
      'resolvedPageIndex',
      'resolvedPage',
      'visibleImageIndices',
    };

    final keepVerboseKeys = <String>{
      'comicId',
      'chapterTitle',
      'chapterIndex',
      'doublePageMode',
      'currentPageIndex',
      'pageIndicatorIndex',
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
        normalizedLevel == 'warning' || normalizedLevel == 'error';

    final filtered = <String, dynamic>{};
    for (final entry in compacted.entries) {
      final key = entry.key.toString();
      if (keepBaseKeys.contains(key) ||
          keepEventKeys.contains(key) ||
          (shouldKeepVerbose && keepVerboseKeys.contains(key))) {
        filtered[key] = entry.value;
      }
    }

    if (filtered['nearbyRenderedItems'] is List && !shouldKeepVerbose) {
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
      return _toBodyPreview(value, keep: maxStringLength);
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
    return _toBodyPreview(value.toString(), keep: maxStringLength);
  }
}
