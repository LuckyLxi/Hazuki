import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../common/source_json_coerce.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_initialization_operations.dart';
import '../plugins/source_sort_options.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_script_engine.dart';
import '../models/source_script_execution.dart';
import '../debug/debug_log_internals.dart';
import '../debug/source_task_log_recorder.dart';

class SourceContentOperations {
  SourceContentOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeInitializationOperations initialization,
  }) : _runtimeHost = runtimeHost,
       _initialization = initialization;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeInitializationOperations _initialization;
  List<SourceTaskSnapshot> get activeSearchTasks => _runtimeHost
      .tasks
      .activeTasks
      .where((task) => task.method == 'search.load')
      .toList(growable: false);

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
