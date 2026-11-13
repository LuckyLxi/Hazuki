import '../common/source_operation_stop.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../runtime/source_runtime_facade.dart'
    show SourceRuntimeHandleView, SourceJsBridge;
import '../http/source_http_gateway.dart';
import '../runtime/source_shared_request.dart';

typedef SourceImageLoadConfigResolver =
    Future<dynamic> Function(String url, String comicId, String epId);
typedef SourceImageCookieResolver = String? Function(String url);
typedef SourceImageBytesRequester =
    Future<SourceImageBytesResponse> Function(
      String url,
      Map<String, dynamic> headers,
    );

class SourceImageBytesResponse {
  const SourceImageBytesResponse({
    required this.statusCode,
    required this.data,
  });

  final int? statusCode;
  final List<int>? data;
}

/// Resolves source-specific request options and downloads validated image bytes.
class SourceImageNetworkDownloader {
  const SourceImageNetworkDownloader({
    required SourceImageLoadConfigResolver resolveLoadConfig,
    required SourceImageCookieResolver resolveCookie,
    required SourceImageBytesRequester requestBytes,
  }) : _resolveLoadConfig = resolveLoadConfig,
       _resolveCookie = resolveCookie,
       _requestBytes = requestBytes;

  factory SourceImageNetworkDownloader.forRuntime({
    required SourceRuntimeHandleView handle,
    required Future<void> Function() ensureInitialized,
    required SourceJsBridge js,
    required SourceHttpGateway httpGateway,
    SourceSharedRequest<Uint8List>? request,
  }) {
    final cancelToken = CancelToken();
    request?.addStopHandler((reason) => cancelToken.cancel(reason.name));
    Future<void> ready() async {
      request?.checkActive();
      final initialization = ensureInitialized();
      if (request == null) {
        await initialization;
      } else {
        await Future.any([
          initialization,
          request.cancellation.whenStopped.then((_) => request.checkActive()),
        ]);
      }
      request?.checkActive();
    }

    return SourceImageNetworkDownloader(
      resolveLoadConfig: (url, comicId, epId) => handle.runOperation(() async {
        await ready();
        final engine = js.engine;
        if (engine == null) return null;
        request?.bindEngine(engine);
        final raw = await engine.evaluate(
          buildImageLoadScript(url, comicId: comicId, epId: epId),
          name: 'source_on_image_load.js',
          execution: request?.execution,
          retainAdmittedWork: request != null,
        );
        return js.resolve(raw);
      }),
      resolveCookie: httpGateway.buildCookieHeader,
      requestBytes: (url, headers) async {
        await ready();
        final response = await httpGateway.getBytes(
          url,
          headers: headers,
          category: 'image_download',
          cancelToken: cancelToken,
          checkActive: request?.checkActive,
          execution: request?.execution,
          commitCookies: request == null
              ? null
              : (operation) => request.runCommit(operation),
        );
        return SourceImageBytesResponse(
          statusCode: response.statusCode,
          data: response.data,
        );
      },
    );
  }

  final SourceImageLoadConfigResolver _resolveLoadConfig;
  final SourceImageCookieResolver _resolveCookie;
  final SourceImageBytesRequester _requestBytes;

  Future<Uint8List> download(
    String url, {
    String? comicId,
    String? epId,
    void Function()? checkActive,
  }) async {
    checkActive?.call();
    final headers = <String, dynamic>{};
    var requestUrl = url;
    try {
      final config = await _resolveLoadConfig(url, comicId ?? '', epId ?? '');
      checkActive?.call();
      if (config is Map) {
        final configuredUrl = config['url'];
        if (configuredUrl is String && configuredUrl.trim().isNotEmpty) {
          requestUrl = configuredUrl;
        }
        final rawHeaders = config['headers'];
        if (rawHeaders is Map) {
          headers.addAll(Map<String, dynamic>.from(rawHeaders));
        }
      }
    } catch (error) {
      checkActive?.call();
      rethrowSourceOperationStop(error);
    }

    final cookie = _resolveCookie(requestUrl);
    if (cookie != null &&
        cookie.isNotEmpty &&
        !headers.keys.any((key) => key.toLowerCase() == 'cookie')) {
      headers['cookie'] = cookie;
    }

    checkActive?.call();
    final SourceImageBytesResponse response;
    try {
      response = await _requestBytes(requestUrl, headers);
    } catch (_) {
      checkActive?.call();
      rethrow;
    }
    checkActive?.call();
    final data = response.data;
    if (response.statusCode != 200 || data == null || data.isEmpty) {
      throw Exception('image_download_failed:${response.statusCode ?? -1}');
    }
    return Uint8List.fromList(data);
  }

  static String buildImageLoadScript(
    String url, {
    required String comicId,
    required String epId,
  }) {
    return 'this.__hazuki_source.comic?.onImageLoad?.('
        '${jsonEncode(url)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? {}';
  }
}
