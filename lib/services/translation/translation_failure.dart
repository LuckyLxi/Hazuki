import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

enum TranslationFailureKind {
  cancelled,
  unauthorized,
  quotaExceeded,
  rateLimited,
  network,
  badResponse,
  server,
  unknown,
}

class TranslationFailure implements Exception {
  const TranslationFailure(this.kind, {this.retryAfter});

  final TranslationFailureKind kind;
  final Duration? retryAfter;

  factory TranslationFailure.from(Object error) {
    if (error is DioException && CancelToken.isCancel(error)) {
      return const TranslationFailure(TranslationFailureKind.cancelled);
    }
    if (error is TranslationFailure) return error;
    if (error is FormatException || error is TypeError) {
      return const TranslationFailure(TranslationFailureKind.badResponse);
    }
    if (error is! DioException) {
      return const TranslationFailure(TranslationFailureKind.unknown);
    }
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return const TranslationFailure(TranslationFailureKind.unauthorized);
    }
    if (status == 402 || (status == 429 && _isQuota(error.response?.data))) {
      return const TranslationFailure(TranslationFailureKind.quotaExceeded);
    }
    if (status == 429) {
      return TranslationFailure(
        TranslationFailureKind.rateLimited,
        retryAfter: _retryAfter(error.response?.headers.value('retry-after')),
      );
    }
    if (status != null && status >= 500 && status < 600) {
      return const TranslationFailure(TranslationFailureKind.server);
    }
    if (switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    }) {
      return const TranslationFailure(TranslationFailureKind.network);
    }
    if (error.error is FormatException ||
        error.type == DioExceptionType.badResponse &&
            status != null &&
            status >= 200 &&
            status < 300) {
      return const TranslationFailure(TranslationFailureKind.badResponse);
    }
    return const TranslationFailure(TranslationFailureKind.unknown);
  }

  static bool _isQuota(dynamic data) {
    final text = (data is String ? data : jsonEncode(data)).toLowerCase();
    return text.contains('quota') ||
        text.contains('insufficient') ||
        text.contains('billing');
  }

  static Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      final delay = HttpDate.parse(value).difference(DateTime.now().toUtc());
      return delay.isNegative ? Duration.zero : delay;
    } on HttpException {
      return null;
    }
  }

  // 不保留底层异常文本，避免请求头或图片数据被日志输出。
  @override
  String toString() => 'TranslationFailure(${kind.name})';
}
