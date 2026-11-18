import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import 'source_shared_request.dart';
import '../common/source_prefs_keys.dart';

class SourceCacheStore {
  SourceCacheStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final LinkedHashMap<String, Uint8List> imageBytesCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, SourceSharedRequest<Uint8List>> imageDownloadInFlight = {};
  final LinkedHashMap<String, ComicDetailsData> comicDetailsMemoryCache =
      LinkedHashMap<String, ComicDetailsData>();
  final Map<String, SourceSharedRequest<ComicDetailsData>>
  comicDetailsInFlight = {};
  List<ExploreSection>? _exploreSectionsMemoryCache;
  DateTime? _exploreSectionsMemoryCachedAt;
  List<CategoryTagGroup>? categoryTagGroupsMemoryCache;
  DateTime? categoryTagGroupsMemoryCachedAt;
  Directory? imageCacheDir;
  Directory? comicDetailsCacheDir;
  Directory? discoverCacheDir;

  Future<void> initializeExploreCache() async {
    _exploreSectionsMemoryCache = null;
    _exploreSectionsMemoryCachedAt = null;
    clearCategoryTagGroupsMemoryCache();
    final dir = discoverCacheDir;
    discoverCacheDir = null;
    try {
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  List<ExploreSection>? getExploreSections() {
    final sections = _exploreSectionsMemoryCache;
    final cachedAt = _exploreSectionsMemoryCachedAt;
    if (sections == null || cachedAt == null) {
      return null;
    }
    if (_now().difference(cachedAt) > SourcePrefsKeys.discoverCacheTtl) {
      _exploreSectionsMemoryCache = null;
      _exploreSectionsMemoryCachedAt = null;
      return null;
    }
    return sections;
  }

  void putExploreSections(List<ExploreSection> sections) {
    _exploreSectionsMemoryCache = List<ExploreSection>.unmodifiable(sections);
    _exploreSectionsMemoryCachedAt = _now();
  }

  void clearExploreSections() {
    _exploreSectionsMemoryCache = null;
    _exploreSectionsMemoryCachedAt = null;
  }

  void clearMemory() {
    imageBytesCache.clear();
    imageDownloadInFlight.clear();
    comicDetailsMemoryCache.clear();
    comicDetailsInFlight.clear();
    _exploreSectionsMemoryCache = null;
    _exploreSectionsMemoryCachedAt = null;
    categoryTagGroupsMemoryCache = null;
    categoryTagGroupsMemoryCachedAt = null;
    imageCacheDir = null;
    comicDetailsCacheDir = null;
    discoverCacheDir = null;
  }

  Uint8List? touchImageBytes(String rawUrl) {
    final normalizedUrl = rawUrl.trim();
    if (normalizedUrl.isEmpty) return null;
    final cached = imageBytesCache.remove(normalizedUrl);
    if (cached == null) return null;
    imageBytesCache[normalizedUrl] = cached;
    return cached;
  }

  void evictImageBytes(Iterable<String> urls) {
    for (final url in urls) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isNotEmpty) imageBytesCache.remove(normalizedUrl);
    }
  }

  void putImageBytes(String url, Uint8List bytes, {int maxEntries = 80}) {
    imageBytesCache.remove(url);
    imageBytesCache[url] = bytes;
    while (imageBytesCache.length > maxEntries) {
      imageBytesCache.remove(imageBytesCache.keys.first);
    }
  }

  List<CategoryTagGroup>? getCategoryTagGroupsFromMemoryCache(Duration ttl) {
    final groups = categoryTagGroupsMemoryCache;
    final cachedAt = categoryTagGroupsMemoryCachedAt;
    if (groups == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > ttl) {
      clearCategoryTagGroupsMemoryCache();
      return null;
    }
    return groups;
  }

  void clearCategoryTagGroupsMemoryCache() {
    categoryTagGroupsMemoryCache = null;
    categoryTagGroupsMemoryCachedAt = null;
  }

  void putCategoryTagGroupsInMemoryCache(List<CategoryTagGroup> groups) {
    categoryTagGroupsMemoryCache = groups;
    categoryTagGroupsMemoryCachedAt = DateTime.now();
  }
}
