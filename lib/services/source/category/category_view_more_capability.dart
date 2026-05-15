part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceCategoryViewMoreCapability on HazukiSourceService {
  Future<List<CategoryRankingOption>> loadCategoryRankingOptionsByViewMore({
    required String viewMoreUrl,
  }) async {
    final groups = await loadCategoryOptionGroupsByViewMore(
      viewMoreUrl: viewMoreUrl,
    );
    return groups.isEmpty ? const <CategoryRankingOption>[] : groups.first;
  }

  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) async {
    final facade = this.facade;
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final parsed = _parseCategoryViewMoreUrl(viewMoreUrl);
    final categoryJson = jsonEncode(parsed.category);
    final paramJson = parsed.param != null ? jsonEncode(parsed.param) : 'null';

    dynamic resolved;
    try {
      final hasOptionLoader = facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.categoryComics?.optionLoader'),
      );
      final dynamic result = hasOptionLoader
          ? engine.evaluate(
              'this.__hazuki_source.categoryComics.optionLoader($categoryJson, $paramJson)',
              name: 'source_category_view_more_options.js',
            )
          : engine.evaluate('''(() => {
              const category = $categoryJson;
              const param = $paramJson;
              const raw = this.__hazuki_source.categoryComics?.optionList;
              if (!Array.isArray(raw)) return [];
              return raw.filter((group) => {
                if (!group || typeof group !== 'object') return false;
                const showWhen = Array.isArray(group.showWhen)
                  ? group.showWhen.map((e) => String(e ?? ''))
                  : null;
                const notShowWhen = Array.isArray(group.notShowWhen)
                  ? group.notShowWhen.map((e) => String(e ?? ''))
                  : null;
                const keys = [String(category ?? ''), String(param ?? '')];
                const showMatch = !showWhen || keys.some((key) => showWhen.includes(key));
                const hideMatch = !!notShowWhen && keys.some((key) => notShowWhen.includes(key));
                return showMatch && !hideMatch;
              });
            })()''', name: 'source_category_view_more_option_list.js');

      resolved = await facade.js.resolve(result);
      if (resolved is! List) {
        return const [];
      }

      final groups = <List<CategoryRankingOption>>[];
      for (final group in resolved) {
        if (group is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(group);
        final rawOptions = map['options'];
        if (rawOptions is! List) {
          continue;
        }

        final options = _parseCategoryRankingOptionsList(rawOptions);
        if (options.isNotEmpty) {
          groups.add(options);
        }
      }

      return groups;
    } catch (e) {
      rethrow;
    }
  }

  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) async {
    final facade = this.facade;
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final parsed = _parseCategoryViewMoreUrl(viewMoreUrl);
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedOrder = order.trim().isEmpty ? 'mr' : order.trim();
    final normalizedOrders = orders == null || orders.isEmpty
        ? <String>[normalizedOrder]
        : orders
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
    final categoryJson = jsonEncode(parsed.category);
    final paramJson = parsed.param != null ? jsonEncode(parsed.param) : 'null';
    final optionsJson = jsonEncode(
      normalizedOrders.isEmpty ? <String>[normalizedOrder] : normalizedOrders,
    );

    try {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.categoryComics.load($categoryJson, $paramJson, $optionsJson, $normalizedPage)',
        name: 'source_category_view_more_load.js',
      );

      final dynamic resolved = await facade.js.resolve(result);
      if (resolved is! Map) {
        return const CategoryComicsResult(comics: [], maxPage: null);
      }

      final parsedResult = _parseCategoryComicsResult(
        Map<String, dynamic>.from(resolved),
      );
      return parsedResult;
    } catch (e) {
      rethrow;
    }
  }
}
