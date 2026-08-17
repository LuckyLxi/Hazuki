import 'dart:convert';
import 'dart:typed_data';

import '../runtime/source_runtime_facade.dart';

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

  factory SourceImageNetworkDownloader.forFacade(HazukiSourceFacade facade) {
    return SourceImageNetworkDownloader(
      resolveLoadConfig: (url, comicId, epId) async {
        final engine = facade.js.engine;
        if (engine == null) return null;
        final raw = engine.evaluate(
          buildImageLoadScript(url, comicId: comicId, epId: epId),
          name: 'source_on_image_load.js',
        );
        return facade.js.resolve(raw);
      },
      resolveCookie: facade.httpGateway.buildCookieHeader,
      requestBytes: (url, headers) async {
        final response = await facade.httpGateway.getBytes(
          url,
          headers: headers,
          category: 'image_download',
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
  }) async {
    final headers = <String, dynamic>{};
    try {
      final config = await _resolveLoadConfig(url, comicId ?? '', epId ?? '');
      if (config is Map) {
        final rawHeaders = config['headers'];
        if (rawHeaders is Map) {
          headers.addAll(Map<String, dynamic>.from(rawHeaders));
        }
      }
    } catch (_) {}

    final cookie = _resolveCookie(url);
    if (cookie != null && cookie.isNotEmpty && !headers.containsKey('cookie')) {
      headers['cookie'] = cookie;
    }

    final response = await _requestBytes(url, headers);
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
