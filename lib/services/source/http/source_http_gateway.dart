import 'package:dio/dio.dart';

import '../../network/hazuki_network.dart';
import '../debug/source_network_log_sink.dart';
import '../runtime/source_cookie_store.dart';

class SourceHttpGateway {
  SourceHttpGateway({
    required Dio dio,
    required String sourceKey,
    required SourceCookieStore cookieStore,
    required SourceNetworkLogSink networkLogSink,
  }) : _cookieStore = cookieStore,
       _networkLogSink = networkLogSink,
       _client = HazukiNetworkClient(dio: dio, sourceKey: sourceKey);

  final SourceCookieStore _cookieStore;
  final SourceNetworkLogSink _networkLogSink;
  final HazukiNetworkClient _client;
  bool _cookieBridgeConfigured = false;

  Dio get dio => _client.dio;

  String normalizeUrl(String url) => _client.normalizeUrl(url);

  String? buildCookieHeader(String url) =>
      _cookieStore.buildHeader(normalizeUrl(url));

  Future<Response<T>> request<T>(
    String url, {
    String method = 'GET',
    Object? data,
    Options? options,
    ProgressCallback? onReceiveProgress,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
    bool withCookies = true,
  }) {
    return _client.request<T>(
      url,
      method: method,
      data: data,
      options: _mergeOptions(
        options,
        extra: withCookies ? null : const {'hazukiSkipCookieBridge': true},
      ),
      onReceiveProgress: onReceiveProgress,
      retryPolicy: retryPolicy,
    );
  }

  Future<Response<List<int>>> getBytes(
    String url, {
    Map<String, dynamic>? headers,
    String? category,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
  }) {
    return request<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        extra: category == null ? const {} : {'hazukiLogCategory': category},
      ),
      retryPolicy: retryPolicy,
    );
  }

  Future<Map<String, dynamic>> sendJsHttpRequest(
    Map<String, dynamic> request,
  ) async {
    Response<dynamic>? response;
    String? error;
    final startedAt = DateTime.now();

    final method = (request['http_method']?.toString() ?? 'GET').toUpperCase();
    final url = request['url']?.toString() ?? '';
    final requestUrl = normalizeUrl(url);
    final headers = Map<String, dynamic>.from(request['headers'] as Map? ?? {});
    final bytes = request['bytes'] == true;
    final data = request['data'];

    try {
      response = await this.request<dynamic>(
        requestUrl,
        method: method,
        data: data,
        options: Options(
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          headers: headers,
          extra: {
            'skipNetworkDebugLog': true,
            if (bytes) 'hazukiLogCategory': 'image_download',
          },
        ),
      );
    } catch (e) {
      if (e is DioException) {
        response = e.response;
      }
      error = e.toString();
    } finally {
      _networkLogSink.append(
        method: method,
        url: requestUrl,
        statusCode: response?.statusCode,
        error: error,
        startedAt: startedAt,
        source: 'js_http',
        category: bytes ? 'image_download' : 'js_http',
        requestHeaders: Map<String, dynamic>.from(headers),
        requestData: data,
        responseHeaders: _flattenHeaders(response?.headers),
        responseBody: response?.data,
      );
    }

    return {
      'status': response?.statusCode,
      'headers': _stringHeaders(response?.headers),
      'body': response?.data,
      'error': error,
    };
  }

  void configureCookieBridge() {
    if (_cookieBridgeConfigured) {
      return;
    }
    _cookieBridgeConfigured = true;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final normalizedUrl = normalizeUrl(options.uri.toString());
          if (normalizedUrl != options.uri.toString()) {
            options.path = normalizedUrl;
          }
          options.extra['hazukiStartedAt'] = DateTime.now();
          if (options.extra['hazukiSkipCookieBridge'] != true) {
            final cookieHeader = _cookieStore.buildHeader(normalizedUrl);
            if (cookieHeader != null && cookieHeader.isNotEmpty) {
              final existing = options.headers['cookie'];
              if (existing is String && existing.trim().isNotEmpty) {
                options.headers['cookie'] = '$existing; $cookieHeader';
              } else {
                options.headers['cookie'] = cookieHeader;
              }
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final requestUrl = response.requestOptions.uri.toString();
          await _cookieStore.saveFromHeaders(requestUrl, response.headers.map);

          final skipLog =
              response.requestOptions.extra['skipNetworkDebugLog'] == true;
          if (!skipLog) {
            _networkLogSink.append(
              method: response.requestOptions.method,
              url: requestUrl,
              statusCode: response.statusCode,
              error: null,
              startedAt: _startedAtFor(response.requestOptions),
              source: 'dio_direct',
              category: response.requestOptions.extra['hazukiLogCategory']
                  ?.toString(),
              requestHeaders: Map<String, dynamic>.from(
                response.requestOptions.headers,
              ),
              requestData: response.requestOptions.data,
              responseHeaders: _flattenHeaders(response.headers),
              responseBody: response.data,
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final options = error.requestOptions;
          final skipLog = options.extra['skipNetworkDebugLog'] == true;
          if (!skipLog) {
            _networkLogSink.append(
              method: options.method,
              url: options.uri.toString(),
              statusCode: error.response?.statusCode,
              error: error.toString(),
              startedAt: _startedAtFor(options),
              source: 'dio_direct',
              category: options.extra['hazukiLogCategory']?.toString(),
              requestHeaders: Map<String, dynamic>.from(options.headers),
              requestData: options.data,
              responseHeaders: _flattenHeaders(error.response?.headers),
              responseBody: error.response?.data,
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  DateTime _startedAtFor(RequestOptions options) {
    final startedAt = options.extra['hazukiStartedAt'];
    return startedAt is DateTime ? startedAt : DateTime.now();
  }

  Options _mergeOptions(Options? options, {Map<String, dynamic>? extra}) {
    if (extra == null || extra.isEmpty) {
      return options ?? Options();
    }
    final base = options ?? Options();
    return base.copyWith(extra: {...?base.extra, ...extra});
  }

  Map<String, dynamic> _flattenHeaders(Headers? headers) {
    final result = <String, dynamic>{};
    headers?.forEach((name, values) {
      result[name] = values.join(',');
    });
    return result;
  }

  Map<String, String> _stringHeaders(Headers? headers) {
    final result = <String, String>{};
    headers?.forEach((name, values) {
      result[name] = values.join(',');
    });
    return result;
  }
}
