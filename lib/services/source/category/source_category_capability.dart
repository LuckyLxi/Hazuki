import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../common/source_prefs_keys.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import '../explore_capability.dart';

typedef SourceComicParser =
    List<ExploreComic> Function(List comics, {String sourceKey});

/// Loads category data using explicit source-runtime collaborators.
class SourceCategoryCapability {
  SourceCategoryCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceTextTranslator translateSourceText,
    required SourceComicParser parseExploreComics,
  }) : _runtimeHost = runtimeHost,
       _translateSourceText = translateSourceText,
       _parseExploreComics = parseExploreComics;

  final SourceRuntimeHost _runtimeHost;
  final SourceTextTranslator _translateSourceText;
  final SourceComicParser _parseExploreComics;

  Future<List<CategoryTagGroup>> loadTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : _runtimeHost.normalize(sourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    await facade.ensureInitialized();
    final startedAt = DateTime.now();

    if (!forceRefresh) {
      final memoryCached = facade.cache.getCategoryTagGroupsFromMemoryCache(
        SourcePrefsKeys.discoverCacheTtl,
      );
      if (memoryCached != null) {
        _logTagTiming(
          'Source category tags loaded from memory cache',
          startedAt: startedAt,
          content: {
            'groupCount': memoryCached.length,
            'tagCount': memoryCached.fold<int>(
              0,
              (sum, group) => sum + group.tags.length,
            ),
          },
          targetFacade: facade,
        );
        return memoryCached;
      }
    } else {
      facade.cache.clearCategoryTagGroupsMemoryCache();
    }

    final engine = facade.js.engine;
    if (engine == null) {
      _logTagTiming(
        'Source category tags load failed',
        startedAt: startedAt,
        level: 'error',
        content: {'error': 'source_not_initialized'},
        targetFacade: facade,
      );
      throw Exception('source_not_initialized');
    }

    final hasCategoryEvaluateStartedAt = DateTime.now();
    final hasCategory = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.category'),
    );
    _logTagTiming(
      'Source category tags availability evaluate finished',
      startedAt: hasCategoryEvaluateStartedAt,
      content: {'hasCategory': hasCategory},
      targetFacade: facade,
    );
    if (!hasCategory) {
      _logTagTiming(
        'Source category tags loaded',
        startedAt: startedAt,
        content: {'groupCount': 0, 'tagCount': 0, 'hasCategory': false},
        targetFacade: facade,
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
          if (itemType !== 'search' && itemType !== 'category') continue;
          const name = String(part.name ?? '').trim();
          const rawCategories = Array.isArray(part.categories) ? part.categories : [];
          const rawParams = Array.isArray(part.categoryParams) ? part.categoryParams : [];
          const tags = rawCategories
            .map((e) => String(e ?? '').trim())
            .filter((e) => e.length > 0);
          const params = rawCategories.map((_, index) => {
            const value = rawParams[index];
            if (value === undefined || value === null) return null;
            return String(value);
          });
          if (!name || tags.length === 0) continue;
          groups.push({ name, tags, params, itemType });
        }
        return groups;
      })()''', name: 'source_category_tag_groups.js');
    _logTagTiming(
      'Source category tags evaluate finished',
      startedAt: evaluateStartedAt,
      targetFacade: facade,
    );

    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! List) {
      _logTagTiming(
        'Source category tags loaded',
        startedAt: startedAt,
        content: {
          'groupCount': 0,
          'tagCount': 0,
          'resultType': resolved.runtimeType.toString(),
        },
        targetFacade: facade,
      );
      return const [];
    }

    final groups = <CategoryTagGroup>[];
    for (final item in resolved) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final name = map['name']?.toString().trim() ?? '';
      final itemType = map['itemType']?.toString().trim() ?? 'search';
      final tagsRaw = map['tags'];
      if (name.isEmpty || tagsRaw is! List) continue;

      final tags = tagsRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (tags.isEmpty) continue;

      final params = <String?>[];
      if (map['params'] case final List paramsRaw) {
        for (final item in paramsRaw) {
          params.add(item?.toString());
        }
      }
      groups.add(
        CategoryTagGroup(
          name: _translateSourceText(name, sourceKey: resolvedSourceKey),
          tags: tags,
          params: params,
          itemType: itemType,
        ),
      );
    }

    final cached = List<CategoryTagGroup>.unmodifiable(
      groups.map(
        (group) => CategoryTagGroup(
          name: group.name,
          tags: List<String>.unmodifiable(group.tags),
          params: List<String?>.unmodifiable(group.params),
          itemType: group.itemType,
        ),
      ),
    );
    facade.cache.putCategoryTagGroupsInMemoryCache(cached);
    _logTagTiming(
      'Source category tags loaded',
      startedAt: startedAt,
      content: {
        'groupCount': cached.length,
        'tagCount': cached.fold<int>(
          0,
          (sum, group) => sum + group.tags.length,
        ),
      },
      targetFacade: facade,
    );
    return cached;
  }

  Future<List<CategoryRankingOption>> loadRankingOptions() async {
    final facade = _runtimeHost.activeHandle.facade;
    await facade.ensureInitialized();
    final engine = facade.js.engine;
    if (engine == null) throw Exception('source_not_initialized');

    final dynamic result = engine.evaluate('''(() => {
        const rawOptions = this.__hazuki_source.categoryComics?.ranking?.options;
        if (!Array.isArray(rawOptions)) return [];
        return rawOptions.map((item) => {
          const text = String(item ?? '').trim();
          if (!text) return null;
          const idx = text.indexOf('-');
          if (idx <= 0 || idx >= text.length - 1) return { value: text, label: text };
          return { value: text.slice(0, idx), label: text.slice(idx + 1) };
        }).filter(Boolean);
      })()''', name: 'source_category_ranking_options.js');
    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! List) return const [];

    final options = <CategoryRankingOption>[];
    for (final item in resolved) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final value = map['value']?.toString().trim() ?? '';
      final label = map['label']?.toString().trim() ?? '';
      if (value.isEmpty || label.isEmpty) continue;
      options.add(
        CategoryRankingOption(value: value, label: _translateSourceText(label)),
      );
    }
    return options;
  }

  Future<CategoryComicsResult> loadRankingComics({
    required String rankingOption,
    required int page,
  }) async {
    final facade = _runtimeHost.activeHandle.facade;
    await facade.ensureInitialized();
    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('婕敾婧愬皻鏈垵濮嬪寲瀹屾垚');
    }

    final option = rankingOption.trim();
    if (option.isEmpty) {
      throw Exception('鎺掕姒滃弬鏁颁笉鑳戒负绌?');
    }
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.categoryComics.ranking.load(${jsonEncode(option)}, ${_normalizePage(page)})',
      name: 'source_category_ranking_load.js',
    );
    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! Map) {
      return const CategoryComicsResult(comics: [], maxPage: null);
    }
    return _parseCategoryComicsResult(Map<String, dynamic>.from(resolved));
  }

  Future<List<CategoryRankingOption>> loadRankingOptionsByViewMore({
    required String viewMoreUrl,
  }) async {
    final groups = await loadOptionGroupsByViewMore(viewMoreUrl: viewMoreUrl);
    return groups.isEmpty ? const [] : groups.first;
  }

  Future<List<List<CategoryRankingOption>>> loadOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) async {
    final facade = _runtimeHost.activeHandle.facade;
    await facade.ensureInitialized();
    final engine = facade.js.engine;
    if (engine == null) throw Exception('source_not_initialized');
    if (parseExploreViewMoreIndex(viewMoreUrl) != null) return const [];

    final parsed = parseCategoryViewMoreUrl(viewMoreUrl);
    final categoryJson = jsonEncode(parsed.category);
    final paramJson = parsed.param == null ? 'null' : jsonEncode(parsed.param);
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
              const showWhen = Array.isArray(group.showWhen) ? group.showWhen.map((e) => String(e ?? '')) : null;
              const notShowWhen = Array.isArray(group.notShowWhen) ? group.notShowWhen.map((e) => String(e ?? '')) : null;
              const keys = [String(category ?? ''), String(param ?? '')];
              const showMatch = !showWhen || keys.some((key) => showWhen.includes(key));
              const hideMatch = !!notShowWhen && keys.some((key) => notShowWhen.includes(key));
              return showMatch && !hideMatch;
            });
          })()''', name: 'source_category_view_more_option_list.js');
    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! List) return const [];

    final groups = <List<CategoryRankingOption>>[];
    for (final group in resolved) {
      if (group is! Map) continue;
      final rawOptions = Map<String, dynamic>.from(group)['options'];
      if (rawOptions is! List) continue;
      final options = _parseRankingOptionsList(rawOptions);
      if (options.isNotEmpty) groups.add(options);
    }
    return groups;
  }

  Future<CategoryComicsResult> loadComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) async {
    final facade = _runtimeHost.activeHandle.facade;
    await facade.ensureInitialized();
    final engine = facade.js.engine;
    if (engine == null) throw Exception('source_not_initialized');

    final normalizedPage = _normalizePage(page);
    final normalizedOrder = order.trim().isEmpty ? 'mr' : order.trim();
    final normalizedOrders = orders == null || orders.isEmpty
        ? <String>[normalizedOrder]
        : orders
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
    final optionsJson = jsonEncode(
      normalizedOrders.isEmpty ? <String>[normalizedOrder] : normalizedOrders,
    );

    final exploreIndex = parseExploreViewMoreIndex(viewMoreUrl);
    final dynamic result;
    if (exploreIndex != null) {
      result = engine.evaluate('''(() => {
          const section = this.__hazuki_source.explore?.[$exploreIndex];
          if (!section || section.type !== "multiPageComicList" || typeof section.load !== "function") return null;
          return Promise.resolve(section.load($normalizedPage)).then((value) => ({ title: section.title ?? "__untitled_section__", ...(value ?? {}) }));
        })()''', name: 'source_explore_view_more_load.js');
    } else {
      final parsed = parseCategoryViewMoreUrl(viewMoreUrl);
      final categoryJson = jsonEncode(parsed.category);
      final paramJson = parsed.param == null
          ? 'null'
          : jsonEncode(parsed.param);
      result = engine.evaluate(
        'this.__hazuki_source.categoryComics.load($categoryJson, $paramJson, $optionsJson, $normalizedPage)',
        name: 'source_category_view_more_load.js',
      );
    }
    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! Map) {
      return const CategoryComicsResult(comics: [], maxPage: null);
    }
    return _parseCategoryComicsResult(Map<String, dynamic>.from(resolved));
  }

  @visibleForTesting
  static ({String category, String? param}) parseCategoryViewMoreUrl(
    String rawUrl,
  ) {
    final raw = rawUrl.trim();
    if (!raw.startsWith('category:')) return (category: raw, param: null);
    final body = raw.substring('category:'.length);
    final atIndex = body.indexOf('@');
    if (atIndex < 0) return (category: body, param: null);
    final param = body.substring(atIndex + 1);
    return (
      category: body.substring(0, atIndex),
      param: param.isEmpty ? null : param,
    );
  }

  @visibleForTesting
  static int? parseExploreViewMoreIndex(String rawUrl) {
    final raw = rawUrl.trim();
    if (!raw.startsWith('explore:')) return null;
    final index = int.tryParse(raw.substring('explore:'.length));
    return index == null || index < 0 ? null : index;
  }

  @visibleForTesting
  CategoryComicsResult parseCategoryComicsResultForTesting(
    Map<String, dynamic> map,
  ) => _parseCategoryComicsResult(map);

  @visibleForTesting
  static int normalizePageForTesting(int page) => _normalizePage(page);

  void _logTagTiming(
    String title, {
    required DateTime startedAt,
    Map<String, Object?>? content,
    String level = 'info',
    HazukiSourceFacade? targetFacade,
  }) {
    (targetFacade ?? _runtimeHost.activeHandle.facade).addApplicationLog(
      level: level,
      title: title,
      source: 'source_category_tags',
      content: {
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        ...?content,
      },
    );
  }

  List<CategoryRankingOption> _parseRankingOptionsList(List rawOptions) {
    final options = <CategoryRankingOption>[];
    for (final item in rawOptions) {
      final text = item?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      final index = text.indexOf('-');
      options.add(
        index <= 0 || index >= text.length - 1
            ? CategoryRankingOption(
                value: text,
                label: _translateSourceText(text),
              )
            : CategoryRankingOption(
                value: text.substring(0, index),
                label: _translateSourceText(text.substring(index + 1)),
              ),
      );
    }
    return options;
  }

  CategoryComicsResult _parseCategoryComicsResult(Map<String, dynamic> map) {
    final comicsRaw = map['comics'];
    return CategoryComicsResult(
      comics: comicsRaw is List
          ? _parseExploreComics(comicsRaw)
          : const <ExploreComic>[],
      maxPage: _parseSourcePageCount(map['maxPage']),
    );
  }

  static int _normalizePage(int page) => page < 1 ? 1 : page;

  static int? _parseSourcePageCount(dynamic value) => switch (value) {
    int value => value,
    num value => value.toInt(),
    _ => int.tryParse(value?.toString() ?? ''),
  };
}
