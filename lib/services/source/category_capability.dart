part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCategoryCapability on HazukiSourceService {
  Future<List<CategoryTagGroup>> loadCategoryTagGroups() async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final hasCategory = _asBool(
      engine.evaluate('!!this.__hazuki_source.category'),
    );
    if (!hasCategory) {
      return const [];
    }

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
