part of '../hazuki_source_service.dart';

extension HazukiSourceServiceImageCacheDownloadCapability
    on HazukiSourceService {
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    int memoryCount = 0,
  }) async {
    final max = count < imageUrls.length ? count : imageUrls.length;
    for (var i = 0; i < max; i++) {
      final url = imageUrls[i];
      if (url.trim().isEmpty) {
        continue;
      }
      try {
        await downloadImageBytes(
          url,
          comicId: comicId,
          epId: epId,
          keepInMemory: i < memoryCount,
        );
      } catch (_) {
        continue;
      }
    }
  }

  Future<Uint8List> downloadImageBytes(
    String url, {
    String? comicId,
    String? epId,
    bool keepInMemory = true,
    bool useDiskCache = true,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw Exception('image_url_empty');
    }

    final cached = _imageBytesCache[normalizedUrl];
    if (cached != null) {
      _imageBytesCache.remove(normalizedUrl);
      _imageBytesCache[normalizedUrl] = cached;
      return cached;
    }

    if (useDiskCache) {
      final diskCached = await _readImageBytesFromDisk(normalizedUrl);
      if (diskCached != null) {
        if (keepInMemory) {
          _putInMemoryCache(normalizedUrl, diskCached);
        }
        return diskCached;
      }
    }

    final inFlight = _imageDownloadInFlight[normalizedUrl];
    if (inFlight != null) {
      final bytes = await inFlight;
      if (keepInMemory) {
        _putInMemoryCache(normalizedUrl, bytes);
      }
      return bytes;
    }

    final future = _downloadImageBytesFromNetwork(
      normalizedUrl,
      comicId: comicId,
      epId: epId,
    );
    _imageDownloadInFlight[normalizedUrl] = future;

    try {
      final bytes = await future;
      if (useDiskCache) {
        await _saveImageBytesToDisk(normalizedUrl, bytes);
      }
      if (keepInMemory) {
        _putInMemoryCache(normalizedUrl, bytes);
      }
      return bytes;
    } finally {
      _imageDownloadInFlight.remove(normalizedUrl);
    }
  }

  Future<Uint8List> _downloadImageBytesFromNetwork(
    String url, {
    String? comicId,
    String? epId,
  }) async {
    final headers = <String, dynamic>{};

    try {
      final engine = _engine;
      if (engine != null) {
        final cid = jsonEncode(comicId ?? '');
        final eid = jsonEncode(epId ?? '');
        final dynamic configRaw = engine.evaluate(
          'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(url)}, $cid, $eid) ?? {}',
          name: 'source_on_image_load.js',
        );
        final dynamic config = await _awaitJsResult(configRaw);
        if (config is Map) {
          final cfg = Map<String, dynamic>.from(config);
          final h = cfg['headers'];
          if (h is Map) {
            headers.addAll(Map<String, dynamic>.from(h));
          }
        }
      }
    } catch (_) {}

    final cookie = _buildCookieHeader(url);
    if (cookie != null && cookie.isNotEmpty && !headers.containsKey('cookie')) {
      headers['cookie'] = cookie;
    }

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        extra: {'hazukiLogCategory': 'image_download'},
      ),
    );

    final data = response.data;
    if (response.statusCode != 200 || data == null || data.isEmpty) {
      throw Exception('image_download_failed:${response.statusCode ?? -1}');
    }

    return Uint8List.fromList(data);
  }

  Future<Uint8List?> _readImageBytesFromDisk(String url) async {
    try {
      final file = await _cacheFileForUrl(url);
      if (!await file.exists()) {
        return null;
      }
      final stat = await file.stat();
      final now = DateTime.now();
      await file.setLastAccessed(now);
      await file.setLastModified(now);
      if (stat.size <= 0) {
        return null;
      }
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveImageBytesToDisk(String url, Uint8List bytes) async {
    try {
      final file = await _cacheFileForUrl(url);
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size == bytes.length && stat.size > 0) {
          final now = DateTime.now();
          await file.setLastAccessed(now);
          await file.setLastModified(now);
          return;
        }
      }
      await file.writeAsBytes(bytes, flush: false);
      await _enforceImageCachePolicy();
    } catch (_) {}
  }
}
