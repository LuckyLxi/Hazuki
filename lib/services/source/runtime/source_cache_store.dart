import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';

class SourceCacheStore {
  final LinkedHashMap<String, Uint8List> imageBytesCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> imageDownloadInFlight = {};
  final LinkedHashMap<String, ComicDetailsData> comicDetailsMemoryCache =
      LinkedHashMap<String, ComicDetailsData>();
  final Map<String, Future<ComicDetailsData>> comicDetailsInFlight = {};
  List<ExploreSection>? exploreSectionsMemoryCache;
  DateTime? exploreSectionsMemoryCachedAt;
  List<CategoryTagGroup>? categoryTagGroupsMemoryCache;
  DateTime? categoryTagGroupsMemoryCachedAt;
  Directory? imageCacheDir;
  Directory? comicDetailsCacheDir;
  Directory? discoverCacheDir;

  void clearMemory() {
    imageBytesCache.clear();
    imageDownloadInFlight.clear();
    comicDetailsMemoryCache.clear();
    comicDetailsInFlight.clear();
    exploreSectionsMemoryCache = null;
    exploreSectionsMemoryCachedAt = null;
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
