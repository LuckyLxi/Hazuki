import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import 'dart:convert';
import 'source_cloud_reading.dart';
import 'source_reading_progress_uploads.dart';

import '../../../models/hazuki_models.dart';
import '../category/source_category_capability.dart';
import '../comic/comic_details_capability.dart';
import '../comic/comic_detail_tab_capability.dart';
import '../plugins/source_detail_tabs.dart';
import '../common/source_json_coerce.dart';
import 'explore_capability.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_initialization_operations.dart';
import '../plugins/source_sort_options.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_script_engine.dart';
import '../models/source_script_execution.dart';
import '../debug/debug_log_internals.dart';
import '../debug/source_task_log_recorder.dart';
import '../gateways/source_content_gateways.dart';

class SourceContentOperations
    implements
        SourceReadingProgressGateway,
        SourceCloudReadingGateway,
        SourceCloudReadingEvents {
  SourceContentOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeInitializationOperations initialization,
    required SourceExploreCapability explore,
    required SourceCategoryCapability category,
    required SourceComicDetailsCapability comicDetails,
    SourceComicDetailTabCapability? detailTabs,
    this.loadCloudReadRuntime,
  }) : _runtimeHost = runtimeHost,
       _initialization = initialization,
       _explore = explore,
       _category = category,
       _comicDetails = comicDetails,
       _detailTabs =
           detailTabs ??
           SourceComicDetailTabCapability(runtimeHost: runtimeHost) {
    _cloud;
    _uploads;
  }

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeInitializationOperations _initialization;
  final SourceExploreCapability _explore;
  final SourceCategoryCapability _category;
  final SourceComicDetailsCapability _comicDetails;
  final SourceComicDetailTabCapability _detailTabs;
  late final _uploads = SourceReadingProgressUploads(_runtimeHost);
  List<SourceTaskSnapshot> get activeSearchTasks => _runtimeHost
      .tasks
      .activeTasks
      .where((task) => task.method == 'search.load')
      .toList(growable: false);
  final Future<void> Function(SourceRuntimeHandle)? loadCloudReadRuntime;
  late final _cloud = SourceCloudReadingCapability(
    _runtimeHost,
    _initialization,
    loadReadRuntime: loadCloudReadRuntime,
  );
  Future<void> get whenCloudReadingSettled => _cloud.whenSettled;
  Future<void> get whenSettled =>
      Future.wait([_cloud.whenSettled, _uploads.whenSettled]);
  void dispose() {
    _cloud.dispose();
    _uploads.dispose();
  }

  @override
  void addListener(void Function() listener) => _cloud.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      _cloud.removeListener(listener);
  @override
  Future<bool> usesCloudReading(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) => _cloud.usesCloudReading(sourceKey, taskOrigin: taskOrigin);
  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId, {
    SourceTaskOrigin? taskOrigin,
  }) => _cloud.loadCloudReadingProgress(
    sourceKey,
    comicId,
    taskOrigin: taskOrigin,
  );
  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) => _cloud.refreshCloudReadingHistory(sourceKey, taskOrigin: taskOrigin);

  @override
  Future<void> reportReadingProgress(
    Map<String, Object> progress, {
    required String sourceKey,
    SourceTaskOrigin? taskOrigin,
  }) => _uploads.report(progress, sourceKey, origin: taskOrigin);

  Future<List<SourceDailyRecommendationItem>> loadDailyRecommendations({
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(
      sourceKey.isEmpty ? _runtimeHost.activeSourceKey : sourceKey,
    ),
    'discover.recommendations',
    (operationContext) => _loadDailyRecommendationsTask(
      operationContext,
      sourceKey: sourceKey,
      taskOrigin: taskOrigin,
    ),
    origin: taskOrigin,
    serviceOwned: false,
  );

  Future<List<SourceDailyRecommendationItem>> _loadDailyRecommendationsTask(
    SourceOperationContext operationContext, {
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async {
    final key = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : _runtimeHost.normalize(sourceKey);
    await _initialization.ensureSourceInitialized(key);
    final facade = _runtimeHost.handleFor(key).facade;
    return facade.handle.runOperation(() async {
      final engine = facade.js.engine;
      if (engine == null) throw StateError('source_not_initialized');
      final raw = await operationContext.resolve(
        facade.js.resolve(
          operationContext.evaluate(
            engine,
            'globalThis.__hazuki_source.dailyRecommendation.load()',
          ),
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

  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) => _explore.load(forceRefresh: forceRefresh, taskOrigin: taskOrigin);
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadComicDetails(
    comicId,
    sourceKey: sourceKey,
    forceRefresh: forceRefresh,
    taskOrigin: taskOrigin,
  );
  Future<List<SourceDetailTabBlock>> loadDetailTab({
    required String comicId,
    required String tabId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _detailTabs.loadDetailTab(
    comicId: comicId,
    tabId: tabId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  bool supportComicLikeForSource(String sourceKey) =>
      _comicDetails.supportComicLikeForSource(sourceKey);
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _comicDetails.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadTagGroups(
    forceRefresh: forceRefresh,
    sourceKey: sourceKey,
    taskOrigin: taskOrigin,
  );
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions({
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadRankingOptions(taskOrigin: taskOrigin);
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadRankingComics(
    rankingOption: rankingOption,
    page: page,
    taskOrigin: taskOrigin,
  );
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadOptionGroupsByViewMore(
    viewMoreUrl: viewMoreUrl,
    taskOrigin: taskOrigin,
  );
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = '',
    List<String>? orders,
    SourceTaskOrigin? taskOrigin,
  }) => _category.loadComicsByViewMore(
    viewMoreUrl: viewMoreUrl,
    page: page,
    order: order,
    orders: orders,
    taskOrigin: taskOrigin,
  );

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
    final capturedHandle = _runtimeHost.handleFor(resolvedSourceKey);
    final normalizedKeyword = keyword.trim();
    final recorder = SourceTaskLogRecorder(_runtimeHost.logStore);
    return _runtimeHost.tasks.run(
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
        task.bindResource(capturedHandle);
        task.checkActive();
        await _initialization.ensureSourceInitialized(resolvedSourceKey);
        task.checkActive();
        final handle = capturedHandle;
        // Acquire before any script execution, including synchronous checks.
        return handle.runOperation(() async {
          final facade = handle.facade;
          final engine = facade.js.engine;
          if (engine == null) throw Exception('source_not_initialized');
          task.bindRuntime(
            runtimeId: engine.runtimeId,
            pluginVersion: facade.sourceMeta?.version,
            engine: engine,
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
