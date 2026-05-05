part of '../hazuki_source_service.dart';

Future<void>? _enforceCachePolicyInFlight;

extension HazukiSourceServiceImageCacheMaintenanceCapability
    on HazukiSourceService {
  Future<void> _initImageCache() async {
    await _ensureImageCacheDir();
    await _enforceImageCachePolicy(force: true);
  }

  Future<Directory> _ensureImageCacheDir() async {
    final existed = _imageCacheDir;
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
    _imageCacheDir = dir;
    return dir;
  }

  String _cacheFileNameForUrl(String url, {String sourceKey = ''}) {
    final scopedUrl = SourceScopedComicId(
      sourceKey: sourceKey,
      comicId: url,
    ).imageCacheKey;
    final hash = md5.convert(utf8.encode(scopedUrl)).toString();
    return '$hash.bin';
  }

  Future<File> _cacheFileForUrl(String url, {String sourceKey = ''}) async {
    final dir = await _ensureImageCacheDir();
    return File(
      '${dir.path}/${_cacheFileNameForUrl(url, sourceKey: sourceKey)}',
    );
  }

  Future<void> _enforceImageCachePolicy({bool force = false}) {
    if (!force) {
      final inFlight = _enforceCachePolicyInFlight;
      if (inFlight != null) {
        return inFlight;
      }
    }
    final future = _enforceImageCachePolicyInternal(force: force);
    _enforceCachePolicyInFlight = future;
    return future.whenComplete(() {
      if (identical(_enforceCachePolicyInFlight, future)) {
        _enforceCachePolicyInFlight = null;
      }
    });
  }

  Future<void> _enforceImageCachePolicyInternal({bool force = false}) async {
    final prefs = facade.session.prefs;
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

  Future<void> evictImageCacheEntries(Iterable<String> urls) async {
    for (final url in urls) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) {
        continue;
      }
      try {
        final file = await _cacheFileForUrl(
          normalizedUrl,
          sourceKey: activeSourceKey,
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
