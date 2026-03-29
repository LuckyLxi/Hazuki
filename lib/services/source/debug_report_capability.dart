part of '../hazuki_source_service.dart';

extension HazukiSourceServiceDebugReportCapability on HazukiSourceService {
  Future<Map<String, dynamic>> collectNetworkDebugInfo() async {
    final approxBytes = _recentNetworkLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
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
      'recentNetworkLogs': _copyLogsWithoutDedupKey(_recentNetworkLogs),
    };
  }

  Future<Map<String, dynamic>> collectApplicationDebugInfo() async {
    final approxBytes = _recentApplicationLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
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
      'recentApplicationLogs': _copyLogsWithoutDedupKey(_recentApplicationLogs),
    };
  }

  Future<Map<String, dynamic>> collectReaderDebugInfo() async {
    final approxBytes = _recentReaderLogs.fold<int>(
      0,
      (sum, item) => sum + _estimatePayloadBytes(item),
    );
    return <String, dynamic>{
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
      'recentReaderLogs': _copyLogsWithoutDedupKey(_recentReaderLogs),
    };
  }
}
