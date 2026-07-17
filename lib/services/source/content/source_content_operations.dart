import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../category/source_category_capability.dart';
import '../comic/comic_details_capability.dart';
import '../explore_capability.dart';
import '../models/source_identity.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_operations.dart';

abstract interface class SourceContentOperations {
  Future<List<ExploreSection>> loadExploreSections({bool forceRefresh = false});
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  });
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  });
  bool supportComicLikeForSource(String sourceKey);
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  });
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  });
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions();
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  });
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  });
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  });
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  });
}

class SourceContentOperationService implements SourceContentOperations {
  SourceContentOperationService({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeOperations runtimeOperations,
    required SourceExploreCapability explore,
    required SourceCategoryCapability category,
    required SourceComicDetailsCapability comicDetails,
  }) : _runtimeHost = runtimeHost,
       _runtimeOperations = runtimeOperations,
       _explore = explore,
       _category = category,
       _comicDetails = comicDetails;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeOperations _runtimeOperations;
  final SourceExploreCapability _explore;
  final SourceCategoryCapability _category;
  final SourceComicDetailsCapability _comicDetails;

  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) => _explore.load(forceRefresh: forceRefresh);
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) => _comicDetails.loadComicDetails(comicId, sourceKey: sourceKey);
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _comicDetails.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
  );
  @override
  bool supportComicLikeForSource(String sourceKey) =>
      _comicDetails.supportComicLikeForSource(sourceKey);
  @override
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) => _comicDetails.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
  );
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) =>
      _category.loadTagGroups(forceRefresh: forceRefresh, sourceKey: sourceKey);
  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() =>
      _category.loadRankingOptions();
  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) => _category.loadRankingComics(rankingOption: rankingOption, page: page);
  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) => _category.loadOptionGroupsByViewMore(viewMoreUrl: viewMoreUrl);
  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = 'mr',
    List<String>? orders,
  }) => _category.loadComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
  );

  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : _runtimeHost.normalize(sourceKey);
    await _runtimeOperations.ensureSourceInitialized(resolvedSourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    final engine = facade.js.engine;
    if (engine == null) throw Exception('source_not_initialized');
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const SearchComicsResult(comics: [], maxPage: 0);
    }
    final hasSearch = facade.js.asBool(
      engine.evaluate('!!this.__hazuki_source.search'),
    );
    final hasSearchLoad = facade.js.asBool(
      engine.evaluate('!!this.__hazuki_source.search?.load'),
    );
    if (!hasSearch || !hasSearchLoad) throw Exception('search_not_supported');
    final result = engine.evaluate(
      'this.__hazuki_source.search.load(${jsonEncode(normalizedKeyword)}, ${jsonEncode([_normalizeSearchOption(order, resolvedSourceKey)])}, ${page < 1 ? 1 : page})',
      name: 'source_search.js',
    );
    final resolved = await facade.js.resolve(result);
    if (resolved is! Map) {
      return const SearchComicsResult(comics: [], maxPage: null);
    }
    final map = Map<String, dynamic>.from(resolved);
    final comicsRaw = map['comics'];
    final comics = comicsRaw is List
        ? _parseExploreComics(comicsRaw, sourceKey: resolvedSourceKey)
        : const <ExploreComic>[];
    final maxPageRaw = map['maxPage'];
    final maxPage = switch (maxPageRaw) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(maxPageRaw?.toString() ?? ''),
    };
    return SearchComicsResult(comics: comics, maxPage: maxPage);
  }

  List<ExploreComic> _parseExploreComics(
    List list, {
    required String sourceKey,
  }) => list
      .whereType<Map>()
      .map((comic) {
        final map = Map<String, dynamic>.from(comic);
        return ExploreComic(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          subTitle: (map['subTitle'] ?? map['subtitle'] ?? '').toString(),
          cover: map['cover']?.toString() ?? '',
          sourceKey: sourceKey,
        );
      })
      .toList(growable: false);

  String _normalizeSearchOption(String order, String sourceKey) {
    final normalized = order.trim();
    if (isHazukiCopyMangaSourceKey(sourceKey)) {
      return const {'-', 'name', 'author', 'local'}.contains(normalized)
          ? normalized
          : '-';
    }
    if (isHazukiPicacgSourceKey(sourceKey)) {
      return const {'dd', 'da', 'ld', 'vd'}.contains(normalized)
          ? normalized
          : 'dd';
    }
    return normalized.isEmpty ? 'mr' : normalized;
  }
}
