import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class NetworkLogsFormatter {
  const NetworkLogsFormatter(this.context);

  final BuildContext context;

  String buildPrettyText({
    required Map<String, dynamic> source,
    required bool importantOnly,
  }) {
    final viewData = buildMap(
      source: source,
      importantOnly: importantOnly,
      includeFullBody: false,
    );
    return const JsonEncoder.withIndent('  ').convert(viewData);
  }

  String buildCopyText({
    required Map<String, dynamic> source,
    required bool importantOnly,
  }) {
    final copyData = buildMap(
      source: source,
      importantOnly: importantOnly,
      includeFullBody: true,
      compactFullBodyForUnimportant: true,
      includeHeaders: true,
    );
    return const JsonEncoder.withIndent('  ').convert(copyData);
  }

  String buildExportText({required Map<String, dynamic> source}) {
    final exportData = buildMap(
      source: source,
      importantOnly: false,
      includeFullBody: true,
      compactFullBodyForUnimportant: true,
    );
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Map<String, dynamic> buildMap({
    required Map<String, dynamic> source,
    required bool importantOnly,
    required bool includeFullBody,
    bool compactFullBodyForUnimportant = false,
    bool includeHeaders = false,
  }) {
    final logs = _readLogs(source);
    final importantLogs = logs.where(_isImportantLog).toList();
    final targetLogs = importantOnly
        ? importantLogs
        : _limitUnimportantLogs(logs);
    final normalizedLogs = targetLogs
        .map(
          (log) => _normalizeLog(
            log: log,
            includeFullBody: includeFullBody,
            compactFullBodyForUnimportant: compactFullBodyForUnimportant,
            includeHeaders: includeHeaders,
          ),
        )
        .toList();

    final baseStats = source['networkLogStats'] is Map
        ? Map<String, dynamic>.from(
            (source['networkLogStats'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
        : <String, dynamic>{};

    final result = <String, dynamic>{
      'generatedAt': source['generatedAt'],
      'statusText': source['statusText'],
      'platform': source['platform'],
      'sourceMeta': _normalizePayload(
        source['sourceMeta'],
        compactStrings: false,
      ),
      'isLogged': source['isLogged'],
      if (_hasMeaningfulValue(source['lastLoginDebugInfo']))
        'lastLoginDebugInfo': _normalizePayload(
          source['lastLoginDebugInfo'],
          compactStrings: !includeFullBody,
        ),
      if (_hasMeaningfulValue(source['lastSourceVersionDebugInfo']))
        'lastSourceVersionDebugInfo': _normalizePayload(
          source['lastSourceVersionDebugInfo'],
          compactStrings: !includeFullBody,
        ),
      if (importantOnly) 'filterMode': 'important_only',
      if (importantOnly)
        'filterReason': l10n(context).favoritesDebugFilterReason,
      'networkLogStats': {
        ..._pruneMap(baseStats),
        'visibleCount': normalizedLogs.length,
        'totalCountBeforeFilter': logs.length,
        'importantCount': importantLogs.length,
        'noiseDroppedCount': logs.length - targetLogs.length,
      },
      'recentNetworkLogs': normalizedLogs,
    };
    return _pruneMap(result);
  }

  List<Map<String, dynamic>> _readLogs(Map<String, dynamic> source) {
    return source['recentNetworkLogs'] is List
        ? List<Map<String, dynamic>>.from(
            (source['recentNetworkLogs'] as List).whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ),
          )
        : <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeLog({
    required Map<String, dynamic> log,
    required bool includeFullBody,
    required bool compactFullBodyForUnimportant,
    required bool includeHeaders,
  }) {
    final isImportant = _isImportantLog(log);
    final mergedCount = log['mergedCount'] is num
        ? (log['mergedCount'] as num).toInt()
        : 1;
    final result = <String, dynamic>{
      'time': log['time'],
      if (mergedCount > 1) 'lastSeenAt': log['lastSeenAt'],
      if (mergedCount > 1) 'mergedCount': mergedCount,
      'source': log['source'],
      'method': log['method'],
      'statusCode': log['statusCode'],
      'durationMs': log['durationMs'],
      'url': log['url'],
      if (_hasMeaningfulValue(log['error'])) 'error': log['error'],
      if (isImportant && _hasMeaningfulValue(log['requestData']))
        'requestData': _normalizePayload(
          log['requestData'],
          compactStrings: !includeFullBody,
        ),
      if (isImportant &&
          includeHeaders &&
          _hasMeaningfulValue(log['requestHeaders']))
        'requestHeaders': _normalizePayload(
          log['requestHeaders'],
          compactStrings: false,
        ),
      if (isImportant &&
          includeHeaders &&
          _hasMeaningfulValue(log['responseHeaders']))
        'responseHeaders': _normalizePayload(
          log['responseHeaders'],
          compactStrings: false,
        ),
      if (_hasMeaningfulValue(log['responseBodyPreview']))
        'responseBodyPreview': _toCompactBody(
          log['responseBodyPreview'],
          keep: isImportant ? 320 : 160,
        ),
      if (includeFullBody && _hasMeaningfulValue(log['responseBodyFull']))
        'responseBodyFull': compactFullBodyForUnimportant && !isImportant
            ? _toCompactBody(log['responseBodyFull'], keep: 320)
            : _normalizePayload(log['responseBodyFull'], compactStrings: false),
    };
    return _pruneMap(result);
  }

  dynamic _normalizePayload(dynamic value, {required bool compactStrings}) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return compactStrings ? _toCompactBody(value) : value;
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final normalized = _normalizePayload(
          entry.value,
          compactStrings: compactStrings,
        );
        if (_hasMeaningfulValue(normalized)) {
          result[entry.key.toString()] = normalized;
        }
      }
      return result;
    }
    if (value is Iterable) {
      final items = value
          .map(
            (item) => _normalizePayload(item, compactStrings: compactStrings),
          )
          .where(_hasMeaningfulValue)
          .toList();
      return items;
    }
    return value;
  }

  Map<String, dynamic> _pruneMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final pruned = _pruneValue(entry.value);
      if (_hasMeaningfulValue(pruned)) {
        result[entry.key] = pruned;
      }
    }
    return result;
  }

  dynamic _pruneValue(dynamic value) {
    if (value is Map) {
      return _pruneMap(
        Map<String, dynamic>.from(
          value.map((key, nested) => MapEntry(key.toString(), nested)),
        ),
      );
    }
    if (value is Iterable) {
      final items = value.map(_pruneValue).where(_hasMeaningfulValue).toList();
      return items;
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text.toLowerCase() == 'null') {
        return null;
      }
      return value;
    }
    return value;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      final text = value.trim();
      return text.isNotEmpty && text.toLowerCase() != 'null';
    }
    if (value is Map) {
      return value.isNotEmpty;
    }
    if (value is Iterable) {
      return value.isNotEmpty;
    }
    return true;
  }

  List<Map<String, dynamic>> _limitUnimportantLogs(
    List<Map<String, dynamic>> logs,
  ) {
    const maxUnimportantLogs = 8;
    final importantLogs = <Map<String, dynamic>>[];
    final unimportantLogs = <Map<String, dynamic>>[];

    for (final log in logs) {
      if (_isImportantLog(log)) {
        importantLogs.add(log);
      } else {
        unimportantLogs.add(log);
      }
    }

    if (unimportantLogs.length <= maxUnimportantLogs) {
      return [...importantLogs, ...unimportantLogs];
    }

    final recentUnimportant = unimportantLogs
        .skip(unimportantLogs.length - maxUnimportantLogs)
        .toList();
    return [...importantLogs, ...recentUnimportant];
  }

  String _toCompactBody(dynamic body, {int keep = 240}) {
    if (body == null) {
      return 'null';
    }
    final text = body.toString();
    if (text.length <= keep) {
      return text;
    }
    final omitted = text.length - keep;
    return '${text.substring(0, keep)}... [omitted $omitted chars]';
  }

  bool _isImportantLog(Map<String, dynamic> log) {
    final statusCode = log['statusCode'] is num
        ? (log['statusCode'] as num).toInt()
        : null;
    final method = (log['method'] ?? '').toString().toUpperCase();
    final source = (log['source'] ?? '').toString().toLowerCase();
    final url = (log['url'] ?? '').toString().toLowerCase();
    final error = (log['error'] ?? '').toString().toLowerCase();
    final responsePreview = (log['responseBodyPreview'] ?? '')
        .toString()
        .toLowerCase();
    final responseFull = (log['responseBodyFull'] ?? '')
        .toString()
        .toLowerCase();

    final hasError = error.isNotEmpty && error != 'null';
    if (hasError) {
      return true;
    }

    final isSlowRequest =
        log['durationMs'] is num && (log['durationMs'] as num).toInt() >= 2500;
    if (isSlowRequest) {
      return true;
    }

    if (statusCode != null && statusCode >= 400) {
      return true;
    }

    final authChainRelated =
        source.contains('login') ||
        source.contains('avatar') ||
        source.contains('source_version') ||
        method == 'LOGIN' ||
        url.contains('/login') ||
        url.contains('/user') ||
        url.contains('/favorite') ||
        url.contains('index.json') ||
        url.contains('/jm.js') ||
        url.contains('/daily') ||
        url.contains('/daily_chk') ||
        url.contains('source://avatar') ||
        url.contains('source://account.login') ||
        url.contains('signin') ||
        url.contains('auth');
    if (authChainRelated) {
      return true;
    }

    const keywords = [
      'error',
      'failed',
      'exception',
      'timeout',
      'unauthorized',
      'forbidden',
      'denied',
      'invalid',
      'login expired',
      'not legal.user',
      'auth_fail',
      'uid',
      'photo',
      '401',
      '403',
      '500',
      '502',
      '503',
      '504',
    ];

    final combined = '$error\n$responsePreview\n$responseFull';
    return keywords.any(combined.contains);
  }
}
