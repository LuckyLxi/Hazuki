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

      final diskCached = await _readExploreSectionsFromDisk();
      if (diskCached != null) {
        _putExploreSectionsInMemoryCache(diskCached);
        return diskCached;
      }
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
    await _saveExploreSectionsToDisk(sections);
    return sections;
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
    await _ensureDiscoverCacheDir();
  }

  Future<Directory> _ensureDiscoverCacheDir() async {
    final existed = _discoverCacheDir;
    if (existed != null) {
      return existed;
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/discover_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _discoverCacheDir = dir;
    return dir;
  }

  Future<File> _discoverCacheFile() async {
    final dir = await _ensureDiscoverCacheDir();
    return File('${dir.path}/discover_sections.json');
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

  Map<String, dynamic> _exploreSectionToJson(ExploreSection section) {
    return {
      'title': section.title,
      'viewMoreUrl': section.viewMoreUrl,
      'comics': section.comics
          .map(
            (comic) => {
              'id': comic.id,
              'title': comic.title,
              'subTitle': comic.subTitle,
              'cover': comic.cover,
            },
          )
          .toList(),
    };
  }

  ExploreSection? _exploreSectionFromJson(Map<String, dynamic> map) {
    final title = map['title']?.toString().trim() ?? '';
    final comicsRaw = map['comics'];
    if (title.isEmpty || comicsRaw is! List) {
      return null;
    }

    final comics = _parseExploreComics(comicsRaw);
    if (comics.isEmpty) {
      return null;
    }

    final viewMoreUrl = map['viewMoreUrl']?.toString().trim();
    return ExploreSection(
      title: title,
      comics: comics,
      viewMoreUrl: viewMoreUrl?.isNotEmpty == true ? viewMoreUrl : null,
    );
  }

  Future<List<ExploreSection>?> _readExploreSectionsFromDisk() async {
    try {
      final file = await _discoverCacheFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);
      final cachedAtMs = map['cachedAtMs'];
      final listRaw = map['sections'];
      final cachedAt = switch (cachedAtMs) {
        int value => DateTime.fromMillisecondsSinceEpoch(value),
        num value => DateTime.fromMillisecondsSinceEpoch(value.toInt()),
        _ => null,
      };
      if (cachedAt == null ||
          DateTime.now().difference(cachedAt) >
              HazukiSourceService._discoverCacheTtl) {
        await file.delete();
        return null;
      }

      if (listRaw is! List) {
        return null;
      }

      final sections = <ExploreSection>[];
      for (final item in listRaw) {
        if (item is! Map) {
          continue;
        }
        final section = _exploreSectionFromJson(
          Map<String, dynamic>.from(item),
        );
        if (section != null) {
          sections.add(section);
        }
      }

      if (sections.isEmpty) {
        return null;
      }

      final now = DateTime.now();
      await file.setLastAccessed(now);
      await file.setLastModified(now);
      _exploreSectionsMemoryCachedAt = cachedAt;
      return sections;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveExploreSectionsToDisk(List<ExploreSection> sections) async {
    try {
      final file = await _discoverCacheFile();
      final payload = {
        'cachedAtMs': DateTime.now().millisecondsSinceEpoch,
        'sections': sections.map(_exploreSectionToJson).toList(),
      };
      await file.writeAsString(jsonEncode(payload), flush: false);
    } catch (_) {}
  }
}
