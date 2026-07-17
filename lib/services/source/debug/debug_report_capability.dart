import 'dart:io';

import '../debug/debug_log_internals.dart';
import '../runtime/source_runtime_facade.dart';

class SourceDebugReportCapability {
  SourceDebugReportCapability({
    required HazukiSourceFacade Function() activeFacade,
    required String? Function() currentAccount,
  }) : _activeFacade = activeFacade,
       _currentAccount = currentAccount;

  final HazukiSourceFacade Function() _activeFacade;
  final String? Function() _currentAccount;

  HazukiSourceFacade get _facade => _activeFacade();

  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) async {
    final facade = _facade;
    final normalizedType = _normalizeDebugReportType(type);
    final logs = _typedDebugReportLogsFor(normalizedType);
    final approxBytes = logs.fold<int>(
      0,
      (sum, item) => sum + estimatePayloadBytes(item),
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
      'currentAccount': _currentAccount(),
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'logStats': {
        'type': normalizedType,
        'keptCount': logs.length,
        'approxBytes': approxBytes,
      },
      'logs': copyLogsWithoutDedupKey(logs),
    };
  }

  String _normalizeDebugReportType(String type) {
    final normalized = type.trim().toLowerCase();
    return debugLogTypes.contains(normalized) ? normalized : debugLogTypeAction;
  }

  List<Map<String, dynamic>> _typedDebugReportLogsFor(String type) {
    return switch (_normalizeDebugReportType(type)) {
      debugLogTypeError => _facade.debug.recentErrorLogs,
      debugLogTypeAction => _facade.debug.recentActionLogs,
      debugLogTypeSystem => _facade.debug.recentSystemLogs,
      debugLogTypePerformance => _facade.debug.recentPerformanceLogs,
      _ => _facade.debug.recentActionLogs,
    };
  }

  Future<Map<String, dynamic>> collectNetworkDebugInfo() async {
    final facade = _facade;
    final recentNetworkLogs = facade.debug.recentNetworkLogs;
    final approxBytes = recentNetworkLogs.fold<int>(
      0,
      (sum, item) => sum + estimatePayloadBytes(item),
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
      'currentAccount': _currentAccount(),
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'networkLogStats': {
        'keptCount': recentNetworkLogs.length,
        'dedupedCount': facade.debug.networkLogDedupedCount,
        'approxBytes': approxBytes,
      },
      'lastLoginDebugInfo': facade.lastLoginDebugInfo,
      'lastSourceVersionDebugInfo': facade.lastSourceVersionDebugInfo,
      'recentNetworkLogs': copyLogsWithoutDedupKey(recentNetworkLogs),
    };
  }

  Future<Map<String, dynamic>> collectApplicationDebugInfo() async {
    final facade = _facade;
    final recentApplicationLogs = facade.debug.recentApplicationLogs;
    final approxBytes = recentApplicationLogs.fold<int>(
      0,
      (sum, item) => sum + estimatePayloadBytes(item),
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
      'currentAccount': _currentAccount(),
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'applicationLogStats': {
        'keptCount': recentApplicationLogs.length,
        'approxBytes': approxBytes,
      },
      'recentApplicationLogs': copyLogsWithoutDedupKey(recentApplicationLogs),
    };
  }

  Future<Map<String, dynamic>> collectReaderDebugInfo() async {
    final facade = _facade;
    final recentReaderLogs = facade.debug.recentReaderLogs;
    final approxBytes = recentReaderLogs.fold<int>(
      0,
      (sum, item) => sum + estimatePayloadBytes(item),
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
      'currentAccount': _currentAccount(),
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': facade.softwareLogCaptureEnabled,
      'readerLogStats': {
        'keptCount': recentReaderLogs.length,
        'approxBytes': approxBytes,
      },
      'recentReaderLogs': copyLogsWithoutDedupKey(recentReaderLogs),
    };
  }
}
