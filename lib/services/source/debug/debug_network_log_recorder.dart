import 'dart:convert';

import '../../logging/app_log_event.dart';
import '../../logging/app_log_store.dart';

/// Converts HTTP diagnostics into the application's unified event stream.
class DebugNetworkLogRecorder {
  const DebugNetworkLogRecorder(this.store);

  /// 成功请求的响应体只保留开头片段，足以判断返回格式。
  static const int _successBodyPreviewLength = 300;

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
    Map<String, Object?>? taskContext,
    bool cancelled = false,
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
      cancelled: cancelled,
    );
    // 成功与取消的请求只保留摘要；完整请求头、响应头与响应体仅在失败时记录。
    final detailed = level == 'warning' || level == 'error';
    final data = <String, dynamic>{
      'task': ?taskContext,
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': durationMs,
    };
    if (category != null) data['category'] = category;
    if (cancelled) data['cancelled'] = true;
    if (detailed && requestHeaders != null) {
      data['requestHeaders'] = requestHeaders;
    }
    if (requestData != null) {
      data['requestData'] = _networkValue(requestData);
    }
    if (detailed && responseHeaders != null) {
      data['responseHeaders'] = responseHeaders;
    }
    if (responseBody != null) {
      if (detailed) {
        data['responseBody'] = _networkValue(responseBody);
      } else {
        data['responseBodyPreview'] = _bodyPreview(responseBody);
      }
    }
    if (error != null && error.trim().isNotEmpty) data['error'] = error;
    store.add(
      level: level,
      area: AppLogArea.network,
      source: source,
      event: cancelled ? 'network_request_cancelled' : 'network_request',
      title: '$method ${cancelled ? 'CANCELLED' : statusCode ?? 'ERR'}',
      data: data,
      tags: durationMs >= 2500
          ? const <String>['performance']
          : const <String>[],
      time: endedAt,
    );
  }

  /// 取消属于正常的页面生命周期；4xx 多为来源业务响应（未登录、资源不存在），
  /// 由上层任务决定是否算失败；只有 5xx 与传输层错误记为 error。
  /// 慢请求与重定向仅保留 performance 标签，不再提升级别。
  String _level({
    required int? statusCode,
    required String? error,
    required bool cancelled,
  }) {
    if (cancelled) return 'debug';
    final hasError =
        error != null &&
        error.trim().isNotEmpty &&
        error.trim().toLowerCase() != 'null';
    if (statusCode != null && statusCode >= 500) return 'error';
    if (statusCode != null && statusCode >= 400) return 'warning';
    if (hasError) return 'error';
    return 'info';
  }

  Object _bodyPreview(Object value) {
    if (value is List<int>) return _networkValue(value);
    String text;
    try {
      text = value is String ? value : jsonEncode(value);
    } catch (_) {
      text = value.toString();
    }
    return truncateLogText(text, _successBodyPreviewLength);
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
