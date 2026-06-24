import '../../../models/hazuki_models.dart';
import '../common/source_prefs_keys.dart';
import 'source_runtime_facade.dart';

class ExploreCacheCapability {
  ExploreCacheCapability(this._facade);

  final HazukiSourceFacade _facade;

  Future<void> init() async {
    _facade.cache.exploreSectionsMemoryCache = null;
    _facade.cache.exploreSectionsMemoryCachedAt = null;
    _facade.cache.clearCategoryTagGroupsMemoryCache();
    final dir = _facade.cache.discoverCacheDir;
    _facade.cache.discoverCacheDir = null;
    try {
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  List<ExploreSection>? getCachedSections() {
    final sections = _facade.cache.exploreSectionsMemoryCache;
    final cachedAt = _facade.cache.exploreSectionsMemoryCachedAt;
    if (sections == null || cachedAt == null) {
      return null;
    }
    if (DateTime.now().difference(cachedAt) >
        SourcePrefsKeys.discoverCacheTtl) {
      _facade.cache.exploreSectionsMemoryCache = null;
      _facade.cache.exploreSectionsMemoryCachedAt = null;
      return null;
    }
    return sections;
  }

  void putSections(List<ExploreSection> sections) {
    _facade.cache.exploreSectionsMemoryCache =
        List<ExploreSection>.unmodifiable(sections);
    _facade.cache.exploreSectionsMemoryCachedAt = DateTime.now();
  }

  void clearMemory() {
    _facade.cache.exploreSectionsMemoryCache = null;
    _facade.cache.exploreSectionsMemoryCachedAt = null;
  }
}
