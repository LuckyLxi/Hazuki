part of '../hazuki_source_service.dart';

extension HazukiSourceServiceImageCacheCapability on HazukiSourceService {
  int get imageCacheMaxBytes {
    final prefs = _prefs;
    final value =
        prefs?.getInt(HazukiSourceService._cacheMaxBytesKey) ??
        HazukiSourceService._defaultCacheMaxBytes;
    return value < HazukiSourceService._defaultCacheMaxBytes
        ? HazukiSourceService._defaultCacheMaxBytes
        : value;
  }

  Future<void> setImageCacheMaxBytes(int value) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final normalized = value < HazukiSourceService._defaultCacheMaxBytes
        ? HazukiSourceService._defaultCacheMaxBytes
        : value;
    await prefs.setInt(HazukiSourceService._cacheMaxBytesKey, normalized);
    await _enforceImageCachePolicy();
  }

  String get imageCacheAutoCleanMode {
    final prefs = _prefs;
    final mode = prefs?.getString(HazukiSourceService._cacheAutoCleanModeKey);
    if (mode == 'seven_days') {
      return mode!;
    }
    return HazukiSourceService._defaultAutoCleanMode;
  }

  Future<void> setImageCacheAutoCleanMode(String mode) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final normalized = mode == 'seven_days' ? 'seven_days' : 'size_overflow';
    await prefs.setString(
      HazukiSourceService._cacheAutoCleanModeKey,
      normalized,
    );
    await _enforceImageCachePolicy(force: true);
  }

  Future<Map<String, dynamic>> getImageCacheStatus() async {
    final dir = await _ensureImageCacheDir();
    final bytes = await _computeImageCacheSizeBytes();
    return {
      'maxBytes': imageCacheMaxBytes,
      'usedBytes': bytes,
      'autoCleanMode': imageCacheAutoCleanMode,
      'path': dir.path,
    };
  }

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
      options: Options(responseType: ResponseType.bytes, headers: headers),
    );

    final data = response.data;
    if (response.statusCode != 200 || data == null || data.isEmpty) {
      throw Exception('image_download_failed:${response.statusCode ?? -1}');
    }

    return Uint8List.fromList(data);
  }

  Future<void> _initImageCache() async {
    await _ensureImageCacheDir();
    await _enforceImageCachePolicy(force: true);
  }

  Future<Directory> _ensureImageCacheDir() async {
    final existed = _imageCacheDir;
    if (existed != null) {
      return existed;
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/image_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _imageCacheDir = dir;
    return dir;
  }

  String _cacheFileNameForUrl(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    return '$hash.bin';
  }

  Future<File> _cacheFileForUrl(String url) async {
    final dir = await _ensureImageCacheDir();
    return File('${dir.path}/${_cacheFileNameForUrl(url)}');
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

  void evictImageBytesFromMemory(Iterable<String> urls) {
    for (final url in urls) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) {
        continue;
      }
      _imageBytesCache.remove(normalizedUrl);
    }
  }

  void _putInMemoryCache(String url, Uint8List bytes) {
    _imageBytesCache[url] = bytes;
    while (_imageBytesCache.length > 80) {
      _imageBytesCache.remove(_imageBytesCache.keys.first);
    }
  }

  Future<void> _enforceImageCachePolicy({bool force = false}) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final now = DateTime.now();
    final mode = imageCacheAutoCleanMode;

    if (mode == 'seven_days') {
      final lastAtMs =
          prefs.getInt(HazukiSourceService._cacheLastAutoCleanAtKey) ?? 0;
      final shouldCleanByAge =
          force ||
          lastAtMs <= 0 ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastAtMs)) >=
              const Duration(days: 7);
      if (shouldCleanByAge) {
        await _cleanImageCacheByAge(const Duration(days: 1));
        await prefs.setInt(
          HazukiSourceService._cacheLastAutoCleanAtKey,
          now.millisecondsSinceEpoch,
        );
      }
    }

    final trimmedByOverflow = await _trimImageCacheToOverflowTarget();
    if (mode != 'seven_days' && trimmedByOverflow) {
      await prefs.setInt(
        HazukiSourceService._cacheLastAutoCleanAtKey,
        now.millisecondsSinceEpoch,
      );
    }
  }

  Future<bool> _trimImageCacheToOverflowTarget() async {
    final dir = await _ensureImageCacheDir();
    final entities = await dir.list(followLinks: false).toList();
    final files = <File>[];
    for (final entity in entities) {
      if (entity is File) {
        files.add(entity);
      }
    }

    final stats = <MapEntry<File, FileStat>>[];
    var total = 0;
    for (final file in files) {
      try {
        final stat = await file.stat();
        if (stat.size <= 0) {
          continue;
        }
        total += stat.size;
        stats.add(MapEntry(file, stat));
      } catch (_) {
        continue;
      }
    }

    final maxBytes = imageCacheMaxBytes;
    if (total <= maxBytes) {
      return false;
    }

    var targetBytes =
        (maxBytes * HazukiSourceService._cacheOverflowTrimTargetRatio).round();
    if (targetBytes < 0) {
      targetBytes = 0;
    }

    stats.sort((a, b) => a.value.modified.compareTo(b.value.modified));
    var removedAny = false;
    for (final item in stats) {
      if (total <= targetBytes) {
        break;
      }
      try {
        await item.key.delete();
        total -= item.value.size;
        removedAny = true;
      } catch (_) {
        continue;
      }
    }

    return removedAny;
  }

  Future<void> _cleanImageCacheByAge(Duration keepDuration) async {
    final dir = await _ensureImageCacheDir();
    final entities = await dir.list(followLinks: false).toList();
    final threshold = DateTime.now().subtract(keepDuration);
    for (final entity in entities) {
      if (entity is! File) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(threshold)) {
          await entity.delete();
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<int> _computeImageCacheSizeBytes() async {
    final dir = await _ensureImageCacheDir();
    final entities = await dir.list(followLinks: false).toList();
    var total = 0;
    for (final entity in entities) {
      if (entity is! File) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (stat.size > 0) {
          total += stat.size;
        }
      } catch (_) {
        continue;
      }
    }
    return total;
  }

  Future<void> clearImageCache() async {
    final dir = await _ensureImageCacheDir();
    final entities = await dir.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is! File) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        continue;
      }
    }
    _imageBytesCache.clear();
  }
}
