part of '../hazuki_source_service.dart';

extension HazukiSourceServiceExploreCapability on HazukiSourceService {
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) async {
    final facade = this.facade;
    await facade.ensureInitialized();

    if (!forceRefresh) {
      final memoryCached = exploreCache.getCachedSections();
      if (memoryCached != null) {
        return memoryCached;
      }
    } else {
      exploreCache.clearMemory();
    }

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final hasExplore = facade.js.asBool(
      facade.js.evaluate('Array.isArray(this.__hazuki_source.explore)'),
    );
    if (!hasExplore) {
      return const [];
    }

    final exploreType =
        (engine.evaluate('this.__hazuki_source.explore?.[0]?.type') ?? '')
            .toString();
    if (exploreType != 'multiPartPage' &&
        exploreType != 'singlePageWithMultiPart' &&
        exploreType != 'multiPageComicList') {
      throw Exception('explore_type_not_supported:$exploreType');
    }

    final dynamic result = engine.evaluate(switch (exploreType) {
      'multiPartPage' => 'this.__hazuki_source.explore[0].load(null)',
      'singlePageWithMultiPart' => 'this.__hazuki_source.explore[0].load()',
      _ =>
        '''
Promise.all(
  this.__hazuki_source.explore
    .filter((section) => section?.type === "multiPageComicList")
    .map(async (section) => {
      try {
        return {
          title: section.title ?? "__untitled_section__",
          ...(await section.load(1))
        };
      } catch (_) {
        return null;
      }
    })
).then((sections) => sections.filter((section) => section != null))
''',
    }, name: 'source_explore_load.js');

    final dynamic resolved = await facade.js.resolve(result);
    final sections = switch (exploreType) {
      'multiPartPage' => _parseMultiPartExploreSections(resolved),
      'singlePageWithMultiPart' => _parseSinglePageWithMultiPartExploreSections(
        resolved,
      ),
      _ => _parseMultiPageComicListExploreSections(resolved),
    };

    exploreCache.putSections(sections);
    return List<ExploreSection>.unmodifiable(sections);
  }

  List<ExploreSection> _parseMultiPartExploreSections(dynamic resolved) {
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
    return sections;
  }

  List<ExploreSection> _parseSinglePageWithMultiPartExploreSections(
    dynamic resolved,
  ) {
    if (resolved is! Map) {
      return const [];
    }
    final map = Map<String, dynamic>.from(resolved);
    final sections = <ExploreSection>[];
    for (final entry in map.entries) {
      final list = entry.value;
      if (list is! List) {
        continue;
      }
      final comics = _parseExploreComics(list);
      if (comics.isNotEmpty) {
        sections.add(
          ExploreSection(title: entry.key.toString(), comics: comics),
        );
      }
    }
    return sections;
  }

  List<ExploreSection> _parseMultiPageComicListExploreSections(
    dynamic resolved,
  ) {
    if (resolved is! List) {
      return const [];
    }
    final sections = <ExploreSection>[];
    for (final item in resolved) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final comicsRaw = map['comics'];
      if (comicsRaw is! List) {
        continue;
      }
      final comics = _parseExploreComics(comicsRaw);
      if (comics.isEmpty) {
        continue;
      }
      sections.add(
        ExploreSection(
          title: map['title']?.toString() ?? '__untitled_section__',
          comics: comics,
        ),
      );
    }
    return sections;
  }

  List<ExploreComic> _parseExploreComics(List list) {
    final sourceKey = activeSourceKey;
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
          sourceKey: sourceKey,
        ),
      );
    }
    return comics;
  }
}
