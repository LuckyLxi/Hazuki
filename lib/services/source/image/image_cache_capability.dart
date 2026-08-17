import 'dart:io';
import 'dart:typed_data';

import '../../../models/hazuki_models.dart';
import '../runtime/source_runtime_facade.dart';
import 'image_cache_policy.dart';
import 'image_disk_cache_store.dart';
import 'image_download_scheduler.dart';
import 'source_image_network_downloader.dart';

class ImageCacheCapability {
  ImageCacheCapability(HazukiSourceFacade facade)
    : _facade = facade,
      _diskCache = ImageDiskCacheStore(
        getCachedDirectory: () => facade.cache.imageCacheDir,
        setCachedDirectory: (directory) =>
            facade.cache.imageCacheDir = directory,
      );

  final HazukiSourceFacade _facade;
  final ImageDiskCacheStore _diskCache;
  late final ImageCachePolicy _policy = ImageCachePolicy(
    getPreferences: () => _facade.session.prefs,
    cleanByAge: _diskCache.cleanByAge,
    trimToOverflow: _diskCache.trimToOverflow,
  );
  late final SourceImageNetworkDownloader _networkDownloader =
      SourceImageNetworkDownloader.forFacade(_facade);

  final ImageDownloadScheduler _downloadScheduler = ImageDownloadScheduler();

  // ---------- Cache size config ----------

  int get maxBytes => _policy.maxBytes;

  Future<void> setMaxBytes(int value) => _policy.setMaxBytes(value);

  String get autoCleanMode => _policy.autoCleanMode;

  Future<void> setAutoCleanMode(String mode) => _policy.setAutoCleanMode(mode);

  Future<Map<String, dynamic>> getStatus() async {
    final dir = await ensureCacheDir();
    final bytes = await computeSizeBytes();
    return {
      'maxBytes': maxBytes,
      'usedBytes': bytes,
      'autoCleanMode': autoCleanMode,
      'path': dir.path,
    };
  }

  // ---------- Memory cache ----------

  String _resolveSourceKeyForRequest(String sourceKey) {
    final requested = sourceKey.trim();
    final handleSourceKey = _facade.sourceKey;
    if (requested.isEmpty) {
      return handleSourceKey;
    }
    if (requested != handleSourceKey) {
      throw Exception('source_mismatch:$requested:$handleSourceKey');
    }
    return requested;
  }

  Uint8List? peekFromMemory(String url, {String sourceKey = ''}) {
    final cacheKey = SourceScopedComicId(
      sourceKey: _resolveSourceKeyForRequest(sourceKey),
      comicId: url,
    ).imageCacheKey;
    return _facade.cache.touchImageBytes(cacheKey);
  }

  void evictFromMemory(Iterable<String> urls, {String sourceKey = ''}) {
    final resolvedSourceKey = _resolveSourceKeyForRequest(sourceKey);
    _facade.cache.evictImageBytes(
      urls.map(
        (url) => SourceScopedComicId(
          sourceKey: resolvedSourceKey,
          comicId: url,
        ).imageCacheKey,
      ),
    );
  }

  void _putInMemoryCache(String url, Uint8List bytes) {
    _facade.cache.putImageBytes(url, bytes);
  }

  // ---------- Download ----------

  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    int memoryCount = 0,
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = _resolveSourceKeyForRequest(sourceKey);
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
          sourceKey: resolvedSourceKey,
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
    bool priority = false,
    String sourceKey = '',
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw Exception('image_url_empty');
    }
    final resolvedSourceKey = _resolveSourceKeyForRequest(sourceKey);
    final cacheKey = SourceScopedComicId(
      sourceKey: resolvedSourceKey,
      comicId: normalizedUrl,
    ).imageCacheKey;

    final memoryCache = _facade.cache.imageBytesCache;
    final cached = memoryCache[cacheKey];
    if (cached != null) {
      memoryCache.remove(cacheKey);
      memoryCache[cacheKey] = cached;
      return cached;
    }

    if (useDiskCache) {
      final diskCached = await _readFromDisk(
        normalizedUrl,
        sourceKey: resolvedSourceKey,
      );
      if (diskCached != null) {
        if (keepInMemory) {
          _putInMemoryCache(cacheKey, diskCached);
        }
        return diskCached;
      }
    }

    final inFlightMap = _facade.cache.imageDownloadInFlight;
    final inFlight = inFlightMap[cacheKey];
    if (inFlight != null) {
      if (priority) {
        _downloadScheduler.promote(cacheKey);
      }
      final bytes = await inFlight;
      if (keepInMemory) {
        _putInMemoryCache(cacheKey, bytes);
      }
      return bytes;
    }

    final future = _downloadScheduler.schedule(
      cacheKey,
      priority: priority,
      task: () => _networkDownloader.download(
        normalizedUrl,
        comicId: comicId,
        epId: epId,
      ),
    );
    inFlightMap[cacheKey] = future;

    try {
      final bytes = await future;
      if (useDiskCache) {
        await _saveToDisk(normalizedUrl, bytes, sourceKey: resolvedSourceKey);
      }
      if (keepInMemory) {
        _putInMemoryCache(cacheKey, bytes);
      }
      return bytes;
    } finally {
      inFlightMap.remove(cacheKey);
    }
  }

  // ---------- Disk cache ----------

  Future<Uint8List?> _readFromDisk(String url, {String sourceKey = ''}) =>
      _diskCache.read(url, sourceKey: sourceKey);

  Future<void> _saveToDisk(
    String url,
    Uint8List bytes, {
    String sourceKey = '',
  }) async {
    try {
      final wrote = await _diskCache.write(url, bytes, sourceKey: sourceKey);
      if (wrote) await _policy.enforce();
    } catch (_) {}
  }

  // ---------- Maintenance ----------

  Future<void> init() async {
    await ensureCacheDir();
    await _policy.enforce(force: true);
  }

  Future<Directory> ensureCacheDir() => _diskCache.ensureDirectory();

  Future<void> enforcePolicy({bool force = false}) =>
      _policy.enforce(force: force);

  Future<int> computeSizeBytes() => _diskCache.computeSizeBytes();

  Future<void> clear() async {
    await _diskCache.clear();
    _facade.cache.imageBytesCache.clear();
  }

  Future<void> evictEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = _resolveSourceKeyForRequest(sourceKey);
    await _diskCache.evictEntries(urls, sourceKey: resolvedSourceKey);
  }
}
