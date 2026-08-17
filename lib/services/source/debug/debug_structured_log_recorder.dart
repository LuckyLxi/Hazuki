import '../runtime/source_runtime_facade.dart';
import 'debug_log_compactor.dart';
import 'debug_log_internals.dart';

class DebugStructuredLogRecorder {
  DebugStructuredLogRecorder(this.facade);

  final HazukiSourceFacade facade;
  static const _compactor = DebugLogCompactor();
  void addTyped({
    required String type,
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {
    if (!facade.softwareLogCaptureEnabled) {
      return;
    }
    appendTyped(
      type: _normalizeDebugLogType(type),
      level: level,
      title: title,
      content: jsonSafe(content),
      source: source,
    );
  }

  void addApplication({
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
    appendTyped(
      type: _resolveGenericDebugLogType(
        level: level,
        title: title,
        content: content,
        source: source,
      ),
      level: level,
      title: title,
      content: jsonSafe(content),
      source: source,
    );
  }

  void addReader({
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
    appendTyped(
      type: _resolveGenericDebugLogType(
        level: level,
        title: title,
        content: content,
        source: source,
      ),
      level: level,
      title: title,
      content: jsonSafe(content),
      source: source,
    );
  }

  void _pruneByAgeIfNeeded() {
    final now = DateTime.now();
    if (facade.debug.lastAgeCleanupAt != null &&
        now.difference(facade.debug.lastAgeCleanupAt!) <
            const Duration(hours: 1)) {
      return;
    }
    facade.debug.lastAgeCleanupAt = now;
    final cutoff = now.subtract(DebugLogConstants.maxAge);
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

  void appendTyped({
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
    final fullContent = jsonSafe(content);
    final safeContent = _compactor.compactGenericLogValue(
      fullContent,
      maxStringLength: DebugLogConstants.applicationStringKeep,
      maxItems: 24,
      maxDepth: 4,
    );
    final fullContentText = toBodyFull(fullContent) ?? 'null';
    final contentText = toBodyFull(safeContent) ?? 'null';
    final dedupKey = [
      normalizedType,
      sourceText,
      normalizedLevel,
      titleText,
      fullContentText,
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
      existing['contentFull'] = fullContent;
      existing['contentPreview'] = toBodyPreview(contentText, keep: 320);
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
      'contentFull': fullContent,
      'contentPreview': toBodyPreview(contentText, keep: 320),
    });
    if (targetLogs.length > DebugLogConstants.maxTypedLogsKept) {
      targetLogs.removeRange(
        0,
        targetLogs.length - DebugLogConstants.maxTypedLogsKept,
      );
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
    final contentText = (toBodyFull(jsonSafe(content)) ?? '').toLowerCase();
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
    final fullContent = jsonSafe(content);
    final safeContent = _compactor.compactReaderLogContent(
      fullContent,
      source: source,
      level: normalizedLevel,
    );
    final fullContentText = toBodyFull(fullContent) ?? 'null';
    final contentText = toBodyFull(safeContent) ?? 'null';
    final dedupKey = [
      source,
      normalizedLevel.toLowerCase(),
      titleText,
      fullContentText,
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
      existing['contentFull'] = fullContent;
      existing['contentPreview'] = toBodyPreview(contentText);
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
      'contentFull': fullContent,
      'contentPreview': toBodyPreview(contentText),
    });
    if (recentReaderLogs.length > DebugLogConstants.maxReaderLogsKept) {
      recentReaderLogs.removeRange(
        0,
        recentReaderLogs.length - DebugLogConstants.maxReaderLogsKept,
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
    final fullContent = jsonSafe(content);
    final safeContent = _compactor.compactGenericLogValue(
      fullContent,
      maxStringLength: DebugLogConstants.applicationStringKeep,
      maxItems: 20,
      maxDepth: 4,
    );
    final fullContentText = toBodyFull(fullContent) ?? 'null';
    final contentText = toBodyFull(safeContent) ?? 'null';
    final dedupKey = [
      source,
      normalizedLevel.toLowerCase(),
      titleText,
      fullContentText,
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
      existing['contentFull'] = fullContent;
      existing['contentPreview'] = toBodyPreview(contentText);
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
      'contentFull': fullContent,
      'contentPreview': toBodyPreview(contentText),
    });
    if (recentApplicationLogs.length >
        DebugLogConstants.maxApplicationLogsKept) {
      recentApplicationLogs.removeRange(
        0,
        recentApplicationLogs.length - DebugLogConstants.maxApplicationLogsKept,
      );
    }
  }
}
