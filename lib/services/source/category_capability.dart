part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCategoryCapability on HazukiSourceService {
  void _logCategoryTagTiming(
    String title, {
    required DateTime startedAt,
    Map<String, Object?>? content,
    String level = 'info',
  }) {
    facade.addApplicationLog(
      level: level,
      title: title,
      source: 'source_category_tags',
      content: {
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        if (content != null) ...content,
      },
    );
  }

  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
  }) async {
    final facade = this.facade;
    await facade.ensureInitialized();

    final startedAt = DateTime.now();

    if (!forceRefresh) {
      final memoryCached = facade.cache.getCategoryTagGroupsFromMemoryCache(
        HazukiSourceService._discoverCacheTtl,
      );
      if (memoryCached != null) {
        _logCategoryTagTiming(
          'Source category tags loaded from memory cache',
          startedAt: startedAt,
          content: {
            'groupCount': memoryCached.length,
            'tagCount': memoryCached.fold<int>(
              0,
              (sum, group) => sum + group.tags.length,
            ),
          },
        );
        return memoryCached;
      }
    } else {
      facade.cache.clearCategoryTagGroupsMemoryCache();
    }

    final engine = facade.js.engine;
    if (engine == null) {
      _logCategoryTagTiming(
        'Source category tags load failed',
        startedAt: startedAt,
        level: 'error',
        content: {'error': 'source_not_initialized'},
      );
      throw Exception('source_not_initialized');
    }

    final hasCategoryEvaluateStartedAt = DateTime.now();
    final hasCategory = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.category'),
    );
    _logCategoryTagTiming(
      'Source category tags availability evaluate finished',
      startedAt: hasCategoryEvaluateStartedAt,
      content: {'hasCategory': hasCategory},
    );
    if (!hasCategory) {
      _logCategoryTagTiming(
        'Source category tags loaded',
        startedAt: startedAt,
        content: {'groupCount': 0, 'tagCount': 0, 'hasCategory': false},
      );
      return const [];
    }

    final evaluateStartedAt = DateTime.now();
    final dynamic result = engine.evaluate('''(() => {
        const category = this.__hazuki_source.category;
        const parts = Array.isArray(category?.parts) ? category.parts : [];
        const groups = [];
        for (const part of parts) {
          if (!part || typeof part !== 'object') continue;
          const itemType = String(part.itemType ?? '').trim();
          if (itemType !== 'search') continue;
          const name = String(part.name ?? '').trim();
          const rawCategories = Array.isArray(part.categories) ? part.categories : [];
          const tags = rawCategories
            .map((e) => String(e ?? '').trim())
            .filter((e) => e.length > 0);
          if (!name || tags.length === 0) continue;
          groups.push({ name, tags });
        }
        return groups;
      })()''', name: 'source_category_tag_groups.js');
    _logCategoryTagTiming(
      'Source category tags evaluate finished',
      startedAt: evaluateStartedAt,
    );

    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! List) {
      _logCategoryTagTiming(
        'Source category tags loaded',
        startedAt: startedAt,
        content: {
          'groupCount': 0,
          'tagCount': 0,
          'resultType': resolved.runtimeType.toString(),
        },
      );
      return const [];
    }

    final groups = <CategoryTagGroup>[];
    for (final item in resolved) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final name = map['name']?.toString().trim() ?? '';
      final tagsRaw = map['tags'];
      if (name.isEmpty || tagsRaw is! List) {
        continue;
      }

      final tags = tagsRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (tags.isEmpty) {
        continue;
      }

      groups.add(CategoryTagGroup(name: name, tags: tags));
    }

    final cached = List<CategoryTagGroup>.unmodifiable(
      groups.map(
        (group) => CategoryTagGroup(
          name: group.name,
          tags: List<String>.unmodifiable(group.tags),
        ),
      ),
    );
    facade.cache.putCategoryTagGroupsInMemoryCache(cached);
    _logCategoryTagTiming(
      'Source category tags loaded',
      startedAt: startedAt,
      content: {
        'groupCount': cached.length,
        'tagCount': cached.fold<int>(
          0,
          (sum, group) => sum + group.tags.length,
        ),
      },
    );
    return cached;
  }

  ({String category, String? param}) _parseCategoryViewMoreUrl(String rawUrl) {
    final raw = rawUrl.trim();
    String category;
    String? param;

    if (raw.startsWith('category:')) {
      final body = raw.substring('category:'.length);
      final atIdx = body.indexOf('@');
      if (atIdx >= 0) {
        category = body.substring(0, atIdx);
        param = body.substring(atIdx + 1);
        if (param.isEmpty) {
          param = null;
        }
      } else {
        category = body;
      }
    } else {
      category = raw;
    }

    return (category: category, param: param);
  }

  List<CategoryRankingOption> _parseCategoryRankingOptionsList(
    List rawOptions,
  ) {
    final options = <CategoryRankingOption>[];
    for (final item in rawOptions) {
      final text = item?.toString().trim() ?? '';
      if (text.isEmpty) {
        continue;
      }
      final idx = text.indexOf('-');
      if (idx <= 0 || idx >= text.length - 1) {
        options.add(CategoryRankingOption(value: text, label: text));
      } else {
        options.add(
          CategoryRankingOption(
            value: text.substring(0, idx),
            label: text.substring(idx + 1),
          ),
        );
      }
    }
    return options;
  }

  CategoryComicsResult _parseCategoryComicsResult(Map<String, dynamic> map) {
    final comicsRaw = map['comics'];
    final comics = comicsRaw is List
        ? _parseExploreComics(comicsRaw)
        : const <ExploreComic>[];

    final maxPageRaw = map['maxPage'];
    final maxPage = switch (maxPageRaw) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(maxPageRaw?.toString() ?? ''),
    };

    return CategoryComicsResult(comics: comics, maxPage: maxPage);
  }
}
