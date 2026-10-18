import 'dart:convert';
import 'source_cloud_reading.dart';

import '../../../models/hazuki_models.dart';
import '../category/source_category_capability.dart';
import '../comic/comic_details_capability.dart';
import '../common/source_json_coerce.dart';
import '../explore_capability.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_operations.dart';
import '../plugins/source_sort_options.dart';
import '../models/source_contract_models.dart';
import '../gateways/source_content_gateways.dart';

abstract interface class SourceContentOperations {
  Future<List<SourceDailyRecommendationItem>> loadDailyRecommendations({
    String sourceKey = '',
  });
  Future<List<ExploreSection>> loadExploreSections({bool forceRefresh = false});
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    bool forceRefresh = false,
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
    String order = '',
    List<String>? orders,
  });
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = '',
    String sourceKey = '',
  });
}

class SourceContentOperationService
    implements
        SourceContentOperations,
        SourceReadingProgressGateway,
        SourceCloudReadingGateway,
        SourceCloudReadingEvents {
  SourceContentOperationService({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeOperations runtimeOperations,
    required SourceExploreCapability explore,
    required SourceCategoryCapability category,
    required SourceComicDetailsCapability comicDetails,
    this.loadCloudReadRuntime,
  }) : _runtimeHost = runtimeHost,
       _runtimeOperations = runtimeOperations,
       _explore = explore,
       _category = category,
       _comicDetails = comicDetails {
    _cloud;
  }

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeOperations _runtimeOperations;
  final SourceExploreCapability _explore;
  final SourceCategoryCapability _category;
  final SourceComicDetailsCapability _comicDetails;
  final Map<String, Future<void>> _progressQueues = {};
  final Future<void> Function(SourceRuntimeHandle)? loadCloudReadRuntime;
  late final _cloud = SourceCloudReadingCapability(
    _runtimeHost,
    _runtimeOperations,
    loadReadRuntime: loadCloudReadRuntime,
  );
  void dispose() => _cloud.dispose();
  @override
  void addListener(void Function() listener) => _cloud.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      _cloud.removeListener(listener);
  @override
  Future<bool> usesCloudReading(String sourceKey) =>
      _cloud.usesCloudReading(sourceKey);
  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId,
  ) => _cloud.loadCloudReadingProgress(sourceKey, comicId);
  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(String sourceKey) =>
      _cloud.refreshCloudReadingHistory(sourceKey);

  @override
  Future<void> reportReadingProgress(
    Map<String, Object> progress, {
    required String sourceKey,
  }) {
    if (!_runtimeHost.runtimeRegistry.isAllowedSourceKey(sourceKey)) {
      return Future.value();
    }
    final handle = _runtimeHost.handleFor(sourceKey);
    final account = handle.session.loginIdentity;
    if (account == null) return Future.value();
    final snapshot = Map<String, Object>.from(progress);
    final previous = _progressQueues[sourceKey] ?? Future<void>.value();
    final next = previous
        .then((_) async {
          if (handle.isDisposed ||
              !_runtimeHost.isCurrentHandle(handle) ||
              !_runtimeHost.runtimeRegistry.isAllowedSourceKey(sourceKey) ||
              handle.session.loginIdentity != account) {
            return;
          }
          final engine = handle.runtime.engine;
          if (engine == null ||
              engine.evaluate(
                    'typeof this.__hazuki_source.comic?.onReadingProgress === "function"',
                  ) !=
                  true) {
            return;
          }
          await handle.facade.js.resolve(
            engine.invoke(
              '(progress) => this.__hazuki_source.comic.onReadingProgress(progress)',
              [snapshot],
            ),
          );
        })
        .catchError((Object _) {});
    _progressQueues[sourceKey] = next;
    return next.whenComplete(() {
      if (identical(_progressQueues[sourceKey], next)) {
        _progressQueues.remove(sourceKey);
      }
    });
  }

  @override
  Future<List<SourceDailyRecommendationItem>> loadDailyRecommendations({
    String sourceKey = '',
  }) async {
    final key = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : _runtimeHost.normalize(sourceKey);
    await _runtimeOperations.ensureSourceInitialized(key);
    final facade = _runtimeHost.handleFor(key).facade;
    final engine = facade.js.engine;
    if (engine == null) throw StateError('source_not_initialized');
    final raw = await facade.js.resolve(
      engine.evaluate('globalThis.__hazuki_source.dailyRecommendation.load()'),
    );
    if (raw is! List) {
      throw const FormatException('plugin_invalid_daily_recommendations');
    }
    final items = <SourceDailyRecommendationItem>[];
    for (final item in raw) {
      if (item is! Map ||
          item['id'] is! String ||
          (item['id'] as String).trim().isEmpty ||
          item['title'] is! String ||
          (item['title'] as String).trim().isEmpty) {
        throw const FormatException('plugin_invalid_daily_recommendation');
      }
      for (final field in [
        'cover',
        'imageUrl',
        'bannerTitle',
        'caption',
        'subTitle',
      ]) {
        if (item[field] != null && item[field] is! String) {
          throw const FormatException('plugin_invalid_daily_recommendation');
        }
      }
      final cover = (item['cover'] as String? ?? '').trim();
      final imageUrl = (item['imageUrl'] as String? ?? '').trim();
      if (cover.isEmpty && imageUrl.isEmpty) {
        throw const FormatException('plugin_recommendation_image_missing');
      }
      items.add(
        SourceDailyRecommendationItem(
          comic: ExploreComic(
            id: (item['id'] as String).trim(),
            title: (item['title'] as String).trim(),
            sourceKey: key,
            cover: cover,
            subTitle: item['subTitle'] as String? ?? '',
            tags: jsAsStringList(item['tags']),
          ),
          caption: item['caption'] as String? ?? '',
          imageUrl: imageUrl,
          bannerTitle: item['bannerTitle'] as String? ?? '',
        ),
      );
    }
    return List.unmodifiable(items);
  }

  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) => _explore.load(forceRefresh: forceRefresh);
  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) => _comicDetails.loadComicDetails(
    comicId,
    sourceKey: sourceKey,
    forceRefresh: forceRefresh,
  );
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
    String order = '',
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
    String order = '',
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
          tags: jsAsStringList(map['tags']),
        );
      })
      .toList(growable: false);

  String _normalizeSearchOption(String order, String sourceKey) {
    return normalizeSourceSearchOrder(
      order,
      _runtimeHost.runtimeRegistry.presentationFor(sourceKey),
    );
  }
}
