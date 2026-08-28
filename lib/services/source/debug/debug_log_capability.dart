import '../../logging/app_log_store.dart';
import 'debug_network_log_recorder.dart';
import 'debug_structured_log_recorder.dart';

/// Public facade for structured and network debug-log recorders.
class DebugLogCapability {
  DebugLogCapability(this.store);

  final AppLogStore store;

  late final DebugStructuredLogRecorder _structured =
      DebugStructuredLogRecorder(store);
  late final DebugNetworkLogRecorder _network = DebugNetworkLogRecorder(store);

  void addDebugLog({
    required String type,
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _structured.addTyped(
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
  }) => _structured.addApplication(
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
  }) => _structured.addReader(
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
  }) => _network.append(
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
}
