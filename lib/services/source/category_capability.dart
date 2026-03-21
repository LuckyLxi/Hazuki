part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCategoryCapability on HazukiSourceService {
  Future<List<CategoryTagGroup>> loadCategoryTagGroups() async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final hasCategory = _asBool(engine.evaluate('!!this.__hazuki_source.category'));
    if (!hasCategory) {
      return const [];
    }

    final dynamic result = engine.evaluate(
      '''(() => {
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
      })()''',
      name: 'source_category_tag_groups.js',
    );

    final dynamic resolved = await _awaitJsResult(result);
    if (resolved is! List) {
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

    return groups;
  }

  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final dynamic result = engine.evaluate(
      '''(() => {
        const rawOptions = this.__hazuki_source.categoryComics?.ranking?.options;
        if (!Array.isArray(rawOptions)) {
          return [];
        }
        return rawOptions.map((item) => {
          const text = String(item ?? '').trim();
          if (!text) {
            return null;
          }
          const idx = text.indexOf('-');
          if (idx <= 0 || idx >= text.length - 1) {
            return { value: text, label: text };
          }
          return {
            value: text.slice(0, idx),
            label: text.slice(idx + 1),
          };
        }).filter(Boolean);
      })()''',
      name: 'source_category_ranking_options.js',
    );

    final dynamic resolved = await _awaitJsResult(result);
    if (resolved is! List) {
      return const [];
    }

    final options = <CategoryRankingOption>[];
    for (final item in resolved) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final value = map['value']?.toString().trim() ?? '';
      final label = map['label']?.toString().trim() ?? '';
      if (value.isEmpty || label.isEmpty) {
        continue;
      }
      options.add(CategoryRankingOption(value: value, label: label));
    }

    return options;
  }

  Future<List<CategoryRankingOption>> loadCategoryRankingOptionsByViewMore(
      {required String viewMoreUrl}) async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final raw = viewMoreUrl.trim();
    String category;
    String? param;

    if (raw.startsWith('category:')) {
      final body = raw.substring('category:'.length);
      final atIdx = body.indexOf('@');
      if (atIdx >= 0) {
        category = body.substring(0, atIdx);
        param = body.substring(atIdx + 1);
        if (param.isEmpty) param = null;
      } else {
        category = body;
      }
    } else {
      category = raw;
    }

    final categoryJson = jsonEncode(category);
    final paramJson = param != null ? jsonEncode(param) : 'null';
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.categoryComics.optionLoader($categoryJson, $paramJson)',
      name: 'source_category_view_more_options.js',
    );

    final dynamic resolved = await _awaitJsResult(result);
    if (resolved is! List) {
      return const [];
    }

    final options = <CategoryRankingOption>[];
    for (final group in resolved) {
      if (group is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(group);
      final rawOptions = map['options'];
      if (rawOptions is! List) {
        continue;
      }

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
      if (options.isNotEmpty) {
        break;
      }
    }

    return options;
  }

  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
  }) async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    // 解析 jm.js 的 viewMore 格式：
    //   "category:{title}@{param}"
    // category 是固定前缀，title 为区块标题，param 为分类参数（可与标题不同）
    final raw = viewMoreUrl.trim();
    String category;
    String? param;

    if (raw.startsWith('category:')) {
      final body = raw.substring('category:'.length);
      final atIdx = body.indexOf('@');
      if (atIdx >= 0) {
        category = body.substring(0, atIdx);
        param = body.substring(atIdx + 1);
        if (param.isEmpty) param = null;
      } else {
        category = body;
      }
    } else {
      // 未能识别格式，直接把整串作为 category
      category = raw;
    }

    final normalizedPage = page < 1 ? 1 : page;
    final normalizedOrder = order.trim().isEmpty ? 'mr' : order.trim();
    // 调用 JS 的 categoryComics.load(category, param, [order], page)
    final categoryJson = jsonEncode(category);
    final paramJson = param != null ? jsonEncode(param) : 'null';
    final optionsJson = jsonEncode([normalizedOrder]);
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.categoryComics.load($categoryJson, $paramJson, $optionsJson, $normalizedPage)',
      name: 'source_category_view_more_load.js',
    );

    final dynamic resolved = await _awaitJsResult(result);
    if (resolved is! Map) {
      return const CategoryComicsResult(comics: [], maxPage: null);
    }

    final map = Map<String, dynamic>.from(resolved);
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

  /// 排行榜漫画加载，使用排行榜专用 ranking.load JS 方法
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final option = rankingOption.trim();
    if (option.isEmpty) {
      throw Exception('排行榜参数不能为空');
    }

    final normalizedPage = page < 1 ? 1 : page;
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.categoryComics.ranking.load(${jsonEncode(option)}, $normalizedPage)',
      name: 'source_category_ranking_load.js',
    );

    final dynamic resolved = await _awaitJsResult(result);
    if (resolved is! Map) {
      return const CategoryComicsResult(comics: [], maxPage: null);
    }

    final map = Map<String, dynamic>.from(resolved);
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
