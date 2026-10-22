import '../models/source_task.dart';
import 'dart:typed_data';

import 'image_cache_capability.dart';

abstract interface class SourceImageOperations {
  int get imageCacheMaxBytes;
  String get imageCacheAutoCleanMode;
  Future<void> setImageCacheMaxBytes(int value);
  Future<void> setImageCacheAutoCleanMode(String mode);
  Future<Map<String, dynamic>> getImageCacheStatus();
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''});
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  });
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    int memoryCount = 0,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<Uint8List> downloadImageBytes(
    String url, {
    String? comicId,
    String? epId,
    bool keepInMemory = true,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> clearImageCache();
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  });
}

class SourceImageOperationService implements SourceImageOperations {
  const SourceImageOperationService(this._cacheForSource);

  final ImageCacheCapability Function(String sourceKey) _cacheForSource;
  ImageCacheCapability get _activeCache => _cacheForSource('');
  ImageCacheCapability _cacheForTask(String key, SourceTaskOrigin? origin) {
    origin?.readerSession?.checkActive();
    origin?.downloadSession?.checkActive();
    return _cacheForSource(key);
  }

  @override
  int get imageCacheMaxBytes => _activeCache.maxBytes;
  @override
  String get imageCacheAutoCleanMode => _activeCache.autoCleanMode;
  @override
  Future<void> setImageCacheMaxBytes(int value) =>
      _activeCache.setMaxBytes(value);
  @override
  Future<void> setImageCacheAutoCleanMode(String mode) =>
      _activeCache.setAutoCleanMode(mode);
  @override
  Future<Map<String, dynamic>> getImageCacheStatus() =>
      _activeCache.getStatus();
  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      _cacheForSource(sourceKey).peekFromMemory(url, sourceKey: sourceKey);
  @override
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _cacheForSource(sourceKey).evictFromMemory(urls, sourceKey: sourceKey);
  @override
  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    int memoryCount = 0,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _cacheForTask(sourceKey, taskOrigin).prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String? comicId,
    String? epId,
    bool keepInMemory = true,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _cacheForTask(sourceKey, taskOrigin).downloadImageBytes(
    url,
    comicId: comicId,
    epId: epId,
    keepInMemory: keepInMemory,
    useDiskCache: useDiskCache,
    priority: priority,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> clearImageCache() => _activeCache.clear();
  @override
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _cacheForSource(sourceKey).evictEntries(urls, sourceKey: sourceKey);
}
