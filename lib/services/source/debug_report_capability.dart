part of '../hazuki_source_service.dart';

extension HazukiSourceServiceDebugReportCapability on HazukiSourceService {
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) async {
    final facade = this.facade;
    final normalizedType = _normalizeDebugReportType(type);
    final logs = _typedDebugReportLogsFor(normalizedType);
    final approxBytes = logs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
      'type': normalizedType,
      'statusText': facade.statusText,
      'sourceRuntimeState': facade.runtimeState.toDebugMap(),
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
      },
      'isLogged': facade.isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'logStats': {
        'type': normalizedType,
        'keptCount': logs.length,
        'approxBytes': approxBytes,
      },
      'logs': _copyLogsWithoutDedupKey(logs),
    };
  }

  String _normalizeDebugReportType(String type) {
    final normalized = type.trim().toLowerCase();
    return debugLogTypes.contains(normalized) ? normalized : debugLogTypeAction;
  }

  List<Map<String, dynamic>> _typedDebugReportLogsFor(String type) {
    return switch (_normalizeDebugReportType(type)) {
      debugLogTypeError => facade.debug.recentErrorLogs,
      debugLogTypeAction => facade.debug.recentActionLogs,
      debugLogTypeSystem => facade.debug.recentSystemLogs,
      debugLogTypePerformance => facade.debug.recentPerformanceLogs,
      _ => facade.debug.recentActionLogs,
    };
  }

  Future<Map<String, dynamic>> collectNetworkDebugInfo() async {
    final facade = this.facade;
    final recentNetworkLogs = facade.debug.recentNetworkLogs;
    final approxBytes = recentNetworkLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
      'statusText': facade.statusText,
      'sourceRuntimeState': facade.runtimeState.toDebugMap(),
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
      },
      'isLogged': facade.isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'networkLogStats': {
        'keptCount': recentNetworkLogs.length,
        'dedupedCount': facade.debug.networkLogDedupedCount,
        'approxBytes': approxBytes,
      },
      'lastLoginDebugInfo': facade.lastLoginDebugInfo,
      'lastSourceVersionDebugInfo': facade.lastSourceVersionDebugInfo,
      'recentNetworkLogs': _copyLogsWithoutDedupKey(recentNetworkLogs),
    };
  }

  Future<Map<String, dynamic>> collectApplicationDebugInfo() async {
    final facade = this.facade;
    final recentApplicationLogs = facade.debug.recentApplicationLogs;
    final approxBytes = recentApplicationLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
      'statusText': facade.statusText,
      'sourceRuntimeState': facade.runtimeState.toDebugMap(),
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
      },
      'isLogged': facade.isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'applicationLogStats': {
        'keptCount': recentApplicationLogs.length,
        'approxBytes': approxBytes,
      },
      'recentApplicationLogs': _copyLogsWithoutDedupKey(recentApplicationLogs),
    };
  }

  Future<Map<String, dynamic>> collectReaderDebugInfo() async {
    final facade = this.facade;
    final recentReaderLogs = facade.debug.recentReaderLogs;
    final approxBytes = recentReaderLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
      'statusText': facade.statusText,
      'sourceRuntimeState': facade.runtimeState.toDebugMap(),
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
      },
      'isLogged': facade.isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'readerLogStats': {
        'keptCount': recentReaderLogs.length,
        'approxBytes': approxBytes,
      },
      'recentReaderLogs': _copyLogsWithoutDedupKey(recentReaderLogs),
    };
  }
}
