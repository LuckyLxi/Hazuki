import '../../hazuki_source_service.dart';

class SourceNetworkLogSink {
  SourceNetworkLogSink(this._service);

  final HazukiSourceService _service;

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
    _service.appendNetworkLogEntry(
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
}
