import 'dart:io';

import 'package:dio/dio.dart';

enum HazukiNetworkFailureKind {
  connection,
  timeout,
  transientStatus,
  canceled,
  badResponse,
  unknown,
}

HazukiNetworkFailureKind classifyHazukiNetworkFailure(Object error) {
  if (error is SocketException) {
    return HazukiNetworkFailureKind.connection;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return HazukiNetworkFailureKind.connection;
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.transformTimeout: // 数据转换超时，归类为超时错误
        return HazukiNetworkFailureKind.timeout;
      case DioExceptionType.cancel:
        return HazukiNetworkFailureKind.canceled;
      case DioExceptionType.badResponse:
        return _isTransientStatus(error.response?.statusCode)
            ? HazukiNetworkFailureKind.transientStatus
            : HazukiNetworkFailureKind.badResponse;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return HazukiNetworkFailureKind.connection;
        }
        final message = error.message?.toLowerCase() ?? '';
        if (message.contains('failed host lookup') ||
            message.contains('connection error') ||
            message.contains('connection refused') ||
            message.contains('network is unreachable')) {
          return HazukiNetworkFailureKind.connection;
        }
        if (message.contains('timeout')) {
          return HazukiNetworkFailureKind.timeout;
        }
        return HazukiNetworkFailureKind.unknown;
    }
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection error') ||
      text.contains('connection refused') ||
      text.contains('network is unreachable')) {
    return HazukiNetworkFailureKind.connection;
  }
  if (text.contains('timeout')) {
    return HazukiNetworkFailureKind.timeout;
  }
  return HazukiNetworkFailureKind.unknown;
}

bool isHazukiTransientNetworkFailure(Object error) {
  return switch (classifyHazukiNetworkFailure(error)) {
    HazukiNetworkFailureKind.connection ||
    HazukiNetworkFailureKind.timeout ||
    HazukiNetworkFailureKind.transientStatus => true,
    HazukiNetworkFailureKind.canceled ||
    HazukiNetworkFailureKind.badResponse ||
    HazukiNetworkFailureKind.unknown => false,
  };
}

bool isHazukiTransientStatusCode(int? statusCode) {
  return _isTransientStatus(statusCode);
}

bool isHazukiSafeNetworkMethod(String method) {
  final normalized = method.trim().toUpperCase();
  return normalized == 'GET' || normalized == 'HEAD';
}

bool shouldRetryHazukiNetworkRequest({
  required String method,
  required Object error,
  required int attempt,
  required int maxAttempts,
  bool allowUnsafeRetry = false,
}) {
  if (attempt >= maxAttempts) {
    return false;
  }
  if (!allowUnsafeRetry && !isHazukiSafeNetworkMethod(method)) {
    return false;
  }
  return isHazukiTransientNetworkFailure(error);
}

bool _isTransientStatus(int? statusCode) {
  return statusCode == 408 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;
}
