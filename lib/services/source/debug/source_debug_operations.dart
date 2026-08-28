import 'debug_log_capability.dart';
import 'debug_report_capability.dart';
import '../../logging/app_log_store.dart';
import '../runtime/source_runtime_facade.dart';

/// Log capture and diagnostic-report operations for the active source runtime.
class SourceDebugOperations {
  const SourceDebugOperations({
    required DebugLogCapability Function() activeDebugLog,
    required HazukiSourceFacade Function() activeFacade,
    required SourceDebugReportCapability debugReport,
    required AppLogStore logStore,
  }) : _activeDebugLog = activeDebugLog,
       _activeFacade = activeFacade,
       _debugReport = debugReport,
       _logStore = logStore;

  final DebugLogCapability Function() _activeDebugLog;
  final HazukiSourceFacade Function() _activeFacade;
  final SourceDebugReportCapability _debugReport;
  final AppLogStore _logStore;

  DebugLogCapability get _debugLog => _activeDebugLog();

  bool get softwareLogCaptureEnabled => _logStore.captureEnabled;

  AppLogStore get logStore => _logStore;

  void addDebugLog({
    required String type,
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _debugLog.addDebugLog(
    type: type,
    level: level,
    title: title,
    content: content,
    source: source,
  );

  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _debugLog.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );

  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => _debugLog.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );

  void appendNetworkLogEntry({
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
  }) => _debugLog.appendNetworkLogEntry(
    method: method,
    url: url,
    statusCode: statusCode,
    error: error,
    startedAt: startedAt,
    source: source,
    category: category,
    requestHeaders: requestHeaders,
    requestData: requestData,
    responseHeaders: responseHeaders,
    responseBody: responseBody,
  );

  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      _debugReport.collectTypedDebugInfo(type);

  Future<Map<String, dynamic>> collectAllDebugInfo() =>
      _debugReport.collectAllDebugInfo();

  Future<Map<String, dynamic>> collectNetworkDebugInfo() =>
      _debugReport.collectNetworkDebugInfo();

  Future<Map<String, dynamic>> collectApplicationDebugInfo() =>
      _debugReport.collectApplicationDebugInfo();

  Future<Map<String, dynamic>> collectReaderDebugInfo() =>
      _debugReport.collectReaderDebugInfo();

  Future<void> clearCapturedLogs() async {
    await _logStore.clear();
    _activeFacade().clearCapturedLogs();
  }
}
