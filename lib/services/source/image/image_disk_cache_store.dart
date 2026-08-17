import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/hazuki_models.dart';

typedef ImageCacheDirectoryResolver = Future<Directory> Function();

/// Owns file-system access for source-scoped image cache entries.
class ImageDiskCacheStore {
  ImageDiskCacheStore({
    required Directory? Function() getCachedDirectory,
    required void Function(Directory directory) setCachedDirectory,
    ImageCacheDirectoryResolver? resolveDirectory,
  }) : _getCachedDirectory = getCachedDirectory,
       _setCachedDirectory = setCachedDirectory,
       _resolveDirectory = resolveDirectory ?? _resolveDefaultDirectory;

  final Directory? Function() _getCachedDirectory;
  final void Function(Directory directory) _setCachedDirectory;
  final ImageCacheDirectoryResolver _resolveDirectory;

  Future<Directory> ensureDirectory() async {
    final cached = _getCachedDirectory();
    if (cached != null) return cached;
    final directory = await _resolveDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _setCachedDirectory(directory);
    return directory;
  }

  Future<Uint8List?> read(String url, {String sourceKey = ''}) async {
    try {
      final file = await _fileFor(url, sourceKey: sourceKey);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      final now = DateTime.now();
      await file.setLastAccessed(now);
      await file.setLastModified(now);
      if (stat.size <= 0) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Returns whether bytes were written. Matching existing bytes are touched.
  Future<bool> write(
    String url,
    Uint8List bytes, {
    String sourceKey = '',
  }) async {
    final file = await _fileFor(url, sourceKey: sourceKey);
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.size == bytes.length && stat.size > 0) {
        final now = DateTime.now();
        await file.setLastAccessed(now);
        await file.setLastModified(now);
        return false;
      }
    }
    await file.writeAsBytes(bytes, flush: false);
    return true;
  }

  Future<bool> trimToOverflow({
    required int limitBytes,
    required double targetRatio,
  }) async {
    final stats = await _positiveFileStats();
    var total = stats.fold<int>(0, (sum, item) => sum + item.value.size);
    if (total <= limitBytes) return false;

    var targetBytes = (limitBytes * targetRatio).round();
    if (targetBytes < 0) targetBytes = 0;
    stats.sort((a, b) => a.value.modified.compareTo(b.value.modified));
    var removedAny = false;
    for (final item in stats) {
      if (total <= targetBytes) break;
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

  Future<void> cleanByAge(Duration keepDuration, {DateTime? now}) async {
    final threshold = (now ?? DateTime.now()).subtract(keepDuration);
    for (final entity in await _files()) {
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(threshold)) await entity.delete();
      } catch (_) {
        continue;
      }
    }
  }

  Future<int> computeSizeBytes() async {
    final stats = await _positiveFileStats();
    return stats.fold<int>(0, (sum, item) => sum + item.value.size);
  }

  Future<void> clear() async {
    for (final file in await _files()) {
      try {
        await file.delete();
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> evictEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) async {
    for (final url in urls) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) continue;
      try {
        final file = await _fileFor(normalizedUrl, sourceKey: sourceKey);
        if (await file.exists()) await file.delete();
      } catch (_) {
        continue;
      }
    }
  }

  Future<List<File>> _files() async {
    final directory = await ensureDirectory();
    final entities = await directory.list(followLinks: false).toList();
    return entities.whereType<File>().toList();
  }

  Future<List<MapEntry<File, FileStat>>> _positiveFileStats() async {
    final stats = <MapEntry<File, FileStat>>[];
    for (final file in await _files()) {
      try {
        final stat = await file.stat();
        if (stat.size > 0) stats.add(MapEntry(file, stat));
      } catch (_) {
        continue;
      }
    }
    return stats;
  }

  Future<File> _fileFor(String url, {String sourceKey = ''}) async {
    final directory = await ensureDirectory();
    final scopedUrl = SourceScopedComicId(
      sourceKey: sourceKey,
      comicId: url,
    ).imageCacheKey;
    final hash = md5.convert(utf8.encode(scopedUrl)).toString();
    return File('${directory.path}/$hash.bin');
  }

  static Future<Directory> _resolveDefaultDirectory() async {
    if (Platform.isWindows) {
      final executableDirectory = File(Platform.resolvedExecutable).parent.path;
      return Directory('$executableDirectory/image_cache');
    }
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory('${supportDirectory.path}/image_cache');
  }
}
