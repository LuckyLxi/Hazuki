part of '../hazuki_source_service.dart';

extension HazukiSourceServiceDebugReportCapability on HazukiSourceService {
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
