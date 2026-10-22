import '../models/source_task.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../models/hazuki_models.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_task_registry.dart';
import '../runtime/source_shared_request.dart';
import '../runtime/source_operation_context.dart';
import '../debug/source_task_log_recorder.dart';
import 'image_cache_policy.dart';
import 'image_disk_cache_store.dart';
import 'image_download_scheduler.dart';
import 'source_image_network_downloader.dart';

class ImageCacheCapability {
  ImageCacheCapability(
    HazukiSourceFacade facade, {
    SourceTaskRegistry? tasks,
    bool Function()? canCache,
  }) : _tasks = tasks ?? SourceTaskRegistry(),
       _canCache = canCache ?? (() => !facade.handle.isDisposed),
       _facade = facade,
       _diskCache = ImageDiskCacheStore(
         getCachedDirectory: () => facade.cache.imageCacheDir,
         setCachedDirectory: (directory) =>
             facade.cache.imageCacheDir = directory,
       );

  final SourceTaskRegistry _tasks;
  final bool Function() _canCache;
  final HazukiSourceFacade _facade;
  final ImageDiskCacheStore _diskCache;
  late final ImageCachePolicy _policy = ImageCachePolicy(
    getPreferences: () => _facade.session.prefs,
    cleanByAge: _diskCache.cleanByAge,
    trimToOverflow: _diskCache.trimToOverflow,
  );

  final ImageDownloadScheduler _downloadScheduler = ImageDownloadScheduler();

  // ---------- Cache size config ----------

  int get maxBytes => _policy.maxBytes;

  Future<void> setMaxBytes(int value) async {
    await _facade.ensurePrefs();
    await _policy.setMaxBytes(value);
  }

  String get autoCleanMode => _policy.autoCleanMode;

  Future<void> setAutoCleanMode(String mode) async {
    await _facade.ensurePrefs();
    await _policy.setAutoCleanMode(mode);
  }

  Future<Map<String, dynamic>> getStatus() async {
    await _facade.ensurePrefs();
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
    SourceTaskOrigin? taskOrigin,
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
          taskOrigin: taskOrigin,
        );
      } catch (error) {
        rethrowSourceOperationStop(error);
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
    SourceTaskOrigin? taskOrigin,
  }) async {
    final resolvedSourceKey = _resolveSourceKeyForRequest(sourceKey);
    final session = taskOrigin?.readerSession ?? taskOrigin?.downloadSession;
    session?.checkActive();
    if (session != null && session.sourceKey != resolvedSourceKey) {
      throw StateError('source_reader_session_mismatch');
    }
    final recorder = SourceTaskLogRecorder(_facade.appLogStore);
    return _tasks.run(
      pluginId: resolvedSourceKey,
      method: 'image.download',
      origin: taskOrigin,
      observe: (task, event, disposition, error, stack) => recorder.record(
        task,
        event,
        disposition,
        error,
        stack,
        sensitiveValues: [url, comicId ?? '', epId ?? ''],
      ),
      operation: (task) => _facade.handle.runOperation(() async {
        task.bindResource(
          _facade.handle,
          survivesSourceChange: taskOrigin == null,
        );
        task.checkActive();
        final normalizedUrl = url.trim();
        if (normalizedUrl.isEmpty) throw Exception('image_url_empty');
        final cacheKey = SourceScopedComicId(
          sourceKey: resolvedSourceKey,
          comicId: normalizedUrl,
        ).imageCacheKey;
        final identity = _facade.session.loginIdentity;
        bool canCache() =>
            _canCache() && _facade.session.loginIdentity == identity;
        final cached = _facade.cache.touchImageBytes(cacheKey);
        if (cached != null) return cached;
        if (useDiskCache) {
          final bytes = await task.runCommit(
            () => _readFromDisk(normalizedUrl, sourceKey: resolvedSourceKey),
          );
          task.checkActive();
          if (bytes != null) {
            if (keepInMemory && canCache()) _putInMemoryCache(cacheKey, bytes);
            return bytes;
          }
        }
        task.checkActive();
        final map = _facade.cache.imageDownloadInFlight;
        var request = map[cacheKey];
        if (request == null || !request.available) {
          late final SourceSharedRequest<Uint8List> created;
          created = SourceSharedRequest<Uint8List>(
            pluginId: resolvedSourceKey,
            method: 'image.bytes',
            drainOperationOnStop: true,
            onUnavailable: () {
              if (identical(map[cacheKey], created)) map.remove(cacheKey);
            },
            operation: (_) => _facade.handle.runOperation(() async {
              final bytes = await _downloadScheduler.schedule(
                cacheKey,
                priority: priority,
                cancellation: created.cancellation,
                task: () =>
                    SourceImageNetworkDownloader.forFacade(
                      _facade,
                      request: created,
                    ).download(
                      normalizedUrl,
                      comicId: comicId,
                      epId: epId,
                      checkActive: created.checkActive,
                    ),
              );
              created.checkActive();
              bool wants(bool Function(_ImageCacheIntent) test) => created
                  .consumerMetadata
                  .whereType<_ImageCacheIntent>()
                  .any(test);
              if (canCache() && wants((intent) => intent.disk)) {
                await created.runCommit(
                  () => _saveToDisk(
                    normalizedUrl,
                    bytes,
                    sourceKey: resolvedSourceKey,
                  ),
                );
              }
              created.checkActive();
              if (canCache() && wants((intent) => intent.memory)) {
                _putInMemoryCache(cacheKey, bytes);
              }
              return bytes;
            }),
          );
          map[cacheKey] = request = created;
        } else if (priority) {
          _downloadScheduler.promote(cacheKey);
        }
        final bytes = await request.subscribe(
          task: task,
          metadata: _ImageCacheIntent(memory: keepInMemory, disk: useDiskCache),
        );
        task.checkActive();
        return bytes;
      }),
    );
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

class _ImageCacheIntent {
  const _ImageCacheIntent({required this.memory, required this.disk});
  final bool memory;
  final bool disk;
}
