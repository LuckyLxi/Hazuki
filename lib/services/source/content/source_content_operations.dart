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
import '../runtime/source_script_engine.dart';
import '../models/source_script_execution.dart';
import '../debug/debug_log_internals.dart';
import '../debug/source_task_log_recorder.dart';
import '../models/source_task.dart';
import '../runtime/source_task_registry.dart';
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
    SourceTaskOrigin? taskOrigin,
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
  final SourceTaskRegistry _searchTasks = SourceTaskRegistry();
  List<SourceTaskSnapshot> get activeSearchTasks => _searchTasks.activeTasks;
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
              await engine.evaluate(
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
    return facade.handle.runOperation(() async {
      final engine = facade.js.engine;
      if (engine == null) throw StateError('source_not_initialized');
      final raw = await facade.js.resolve(
        engine.evaluate(
          'globalThis.__hazuki_source.dailyRecommendation.load()',
        ),
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
    });
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
    SourceTaskOrigin? taskOrigin,
  }) async {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : _runtimeHost.normalize(sourceKey);
    final normalizedKeyword = keyword.trim();
    final recorder = SourceTaskLogRecorder(_runtimeHost.logStore);
    return _searchTasks.run(
      pluginId: resolvedSourceKey,
      pluginVersion: _runtimeHost.catalog
          .where((source) => source.normalizedKey == resolvedSourceKey)
          .firstOrNull
          ?.pluginVersion,
      method: 'search.load',
      origin: taskOrigin,
      observe: (task, event, disposition, error, stack) => recorder.record(
        task,
        event,
        disposition,
        error,
        stack,
        sensitiveValues: [keyword, normalizedKeyword],
      ),
      operation: (task) async {
        await _runtimeOperations.ensureSourceInitialized(resolvedSourceKey);
        final handle = _runtimeHost.handleFor(resolvedSourceKey);
        // Acquire before any script execution, including synchronous checks.
        return handle.runOperation(() async {
          final facade = handle.facade;
          final engine = facade.js.engine;
          if (engine == null) throw Exception('source_not_initialized');
          task.bindRuntime(
            runtimeId: engine.runtimeId,
            pluginVersion: facade.sourceMeta?.version,
          );
          return _searchWithEngine(
            engine,
            normalizedKeyword,
            page,
            order,
            resolvedSourceKey,
            SourceScriptExecution.fromTask(task.snapshot),
          );
        });
      },
    );
  }

  Future<SearchComicsResult> _searchWithEngine(
    SourceScriptEngine engine,
    String normalizedKeyword,
    int page,
    String order,
    String resolvedSourceKey,
    SourceScriptExecution execution,
  ) async {
    if (normalizedKeyword.isEmpty) {
      return const SearchComicsResult(comics: [], maxPage: 0);
    }
    final hasSearch = jsAsBool(
      await engine.evaluate(
        '!!this.__hazuki_source.search',
        execution: execution,
      ),
    );
    final hasSearchLoad = jsAsBool(
      await engine.evaluate(
        '!!this.__hazuki_source.search?.load',
        execution: execution,
      ),
    );
    if (!hasSearch || !hasSearchLoad) throw Exception('search_not_supported');
    final result = await engine.evaluate(
      'this.__hazuki_source.search.load(${jsonEncode(normalizedKeyword)}, ${jsonEncode([_normalizeSearchOption(order, resolvedSourceKey)])}, ${page < 1 ? 1 : page})',
      name: 'source_search.js',
      execution: execution,
    );
    final resolved = await awaitJsResult(result);
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
