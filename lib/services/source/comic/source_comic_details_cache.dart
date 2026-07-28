import '../../../models/hazuki_models.dart';
import '../runtime/source_runtime_host.dart';

/// Tracks the newest request for each comic so an older response cannot
/// replace data obtained by a forced refresh.
class SourceComicDetailsRequestTracker {
  final Map<String, Object> _activeRequests = {};

  Object begin(String scopedComicKey) {
    final token = Object();
    _activeRequests[scopedComicKey] = token;
    return token;
  }

  bool isCurrent(String scopedComicKey, Object token) =>
      identical(_activeRequests[scopedComicKey], token);

  void complete(String scopedComicKey, Object token) {
    if (isCurrent(scopedComicKey, token)) {
      _activeRequests.remove(scopedComicKey);
    }
  }
}

/// Owns source-scoped in-memory comic detail cache access.
class SourceComicDetailsCache {
  SourceComicDetailsCache({required SourceRuntimeHost runtimeHost})
    : _runtimeHost = runtimeHost;

  final SourceRuntimeHost _runtimeHost;

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  ComicDetailsData? get(String comicId, {String sourceKey = ''}) {
    final cache = _runtimeHost
        .handleFor(_resolveSourceKey(sourceKey))
        .cache
        .comicDetailsMemoryCache;
    final value = cache.remove(comicId);
    if (value != null) cache[comicId] = value;
    return value;
  }

  void put(String comicId, ComicDetailsData details, {String sourceKey = ''}) {
    final cache = _runtimeHost
        .handleFor(_resolveSourceKey(sourceKey))
        .cache
        .comicDetailsMemoryCache;
    cache.remove(comicId);
    cache[comicId] = details;
    while (cache.length > 120) {
      cache.remove(cache.keys.first);
    }
  }

  void update(
    SourceScopedComicId scopedId, {
    required ComicDetailsData Function(ComicDetailsData details) transform,
  }) {
    final sourceKey = _resolveSourceKey(scopedId.sourceKey);
    final cache = _runtimeHost
        .handleFor(sourceKey)
        .cache
        .comicDetailsMemoryCache;
    final canonicalKey = scopedId.storageKey;
    for (final entry in cache.entries.toList()) {
      if (entry.key != canonicalKey &&
          entry.value.scopedId.storageKey != canonicalKey) {
        continue;
      }
      put(entry.key, transform(entry.value), sourceKey: sourceKey);
    }
  }
}
