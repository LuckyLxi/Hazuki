import '../../logging/app_log_event.dart';
import '../../logging/app_log_store.dart';

/// Converts HTTP diagnostics into the application's unified event stream.
class DebugNetworkLogRecorder {
  const DebugNetworkLogRecorder(this.store);

  final AppLogStore store;

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
    final endedAt = DateTime.now();
    final durationMs = endedAt.difference(startedAt).inMilliseconds;
    if (_isSuccessfulImageDownload(
      category: category,
      statusCode: statusCode,
      error: error,
    )) {
      return;
    }
    final level = _level(
      statusCode: statusCode,
      error: error,
      durationMs: durationMs,
    );
    final data = <String, dynamic>{
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': durationMs,
    };
    if (category != null) data['category'] = category;
    if (requestHeaders != null) data['requestHeaders'] = requestHeaders;
    if (requestData != null) {
      data['requestData'] = _networkValue(requestData);
    }
    if (responseHeaders != null) data['responseHeaders'] = responseHeaders;
    if (responseBody != null) {
      data['responseBody'] = _networkValue(responseBody);
    }
    if (error != null && error.trim().isNotEmpty) data['error'] = error;
    store.add(
      level: level,
      area: AppLogArea.network,
      source: source,
      event: 'network_request',
      title: '$method ${statusCode ?? 'ERR'}',
      data: data,
      tags: durationMs >= 2500
          ? const <String>['performance']
          : const <String>[],
      time: endedAt,
    );
  }

  String _level({
    required int? statusCode,
    required String? error,
    required int durationMs,
  }) {
    final hasError =
        error != null &&
        error.trim().isNotEmpty &&
        error.trim().toLowerCase() != 'null';
    if (hasError || (statusCode != null && statusCode >= 400)) return 'error';
    if ((statusCode != null && statusCode >= 300) || durationMs >= 2500) {
      return 'warning';
    }
    return 'info';
  }

  bool _isSuccessfulImageDownload({
    required String? category,
    required int? statusCode,
    required String? error,
  }) {
    final hasError =
        error != null &&
        error.trim().isNotEmpty &&
        error.trim().toLowerCase() != 'null';
    return category?.toLowerCase() == 'image_download' &&
        !hasError &&
        (statusCode == null || statusCode < 400);
  }

  Object _networkValue(Object value) {
    if (value is List<int>) {
      return <String, dynamic>{'binaryType': 'bytes', 'length': value.length};
    }
    return value;
  }
}
