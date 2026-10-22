import 'package:dio/dio.dart';

import '../../network/hazuki_network.dart';
import '../debug/source_network_log_sink.dart';
import '../runtime/source_cookie_store.dart';
import '../models/source_script_execution.dart';
import '../models/source_task.dart';
import '../runtime/source_host_call_context.dart';

class SourceHttpGateway {
  SourceHttpGateway({
    required Dio dio,
    required String sourceKey,
    required SourceCookieStore cookieStore,
    required SourceNetworkLogSink networkLogSink,
    Map<String, String> Function()? browserUserAgents,
    void Function(int statusCode)? onResponseStatus,
  }) : _cookieStore = cookieStore,
       _browserUserAgents = browserUserAgents ?? _noUserAgents,
       _networkLogSink = networkLogSink,
       _onResponseStatus = onResponseStatus,
       _client = HazukiNetworkClient(dio: dio, sourceKey: sourceKey);

  final SourceCookieStore _cookieStore;
  static const _hostContextKey = 'hazukiSourceHostCallContext';
  static const _imageCommitKey = 'hazukiImageCookieCommit';
  static const _imageExecutionKey = 'hazukiImageExecution';
  static Map<String, String> _noUserAgents() => const {};
  final Map<String, String> Function() _browserUserAgents;
  final SourceNetworkLogSink _networkLogSink;
  final void Function(int statusCode)? _onResponseStatus;
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
    void Function()? checkActive,
    CancelToken? cancelToken,
  }) async {
    // Native redirects would carry the pinned UA to a different origin without
    // passing through Dio interceptors. Rebuild each hop from caller headers.
    final manageRedirects =
        withCookies &&
        _browserUserAgents().isNotEmpty &&
        (options?.followRedirects ?? dio.options.followRedirects);
    var currentUrl = normalizeUrl(url);
    var currentMethod = method.toUpperCase();
    var currentData = data;
    var currentOptions = _mergeOptions(
      options,
      extra: withCookies ? null : const {'hazukiSkipCookieBridge': true},
    );
    if (manageRedirects) {
      currentOptions = currentOptions.copyWith(followRedirects: false);
    }
    final maxRedirects = options?.maxRedirects ?? dio.options.maxRedirects;
    for (var redirects = 0; ; redirects++) {
      checkActive?.call();
      final response = await _client.request<T>(
        currentUrl,
        method: currentMethod,
        data: currentData,
        options: currentOptions,
        onReceiveProgress: onReceiveProgress,
        retryPolicy: retryPolicy,
        cancelToken: cancelToken,
      );
      checkActive?.call();
      final status = response.statusCode;
      final location = response.headers.value('location');
      final redirect =
          const [301, 302, 303, 307, 308].contains(status) &&
          (currentMethod == 'GET' ||
              currentMethod == 'HEAD' ||
              status == 303 ||
              status == 307 ||
              status == 308);
      if (!manageRedirects || !redirect || location == null) return response;
      if (redirects >= maxRedirects) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          error: StateError('http_too_many_redirects'),
        );
      }
      final previous = Uri.parse(currentUrl);
      final next = previous.resolve(location);
      final headers = Map<String, dynamic>.from(currentOptions.headers ?? {});
      if (next.origin != previous.origin) {
        headers.removeWhere(
          (key, _) => const {
            'authorization',
            'proxy-authorization',
            'cookie',
          }.contains(key.toLowerCase()),
        );
      }
      if (status == 303 && currentMethod != 'HEAD') {
        currentMethod = 'GET';
        currentData = null;
        headers.removeWhere(
          (key, _) => const {
            'content-type',
            'content-length',
          }.contains(key.toLowerCase()),
        );
      }
      currentOptions = currentOptions.copyWith(headers: headers);
      currentUrl = next.toString();
    }
  }

  Future<Response<List<int>>> getBytes(
    String url, {
    Map<String, dynamic>? headers,
    String? category,
    HazukiNetworkRetryPolicy retryPolicy =
        HazukiNetworkRetryPolicy.conservative,
    CancelToken? cancelToken,
    void Function()? checkActive,
    Future<void> Function(Future<void> Function())? commitCookies,
    SourceScriptExecution? execution,
  }) {
    return request<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        extra: {
          'hazukiLogCategory': ?category,
          _imageCommitKey: ?commitCookies,
          _imageExecutionKey: ?execution,
        },
      ),
      retryPolicy: retryPolicy,
      cancelToken: cancelToken,
      checkActive: checkActive,
    );
  }

  Future<Map<String, dynamic>> sendJsHttpRequest(
    Map<String, dynamic> request, {
    SourceScriptExecution? execution,
    String? runtimeId,
    void Function()? checkActive,
    SourceHostCallContext? hostContext,
  }) async {
    Response<dynamic>? response;
    String? error;
    final startedAt = DateTime.now();

    final method = (request['http_method']?.toString() ?? 'GET').toUpperCase();
    final url = request['url']?.toString() ?? '';
    final requestUrl = normalizeUrl(url);
    final headers = Map<String, dynamic>.from(request['headers'] as Map? ?? {});
    final bytes = request['bytes'] == true;
    final data = request['data'];
    final cancelToken = hostContext == null ? null : CancelToken();
    var finished = false;
    if (hostContext != null) {
      hostContext.whenStopped.then((_) {
        if (!finished) cancelToken!.cancel('source_work_stopped');
      });
    }
    void checkResource() {
      hostContext?.checkActive();
      checkActive?.call();
    }

    try {
      checkResource();
      response = await this.request<dynamic>(
        requestUrl,
        method: method,
        data: data,
        checkActive: checkResource,
        cancelToken: cancelToken,
        options: Options(
          responseType: bytes ? ResponseType.bytes : ResponseType.plain,
          headers: headers,
          extra: {
            'skipNetworkDebugLog': true,
            _hostContextKey: ?hostContext,
            if (bytes) 'hazukiLogCategory': 'image_download',
          },
        ),
      );
    } catch (e) {
      error = e.toString();
      hostContext?.checkActive();
      if (e is SourceScriptStopped ||
          e is DioException && CancelToken.isCancel(e)) {
        rethrow;
      }
      if (e is DioException) {
        response = e.response;
      }
    } finally {
      finished = true;
      final statusCode = response?.statusCode;
      if (statusCode != null) {
        _onResponseStatus?.call(statusCode);
      }
      _networkLogSink.append(
        method: method,
        url: requestUrl,
        statusCode: response?.statusCode,
        error: error,
        startedAt: startedAt,
        source: 'js_http',
        category: bytes ? 'image_download' : 'js_http',
        requestHeaders: Map<String, dynamic>.from(
          response?.requestOptions.headers ?? headers,
        ),
        requestData: data,
        responseHeaders: _flattenHeaders(response?.headers),
        responseBody: response?.data,
        taskContext: execution == null
            ? null
            : {
                ...execution.toMap(),
                'runtimeId': runtimeId,
                if (hostContext != null) ...{
                  'nativeToken': hostContext.nativeToken,
                  'workId': hostContext.workId,
                  'resourceId': hostContext.resourceId,
                  'resourceStopped': hostContext.isStopped,
                },
              },
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
            final uri = Uri.parse(normalizedUrl);
            final userAgent = uri.scheme == 'https'
                ? _browserUserAgents()[uri.origin]
                : null;
            if (userAgent != null) {
              options.headers = {
                for (final entry in options.headers.entries)
                  if (entry.key.toLowerCase() != 'user-agent')
                    entry.key: entry.value,
                'User-Agent': userAgent,
              };
            }
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
          final context =
              response.requestOptions.extra[_hostContextKey]
                  as SourceHostCallContext?;
          try {
            final imageCommit =
                response.requestOptions.extra[_imageCommitKey]
                    as Future<void> Function(Future<void> Function())?;
            if (imageCommit != null) {
              await imageCommit(
                () => _cookieStore.saveFromHeaders(
                  requestUrl,
                  response.headers.map,
                ),
              );
            } else if (context == null) {
              await _cookieStore.saveFromHeaders(
                requestUrl,
                response.headers.map,
              );
            } else {
              await context.runCommit(
                () => _cookieStore.saveFromHeaders(
                  requestUrl,
                  response.headers.map,
                ),
              );
            }
          } catch (error, stack) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: context?.isStopped == true || error is SourceTaskCancelled
                    ? DioExceptionType.cancel
                    : DioExceptionType.unknown,
                error: error,
                stackTrace: stack,
              ),
            );
            return;
          }

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
              taskContext:
                  (response.requestOptions.extra[_imageExecutionKey]
                          as SourceScriptExecution?)
                      ?.toMap(),
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
              taskContext:
                  (options.extra[_imageExecutionKey] as SourceScriptExecution?)
                      ?.toMap(),
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
