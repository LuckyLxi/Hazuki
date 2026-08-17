import 'dart:convert';

import '../runtime/source_runtime_facade.dart';
import 'debug_log_compactor.dart';
import 'debug_log_internals.dart';

typedef DebugTypedLogAppender =
    void Function({
      required String type,
      required String level,
      required String title,
      required Object? content,
      required String source,
    });

/// Applies network-log sampling, detail retention, deduplication, and storage.
class DebugNetworkLogRecorder {
  const DebugNetworkLogRecorder({
    required HazukiSourceFacade facade,
    required DebugTypedLogAppender appendTypedLog,
    DebugLogCompactor compactor = const DebugLogCompactor(),
  }) : _facade = facade,
       _appendTypedLog = appendTypedLog,
       _compactor = compactor;

  final HazukiSourceFacade _facade;
  final DebugTypedLogAppender _appendTypedLog;
  final DebugLogCompactor _compactor;

  void append({
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
    if (!_facade.softwareLogCaptureEnabled) return;
    final recentNetworkLogs = _facade.debug.recentNetworkLogs;
    final endedAt = DateTime.now();
    final durationMs = endedAt.difference(startedAt).inMilliseconds;
    if (_shouldSkipStorage(
      category: category,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    )) {
      return;
    }
    final isImportant = _isImportantForStorage(
      source: source,
      category: category,
      url: url,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    );
    final keepRequestDetails = _shouldKeepDetailedRequest(
      statusCode: statusCode,
      error: error,
    );
    final keepResponseDetails = _shouldKeepDetailedResponse(
      source: source,
      category: category,
      url: url,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    );
    final requestHeadersSafe = keepRequestDetails
        ? _compactor.compactNetworkHeaders(jsonSafe(requestHeaders))
        : null;
    final requestDataSafe = keepRequestDetails
        ? _compactor.compactNetworkPayload(jsonSafe(requestData), keep: 420)
        : null;
    final responseHeadersSafe = keepResponseDetails
        ? _compactor.compactNetworkHeaders(jsonSafe(responseHeaders))
        : null;
    final responseBodyFull = keepResponseDetails
        ? toBodyFull(responseBody)
        : null;
    final responseBodyPreviewSource = keepResponseDetails
        ? responseBodyFull
        : toBodyPreview(
            toBodyFull(responseBody),
            keep: DebugLogConstants.networkPreviewKeep,
          );
    final responseBodyPreview = isImportant
        ? toBodyPreview(
            responseBodyPreviewSource,
            keep: DebugLogConstants.networkPreviewKeep,
          )
        : toBodyPreview(toBodyFull(responseBody), keep: 160);
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
      _facade.debug.networkLogDedupedCount++;
      _appendTypedEntry(
        method: method,
        url: url,
        statusCode: statusCode,
        error: error,
        durationMs: durationMs,
        source: source,
        category: category,
        requestData: requestDataSafe,
        responseBodyPreview: responseBodyPreview,
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
    if (category != null) logEntry['category'] = category;
    recentNetworkLogs.add(logEntry);
    _appendTypedEntry(
      method: method,
      url: url,
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
      source: source,
      category: category,
      requestData: requestDataSafe,
      responseBodyPreview: responseBodyPreview,
    );
    if (recentNetworkLogs.length > DebugLogConstants.maxNetworkLogsKept) {
      recentNetworkLogs.removeRange(
        0,
        recentNetworkLogs.length - DebugLogConstants.maxNetworkLogsKept,
      );
    }
  }

  void _appendTypedEntry({
    required String method,
    required String url,
    required int? statusCode,
    required String? error,
    required int durationMs,
    required String source,
    required String? category,
    required dynamic requestData,
    required String? responseBodyPreview,
  }) {
    final content = <String, dynamic>{
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': durationMs,
      'error': error,
    };
    if (category != null) content['category'] = category;
    if (requestData != null) content['requestData'] = requestData;
    if (responseBodyPreview != null) {
      content['responseBodyPreview'] = responseBodyPreview;
    }
    _appendTypedLog(
      type: _resolveDebugLogType(
        statusCode: statusCode,
        error: error,
        durationMs: durationMs,
      ),
      level: _debugLevel(
        statusCode: statusCode,
        error: error,
        durationMs: durationMs,
      ),
      title: '$method ${statusCode ?? 'ERR'}',
      source: source,
      content: content,
    );
  }

  String _resolveDebugLogType({
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedError = (error ?? '').trim().toLowerCase();
    if ((normalizedError.isNotEmpty && normalizedError != 'null') ||
        (statusCode != null && statusCode >= 400)) {
      return debugLogTypeError;
    }
    if (durationMs >= 2500) return debugLogTypePerformance;
    return debugLogTypeSystem;
  }

  String _debugLevel({
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedError = (error ?? '').trim().toLowerCase();
    if (normalizedError.isNotEmpty && normalizedError != 'null') return 'error';
    if (statusCode != null && statusCode >= 400) return 'error';
    if ((statusCode != null && statusCode >= 300) || durationMs >= 2500) {
      return 'warn';
    }
    return 'info';
  }

  bool _shouldSkipStorage({
    required String? category,
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final normalizedCategory = (category ?? '').toLowerCase();
    final normalizedError = (error ?? '').trim().toLowerCase();
    final hasError = normalizedError.isNotEmpty && normalizedError != 'null';
    if (hasError || (statusCode != null && statusCode >= 400)) return false;
    if (durationMs >= 2500) return false;
    return normalizedCategory == 'image_download';
  }

  bool _isImportantForStorage({
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
    if ((normalizedError.isNotEmpty && normalizedError != 'null') ||
        (statusCode != null && statusCode >= 400) ||
        durationMs >= 2500) {
      return true;
    }
    if (normalizedCategory == 'image_download') return false;
    if (normalizedSource.contains('login') ||
        normalizedSource.contains('avatar') ||
        normalizedSource.contains('source_version')) {
      return true;
    }
    return normalizedUrl.contains('/login') ||
        normalizedUrl.contains('/favorite') ||
        normalizedUrl.contains('/user') ||
        normalizedUrl.contains('/daily') ||
        normalizedUrl.contains('/daily_chk') ||
        normalizedUrl.contains('index.json') ||
        normalizedUrl.contains('/jm.js');
  }

  bool _shouldKeepDetailedRequest({
    required int? statusCode,
    required String? error,
  }) {
    final normalizedError = (error ?? '').trim().toLowerCase();
    return (normalizedError.isNotEmpty && normalizedError != 'null') ||
        (statusCode != null && statusCode >= 400);
  }

  bool _shouldKeepDetailedResponse({
    required String source,
    required String? category,
    required String url,
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    if (_shouldKeepDetailedRequest(statusCode: statusCode, error: error)) {
      return true;
    }
    final normalizedSource = source.toLowerCase();
    final normalizedCategory = (category ?? '').toLowerCase();
    final normalizedUrl = url.toLowerCase();
    if (normalizedCategory == 'image_download') return false;
    if (durationMs >= 4000 || normalizedSource.contains('login')) return true;
    return normalizedUrl.contains('/login') ||
        normalizedUrl.contains('source://account.login') ||
        normalizedUrl.contains('signin') ||
        normalizedUrl.contains('auth');
  }
}
