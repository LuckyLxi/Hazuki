typedef SourceNetworkLogAppender =
    void Function({
      required String method,
      required String url,
      required int? statusCode,
      required String? error,
      required DateTime startedAt,
      String source,
      String? category,
      Map<String, dynamic>? requestHeaders,
      Object? requestData,
      Map<String, dynamic>? responseHeaders,
      Object? responseBody,
    });

class SourceNetworkLogSink {
  const SourceNetworkLogSink(this._append);

  final SourceNetworkLogAppender _append;

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
  }) => _append(
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
