part of '../hazuki_source_service.dart';

extension HazukiSourceServiceExploreCapability on HazukiSourceService {
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) async {
    await ensureInitialized();

    if (!forceRefresh) {
      final memoryCached = _getExploreSectionsFromMemoryCache();
      if (memoryCached != null) {
        return memoryCached;
      }
    } else {
      _exploreSectionsMemoryCache = null;
      _exploreSectionsMemoryCachedAt = null;
    }

    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final hasExplore = _asBool(
      engine.evaluate('Array.isArray(this.__hazuki_source.explore)'),
    );
    if (!hasExplore) {
      return const [];
    }

    final exploreType =
        (engine.evaluate('this.__hazuki_source.explore?.[0]?.type') ?? '')
            .toString();
    if (exploreType != 'multiPartPage') {
      throw Exception('explore_type_not_supported:$exploreType');
    }

    final dynamic result = engine.evaluate(
      'this.__hazuki_source.explore[0].load(null)',
      name: 'source_explore_load.js',
    );

    final dynamic resolved = result is Future ? await result : result;
    if (resolved is! List) {
      return const [];
    }

    final sections = <ExploreSection>[];
    for (final item in resolved) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final title = map['title']?.toString() ?? '__untitled_section__';
      final list = map['comics'];
      if (list is! List) {
        continue;
      }
      // 提取 viewMore 字段（jm.js 格式如 "category:禁漫天堂@0"）
      final viewMore = map['viewMore']?.toString().trim();

      final comics = _parseExploreComics(list);
      if (comics.isNotEmpty) {
        sections.add(
          ExploreSection(
            title: title,
            comics: comics,
            viewMoreUrl: viewMore?.isNotEmpty == true ? viewMore : null,
          ),
        );
      }
    }

    _putExploreSectionsInMemoryCache(sections);
    return List<ExploreSection>.unmodifiable(sections);
  }

  List<ExploreComic> _parseExploreComics(List list) {
    final comics = <ExploreComic>[];
    for (final comic in list) {
      if (comic is! Map) {
        continue;
      }
      final comicMap = Map<String, dynamic>.from(comic);
      comics.add(
        ExploreComic(
          id: comicMap['id']?.toString() ?? '',
          title: comicMap['title']?.toString() ?? '',
          subTitle: (comicMap['subTitle'] ?? comicMap['subtitle'] ?? '')
              .toString(),
          cover: comicMap['cover']?.toString() ?? '',
        ),
      );
    }
    return comics;
  }

  Future<void> _initDiscoverCache() async {
    _exploreSectionsMemoryCache = null;
    _exploreSectionsMemoryCachedAt = null;
    final dir = _discoverCacheDir;
    _discoverCacheDir = null;
    try {
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  List<ExploreSection>? _getExploreSectionsFromMemoryCache() {
    final sections = _exploreSectionsMemoryCache;
    final cachedAt = _exploreSectionsMemoryCachedAt;
    if (sections == null || cachedAt == null) {
      return null;
    }
    if (DateTime.now().difference(cachedAt) >
        HazukiSourceService._discoverCacheTtl) {
      _exploreSectionsMemoryCache = null;
      _exploreSectionsMemoryCachedAt = null;
      return null;
    }
    return sections;
  }

  void _putExploreSectionsInMemoryCache(List<ExploreSection> sections) {
    _exploreSectionsMemoryCache = List<ExploreSection>.unmodifiable(sections);
    _exploreSectionsMemoryCachedAt = DateTime.now();
  }
}
