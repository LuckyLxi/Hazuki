import 'dart:async';

import 'package:dio/dio.dart';

import 'hazuki_network_errors.dart';
import 'hazuki_url_normalizer.dart';

enum HazukiNetworkRetryPolicy { none, conservative, allowUnsafe }

class HazukiNetworkRequest {
  const HazukiNetworkRequest({
    required this.method,
    required this.url,
    this.data,
    this.options,
    this.retryPolicy = HazukiNetworkRetryPolicy.conservative,
  });

  final String method;
  final String url;
  final Object? data;
  final Options? options;
  final HazukiNetworkRetryPolicy retryPolicy;
}

class HazukiNetworkResponse<T> {
  const HazukiNetworkResponse({
    required this.statusCode,
    required this.headers,
    required this.data,
    required this.requestUrl,
  });

  final int? statusCode;
  final Headers headers;
  final T? data;
  final String requestUrl;

  factory HazukiNetworkResponse.fromDio(Response<T> response) {
    return HazukiNetworkResponse<T>(
      statusCode: response.statusCode,
      headers: response.headers,
      data: response.data,
      requestUrl: response.requestOptions.uri.toString(),
    );
  }
}

typedef HazukiNetworkUrlNormalizer =
    String Function(String url, {String sourceKey});

class HazukiNetworkClient {
  HazukiNetworkClient({
    Dio? dio,
    String sourceKey = '',
    HazukiNetworkUrlNormalizer urlNormalizer = normalizeHazukiRequestUrl,
    Duration retryDelay = const Duration(milliseconds: 250),
    int maxAttempts = 2,
  }) : dio = dio ?? Dio(),
       _sourceKey = sourceKey,
       _urlNormalizer = urlNormalizer,
       _retryDelay = retryDelay,
       _maxAttempts = maxAttempts < 1 ? 1 : maxAttempts;

  final Dio dio;
  final String _sourceKey;
  final HazukiNetworkUrlNormalizer _urlNormalizer;
  final Duration _retryDelay;
  final int _maxAttempts;

  String normalizeUrl(String url) {
    return _urlNormalizer(url, sourceKey: _sourceKey);
  }

  Future<Response<T>> send<T>(
    HazukiNetworkRequest networkRequest, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return request<T>(
      networkRequest.url,
      method: networkRequest.method,
      data: networkRequest.data,
      options: networkRequest.options,
      retryPolicy: networkRequest.retryPolicy,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> request<T>(
    String url, {
    String method = 'GET',
    Object? data,
    Options? options,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final normalizedMethod = method.trim().isEmpty
        ? 'GET'
        : method.trim().toUpperCase();
    final requestUrl = normalizeUrl(url);
    final requestOptions = (options ?? Options()).copyWith(
      method: normalizedMethod,
    );

    var attempt = 1;
    while (true) {
      try {
        final response = await dio.request<T>(
          requestUrl,
          data: data,
          options: requestOptions,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
          onReceiveProgress: onReceiveProgress,
        );
        if (!_shouldRetryStatus(
          method: normalizedMethod,
          statusCode: response.statusCode,
          attempt: attempt,
          retryPolicy: retryPolicy,
        )) {
          return response;
        }
        attempt++;
        await _delayBeforeRetry();
      } catch (error) {
        if (!_shouldRetry(
          method: normalizedMethod,
          error: error,
          attempt: attempt,
          retryPolicy: retryPolicy,
        )) {
          rethrow;
        }
        attempt++;
        await _delayBeforeRetry();
      }
    }
  }

  Future<Response<T>> get<T>(
    String url, {
    Options? options,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return request<T>(
      url,
      method: 'GET',
      options: options,
      retryPolicy: retryPolicy,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> post<T>(
    String url, {
    Object? data,
    Options? options,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
    CancelToken? cancelToken,
  }) {
    return request<T>(
      url,
      method: 'POST',
      data: data,
      options: options,
      retryPolicy: retryPolicy,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> download(
    String url,
    String savePath, {
    Options? options,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    ProgressCallback? onReceiveProgress,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
  }) async {
    final requestUrl = normalizeUrl(url);
    var attempt = 1;
    while (true) {
      try {
        final response = await dio.download(
          requestUrl,
          savePath,
          options: options,
          cancelToken: cancelToken,
          deleteOnError: deleteOnError,
          onReceiveProgress: onReceiveProgress,
        );
        if (!_shouldRetryStatus(
          method: 'GET',
          statusCode: response.statusCode,
          attempt: attempt,
          retryPolicy: retryPolicy,
        )) {
          return response;
        }
        attempt++;
        await _delayBeforeRetry();
      } catch (error) {
        if (!_shouldRetry(
          method: 'GET',
          error: error,
          attempt: attempt,
          retryPolicy: retryPolicy,
        )) {
          rethrow;
        }
        attempt++;
        await _delayBeforeRetry();
      }
    }
  }

  bool _shouldRetry({
    required String method,
    required Object error,
    required int attempt,
    required HazukiNetworkRetryPolicy retryPolicy,
  }) {
    if (retryPolicy == HazukiNetworkRetryPolicy.none) {
      return false;
    }
    return shouldRetryHazukiNetworkRequest(
      method: method,
      error: error,
      attempt: attempt,
      maxAttempts: _maxAttempts,
      allowUnsafeRetry: retryPolicy == HazukiNetworkRetryPolicy.allowUnsafe,
    );
  }

  bool _shouldRetryStatus({
    required String method,
    required int? statusCode,
    required int attempt,
    required HazukiNetworkRetryPolicy retryPolicy,
  }) {
    if (retryPolicy == HazukiNetworkRetryPolicy.none) {
      return false;
    }
    if (attempt >= _maxAttempts) {
      return false;
    }
    if (retryPolicy != HazukiNetworkRetryPolicy.allowUnsafe &&
        !isHazukiSafeNetworkMethod(method)) {
      return false;
    }
    return isHazukiTransientStatusCode(statusCode);
  }

  Future<void> _delayBeforeRetry() {
    if (_retryDelay == Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(_retryDelay);
  }
}
