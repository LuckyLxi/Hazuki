import '../models/source_task.dart';
import 'dart:typed_data';

import 'image_cache_capability.dart';

class SourceImageOperations {
  const SourceImageOperations(this._cacheForSource);

  final ImageCacheCapability Function(String sourceKey) _cacheForSource;
  ImageCacheCapability get _activeCache => _cacheForSource('');
  ImageCacheCapability _cacheForTask(String key, SourceTaskOrigin? origin) {
    origin?.readerSession?.checkActive();
    origin?.downloadSession?.checkActive();
    return _cacheForSource(key);
  }

  int get imageCacheMaxBytes => _activeCache.maxBytes;
  String get imageCacheAutoCleanMode => _activeCache.autoCleanMode;
  Future<void> setImageCacheMaxBytes(int value) =>
      _activeCache.setMaxBytes(value);
  Future<void> setImageCacheAutoCleanMode(String mode) =>
      _activeCache.setAutoCleanMode(mode);
  Future<Map<String, dynamic>> getImageCacheStatus() =>
      _activeCache.getStatus();
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      _cacheForSource(sourceKey).peekFromMemory(url, sourceKey: sourceKey);
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _cacheForSource(sourceKey).evictFromMemory(urls, sourceKey: sourceKey);
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
  Future<void> clearImageCache() => _activeCache.clear();
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) => _cacheForSource(sourceKey).evictEntries(urls, sourceKey: sourceKey);
}
