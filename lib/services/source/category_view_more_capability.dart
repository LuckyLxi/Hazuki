part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCategoryViewMoreCapability on HazukiSourceService {
  Future<List<CategoryRankingOption>> loadCategoryRankingOptionsByViewMore({
    required String viewMoreUrl,
  }) async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final parsed = _parseCategoryViewMoreUrl(viewMoreUrl);
    final categoryJson = jsonEncode(parsed.category);
    final paramJson = parsed.param != null ? jsonEncode(parsed.param) : 'null';

    dynamic resolved;
    try {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.categoryComics.optionLoader($categoryJson, $paramJson)',
        name: 'source_category_view_more_options.js',
      );

      resolved = await _awaitJsResult(result);
      if (resolved is! List) {
        return const [];
      }

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
          return options;
        }
      }

      return const [];
    } catch (e) {
      rethrow;
    }
  }

  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
  }) async {
    await ensureInitialized();

    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final parsed = _parseCategoryViewMoreUrl(viewMoreUrl);
    final normalizedPage = page < 1 ? 1 : page;
    final normalizedOrder = order.trim().isEmpty ? 'mr' : order.trim();
    final categoryJson = jsonEncode(parsed.category);
    final paramJson = parsed.param != null ? jsonEncode(parsed.param) : 'null';
    final optionsJson = jsonEncode([normalizedOrder]);

    try {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.categoryComics.load($categoryJson, $paramJson, $optionsJson, $normalizedPage)',
        name: 'source_category_view_more_load.js',
      );

      final dynamic resolved = await _awaitJsResult(result);
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
