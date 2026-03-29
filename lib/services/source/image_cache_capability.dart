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
}
