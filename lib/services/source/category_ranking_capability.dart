part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCategoryRankingCapability on HazukiSourceService {
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() async {
    final facade = this.facade;
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final dynamic result = engine.evaluate('''(() => {
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
      })()''', name: 'source_category_ranking_options.js');

    final dynamic resolved = await facade.js.resolve(result);
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

  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) async {
    final facade = this.facade;
    await facade.ensureInitialized();

    final engine = facade.js.engine;
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

    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! Map) {
      return const CategoryComicsResult(comics: [], maxPage: null);
    }

    return _parseCategoryComicsResult(Map<String, dynamic>.from(resolved));
  }
}
