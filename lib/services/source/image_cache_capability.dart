part of '../hazuki_source_service.dart';

extension HazukiSourceServiceImageCacheCapability on HazukiSourceService {
  int get imageCacheMaxBytes {
    final prefs = facade.session.prefs;
    final value =
        prefs?.getInt(HazukiSourceService._cacheMaxBytesKey) ??
        HazukiSourceService._defaultCacheMaxBytes;
    return value < HazukiSourceService._defaultCacheMaxBytes
        ? HazukiSourceService._defaultCacheMaxBytes
        : value;
  }

  Future<void> setImageCacheMaxBytes(int value) async {
    final prefs = facade.session.prefs;
    if (prefs == null) {
      return;
    }
    final normalized = value < HazukiSourceService._defaultCacheMaxBytes
        ? HazukiSourceService._defaultCacheMaxBytes
        : value;
    await prefs.setInt(HazukiSourceService._cacheMaxBytesKey, normalized);
    await facade.enforceImageCachePolicy();
  }

  String get imageCacheAutoCleanMode {
    final prefs = facade.session.prefs;
    final mode = prefs?.getString(HazukiSourceService._cacheAutoCleanModeKey);
    if (mode == 'seven_days') {
      return mode!;
    }
    return HazukiSourceService._defaultAutoCleanMode;
  }

  Future<void> setImageCacheAutoCleanMode(String mode) async {
    final prefs = facade.session.prefs;
    if (prefs == null) {
      return;
    }
    final normalized = mode == 'seven_days' ? 'seven_days' : 'size_overflow';
    await prefs.setString(
      HazukiSourceService._cacheAutoCleanModeKey,
      normalized,
    );
    await facade.enforceImageCachePolicy(force: true);
  }

  Future<Map<String, dynamic>> getImageCacheStatus() async {
    final dir = await facade.ensureImageCacheDir();
    final bytes = await facade.computeImageCacheSizeBytes();
    return {
      'maxBytes': imageCacheMaxBytes,
      'usedBytes': bytes,
      'autoCleanMode': imageCacheAutoCleanMode,
      'path': dir.path,
    };
  }

  Uint8List? peekImageBytesFromMemory(String url) {
    return facade.cache.touchImageBytes(url);
  }

  void evictImageBytesFromMemory(Iterable<String> urls) {
    facade.cache.evictImageBytes(urls);
  }

  void _putInMemoryCache(String url, Uint8List bytes) {
    facade.cache.putImageBytes(url, bytes);
  }
}
