import 'dart:async';

import 'package:dio/dio.dart';

import 'source_runtime_facade.dart';

abstract interface class SourceTextDownloadClient {
  Future<String?> firstAvailable(
    List<String> urls, {
    required HazukiSourceFacade facade,
    String source = 'source_fetch',
  });

  Future<String?> sequential(
    List<String> urls, {
    required HazukiSourceFacade facade,
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
  });
}

/// Downloads source text while keeping request diagnostics source-scoped.
class SourceTextDownloader implements SourceTextDownloadClient {
  const SourceTextDownloader();

  @override
  Future<String?> firstAvailable(
    List<String> urls, {
    required HazukiSourceFacade facade,
    String source = 'source_fetch',
  }) async {
    if (urls.isEmpty) return null;

    Future<String?> requestOnce(String url) async {
      final startedAt = DateTime.now();
      final requestUrl = facade.httpGateway.normalizeUrl(url);
      try {
        final response = await facade.httpGateway.request<String>(
          requestUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
            extra: {'skipNetworkDebugLog': true, 'hazukiLogCategory': source},
          ),
        );
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: response.statusCode,
          error: null,
          startedAt: startedAt,
          category: source,
          responseHeaders: response.headers.map,
          responseBody: response.data,
        );
        if (response.statusCode == 200 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data;
        }
      } catch (error) {
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: null,
          error: error.toString(),
          startedAt: startedAt,
          category: source,
        );
      }
      return null;
    }

    final completer = Completer<String?>();
    var finished = false;

    void tryComplete(String? value) {
      if (finished || value == null) return;
      finished = true;
      completer.complete(value);
    }

    Future<void> runAll() async {
      await Future.wait(
        urls.map((url) async => tryComplete(await requestOnce(url))),
      );
      if (!finished) completer.complete(null);
    }

    runAll();
    return completer.future;
  }

  @override
  Future<String?> sequential(
    List<String> urls, {
    required HazukiSourceFacade facade,
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
  }) async {
    for (final url in urls) {
      final startedAt = DateTime.now();
      final requestUrl = facade.httpGateway.normalizeUrl(url);
      try {
        final response = await facade.httpGateway.request<String>(
          requestUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'cache-control': 'no-cache'},
            extra: {'skipNetworkDebugLog': true, 'hazukiLogCategory': source},
          ),
          onReceiveProgress: onProgress,
        );
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: response.statusCode,
          error: null,
          startedAt: startedAt,
          category: source,
          responseHeaders: response.headers.map,
          responseBody: response.data,
        );
        if (response.statusCode == 200 &&
            (response.data?.isNotEmpty ?? false)) {
          return response.data;
        }
      } catch (error) {
        facade.networkLogSink.append(
          source: source,
          method: 'GET',
          url: requestUrl,
          statusCode: null,
          error: error.toString(),
          startedAt: startedAt,
          category: source,
        );
      }
    }
    return null;
  }
}
