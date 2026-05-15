import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/hazuki_models.dart';
import '../../hazuki_source_service.dart';
import '../common/source_prefs_keys.dart';

class ImageCacheCapability {
  ImageCacheCapability(this._handle);

  final SourceRuntimeHandle _handle;

  HazukiSourceFacade get _facade => _handle.facade;

  static const int _maxConcurrent = 4;
  int _activeCount = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  Future<void>? _enforcePolicyInFlight;

  // ---------- Cache size config ----------

  int get maxBytes {
    final prefs = _facade.session.prefs;
    final value =
        prefs?.getInt(SourcePrefsKeys.cacheMaxBytes) ??
        SourcePrefsKeys.defaultCacheMaxBytes;
    return value < SourcePrefsKeys.defaultCacheMaxBytes
        ? SourcePrefsKeys.defaultCacheMaxBytes
        : value;
  }

  Future<void> setMaxBytes(int value) async {
    final prefs = _facade.session.prefs;
    if (prefs == null) {
      return;
    }
    final normalized = value < SourcePrefsKeys.defaultCacheMaxBytes
        ? SourcePrefsKeys.defaultCacheMaxBytes
        : value;
    await prefs.setInt(SourcePrefsKeys.cacheMaxBytes, normalized);
    await enforcePolicy();
  }

  String get autoCleanMode {
    final prefs = _facade.session.prefs;
    final mode = prefs?.getString(SourcePrefsKeys.cacheAutoCleanMode);
    if (mode == 'seven_days') {
      return mode!;
    }
    return SourcePrefsKeys.defaultAutoCleanMode;
  }

  Future<void> setAutoCleanMode(String mode) async {
    final prefs = _facade.session.prefs;
    if (prefs == null) {
      return;
    }
    final normalized = mode == 'seven_days' ? 'seven_days' : 'size_overflow';
    await prefs.setString(SourcePrefsKeys.cacheAutoCleanMode, normalized);
    await enforcePolicy(force: true);
  }

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
      final bytes = await inFlight;
      if (keepInMemory) {
        _putInMemoryCache(cacheKey, bytes);
      }
      return bytes;
    }

    final future = () async {
      await _acquireSlot();
      try {
        return await _downloadFromNetwork(
          normalizedUrl,
          comicId: comicId,
          epId: epId,
        );
      } finally {
        _releaseSlot();
      }
    }();
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

  Future<Uint8List> _downloadFromNetwork(
    String url, {
    String? comicId,
    String? epId,
  }) async {
    final headers = <String, dynamic>{};

    try {
      final engine = _facade.js.engine;
      if (engine != null) {
        final cid = jsonEncode(comicId ?? '');
        final eid = jsonEncode(epId ?? '');
        final dynamic configRaw = engine.evaluate(
          'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(url)}, $cid, $eid) ?? {}',
          name: 'source_on_image_load.js',
        );
        final dynamic config = await _facade.js.resolve(configRaw);
        if (config is Map) {
          final cfg = Map<String, dynamic>.from(config);
          final h = cfg['headers'];
          if (h is Map) {
            headers.addAll(Map<String, dynamic>.from(h));
          }
        }
      }
    } catch (_) {}

    final cookie = _facade.httpGateway.buildCookieHeader(url);
    if (cookie != null && cookie.isNotEmpty && !headers.containsKey('cookie')) {
      headers['cookie'] = cookie;
    }

    final response = await _facade.httpGateway.dio.get<List<int>>(
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

  Future<void> _acquireSlot() async {
    if (_activeCount < _maxConcurrent) {
      _activeCount++;
      return;
    }
    final completer = Completer<void>();
    _waiters.addLast(completer);
    await completer.future;
  }

  void _releaseSlot() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (!next.isCompleted) {
        next.complete();
      }
      return;
    }
    if (_activeCount > 0) {
      _activeCount--;
    }
  }

  // ---------- Disk cache ----------

  Future<Uint8List?> _readFromDisk(String url, {String sourceKey = ''}) async {
    try {
      final file = await _cacheFileFor(url, sourceKey: sourceKey);
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

  Future<void> _saveToDisk(
    String url,
    Uint8List bytes, {
    String sourceKey = '',
  }) async {
    try {
      final file = await _cacheFileFor(url, sourceKey: sourceKey);
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
      await enforcePolicy();
    } catch (_) {}
  }

  // ---------- Maintenance ----------

  Future<void> init() async {
    await ensureCacheDir();
    await enforcePolicy(force: true);
  }

  Future<Directory> ensureCacheDir() async {
    final existed = _facade.cache.imageCacheDir;
    if (existed != null) {
      return existed;
    }
    Directory dir;
    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      dir = Directory('$exeDir/image_cache');
    } else {
      final supportDir = await getApplicationSupportDirectory();
      dir = Directory('${supportDir.path}/image_cache');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _facade.cache.imageCacheDir = dir;
    return dir;
  }

  String _cacheFileName(String url, {String sourceKey = ''}) {
    final scopedUrl = SourceScopedComicId(
      sourceKey: sourceKey,
      comicId: url,
    ).imageCacheKey;
    final hash = md5.convert(utf8.encode(scopedUrl)).toString();
    return '$hash.bin';
  }

  Future<File> _cacheFileFor(String url, {String sourceKey = ''}) async {
    final dir = await ensureCacheDir();
    return File('${dir.path}/${_cacheFileName(url, sourceKey: sourceKey)}');
  }

  Future<void> enforcePolicy({bool force = false}) {
    if (!force) {
      final inFlight = _enforcePolicyInFlight;
      if (inFlight != null) {
        return inFlight;
      }
    }
    final future = _enforcePolicyInternal(force: force);
    _enforcePolicyInFlight = future;
    return future.whenComplete(() {
      if (identical(_enforcePolicyInFlight, future)) {
        _enforcePolicyInFlight = null;
      }
    });
  }

  Future<void> _enforcePolicyInternal({bool force = false}) async {
    final prefs = _facade.session.prefs;
    if (prefs == null) {
      return;
    }

    final now = DateTime.now();
    final mode = autoCleanMode;

    if (mode == 'seven_days') {
      final lastAtMs = prefs.getInt(SourcePrefsKeys.cacheLastAutoCleanAt) ?? 0;
      final shouldCleanByAge =
          force ||
          lastAtMs <= 0 ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastAtMs)) >=
              const Duration(days: 7);
      if (shouldCleanByAge) {
        await _cleanByAge(const Duration(days: 1));
        await prefs.setInt(
          SourcePrefsKeys.cacheLastAutoCleanAt,
          now.millisecondsSinceEpoch,
        );
      }
    }

    final trimmedByOverflow = await _trimToOverflow();
    if (mode != 'seven_days' && trimmedByOverflow) {
      await prefs.setInt(
        SourcePrefsKeys.cacheLastAutoCleanAt,
        now.millisecondsSinceEpoch,
      );
    }
  }

  Future<bool> _trimToOverflow() async {
    final dir = await ensureCacheDir();
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

    final limit = maxBytes;
    if (total <= limit) {
      return false;
    }

    var targetBytes = (limit * SourcePrefsKeys.cacheOverflowTrimTargetRatio)
        .round();
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

  Future<void> _cleanByAge(Duration keepDuration) async {
    final dir = await ensureCacheDir();
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

  Future<int> computeSizeBytes() async {
    final dir = await ensureCacheDir();
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

  Future<void> clear() async {
    final dir = await ensureCacheDir();
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
    _facade.cache.imageBytesCache.clear();
  }

  Future<void> evictEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = _resolveSourceKeyForRequest(sourceKey);
    for (final url in urls) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) {
        continue;
      }
      try {
        final file = await _cacheFileFor(
          normalizedUrl,
          sourceKey: resolvedSourceKey,
        );
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        continue;
      }
    }
  }
}
