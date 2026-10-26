import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../common/source_json_coerce.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';
import 'source_comic_details_cache.dart';
import 'source_comic_details_parser.dart';
import '../runtime/source_task_registry.dart';
import '../runtime/source_shared_request.dart';
import '../runtime/source_host_call_context.dart';
import '../debug/source_task_log_recorder.dart';
import '../interaction/source_ui_scope.dart';
import '../interaction/source_ui_service.dart';

class SourceComicDetailsCapability {
  SourceComicDetailsCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceComicDetailsCache cache,
    required SourceReloginCoordinator reloginCoordinator,
    required ComicDetailsTextTranslator translateSourceText,
  }) : _runtimeHost = runtimeHost,
       _cache = cache,
       _reloginCoordinator = reloginCoordinator,
       _parser = SourceComicDetailsParser(translateSourceText);

  final SourceRuntimeHost _runtimeHost;
  final SourceComicDetailsCache _cache;
  final SourceReloginCoordinator _reloginCoordinator;
  final SourceComicDetailsParser _parser;
  final SourceComicDetailsRequestTracker _requestTracker =
      SourceComicDetailsRequestTracker();

  String _resolveActiveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  HazukiSourceFacade get facade => _runtimeHost.activeHandle.facade;
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) {
    taskOrigin?.readerSession?.checkActive();
    taskOrigin?.downloadSession?.checkActive();
    _runtimeHost.checkReaderSession(
      _resolveActiveSourceKey(sourceKey),
      taskOrigin,
    );
    if (taskOrigin == null) {
      return _loadComicDetails(
        comicId,
        sourceKey: sourceKey,
        forceRefresh: forceRefresh,
      );
    }
    final recorder = SourceTaskLogRecorder(_runtimeHost.logStore);
    return _runtimeHost.tasks.run(
      pluginId: _resolveActiveSourceKey(sourceKey),
      method: taskOrigin.readerSession == null
          ? 'search.directId'
          : 'reader.details',
      origin: taskOrigin,
      observe: (task, event, disposition, error, stack) => recorder.record(
        task,
        event,
        disposition,
        error,
        stack,
        sensitiveValues: [comicId],
      ),
      operation: (task) => _loadComicDetails(
        comicId,
        sourceKey: sourceKey,
        forceRefresh: forceRefresh,
        task: task,
      ),
    );
  }

  Future<ComicDetailsData> _loadComicDetails(
    String comicId, {
    required String sourceKey,
    required bool forceRefresh,
    SourceTask? task,
  }) async {
    task?.checkActive();
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('comic_id_empty');
    }
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final scopedComicKey = SourceScopedComicId(
      sourceKey: resolvedSourceKey,
      comicId: normalizedComicId,
    ).storageKey;

    if (!forceRefresh) {
      final memoryCached = _cache.get(
        scopedComicKey,
        sourceKey: resolvedSourceKey,
      );
      if (memoryCached != null) {
        return memoryCached;
      }
    }

    final handle = _runtimeHost.handleFor(resolvedSourceKey);
    task?.bindResource(handle);
    final facade = handle.facade;

    final inFlight = facade.cache.comicDetailsInFlight[scopedComicKey];
    if (!forceRefresh && inFlight != null && inFlight.available) {
      return inFlight.subscribe(task: task);
    }

    final requestToken = _requestTracker.begin(scopedComicKey);
    late final SourceSharedRequest<ComicDetailsData> request;
    request = SourceSharedRequest<ComicDetailsData>(
      pluginId: resolvedSourceKey,
      method: 'comic.loadInfo',
      operation: (_) => _loadComicDetailsWithRuntimeRecovery(
        normalizedComicId,
        handle,
        sourceKey: resolvedSourceKey,
        request: request,
        shouldCacheResult: () =>
            request.hasConsumers &&
            _requestTracker.isCurrent(scopedComicKey, requestToken),
      ),
      onUnavailable: () {
        if (identical(
          facade.cache.comicDetailsInFlight[scopedComicKey],
          request,
        )) {
          facade.cache.comicDetailsInFlight.remove(scopedComicKey);
        }
        _requestTracker.complete(scopedComicKey, requestToken);
      },
    );
    facade.cache.comicDetailsInFlight[scopedComicKey] = request;
    return request.subscribe(task: task);
  }

  Future<ComicDetailsData> _loadComicDetailsWithRuntimeRecovery(
    String normalizedComicId,
    SourceRuntimeHandle initialHandle, {
    required String sourceKey,
    required bool Function() shouldCacheResult,
    required SourceSharedRequest<ComicDetailsData> request,
  }) async {
    var handle = initialHandle;
    var recoveringRuntime = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      request.checkActive();
      final facade = handle.facade;
      try {
        final details = await _loadComicDetailsFromSource(
          normalizedComicId,
          facade,
          sourceKey: sourceKey,
          shouldCacheResult: shouldCacheResult,
          request: request,
        );
        request.checkActive();
        if (!handle.recreationRequested) {
          return details;
        }
      } catch (error) {
        request.checkActive();
        // 运行时故障不能经插件请求的重建重放到新实例。
        if (error is SourceTaskCancelled ||
            error is SourceScriptStopped ||
            error is SourceRuntimeFailed ||
            isSourceUiCancellation(error)) {
          rethrow;
        }
        if (!handle.recreationRequested || attempt == 1) {
          if (attempt == 1 && recoveringRuntime) {
            throw Exception('source_runtime_recovery_failed:$error');
          }
          rethrow;
        }
      }

      if (attempt == 1) {
        throw Exception('source_runtime_recovery_failed');
      }
      recoveringRuntime = true;
      facade.addApplicationLog(
        title: 'Recreating source runtime as requested by plugin',
        level: 'warning',
        source: 'source_runtime',
        content: {'sourceKey': sourceKey, 'comicId': normalizedComicId},
      );
      handle = _runtimeHost.recreateSourceRuntime(
        sourceKey,
        expectedHandle: handle,
      );
    }
    throw StateError('unreachable');
  }

  Future<ComicDetailsData> _loadComicDetailsFromSource(
    String normalizedComicId,
    HazukiSourceFacade facade, {
    required String sourceKey,
    required bool Function() shouldCacheResult,
    required SourceSharedRequest<ComicDetailsData> request,
  }) async {
    return request.withUiScope(
      () => facade.handle.runOperation(() async {
        await facade.ensureInitialized();
        request.checkActive();

        final engine = facade.js.engine;
        if (engine == null) {
          throw Exception('source_not_initialized');
        }
        request.bindEngine(engine);

        final dynamic result = await engine.evaluate(
          '''(async () => {
        const data = await this.__hazuki_source.comic.loadInfo(${jsonEncode(normalizedComicId)});
        const chapterEntries = [];
        const chapters = data?.chapters;
        if (chapters?.entries && typeof chapters.entries === 'function') {
          for (const pair of chapters.entries()) {
            if (Array.isArray(pair) && pair.length >= 2) {
              chapterEntries.push([String(pair[0] ?? ''), String(pair[1] ?? '')]);
            }
          }
        } else if (Array.isArray(chapters)) {
          for (const item of chapters) {
            if (Array.isArray(item) && item.length >= 2) {
              chapterEntries.push([String(item[0] ?? ''), String(item[1] ?? '')]);
            } else if (item && typeof item === 'object') {
              chapterEntries.push([
                String(item.id ?? item.epId ?? item.key ?? ''),
                String(item.title ?? item.name ?? item.value ?? ''),
              ]);
            }
          }
        } else if (chapters && typeof chapters === 'object') {
          for (const key of Object.keys(chapters)) {
            chapterEntries.push([String(key), String(chapters[key] ?? '')]);
          }
        }
        return {
          ...data,
          __chapterEntries: chapterEntries,
        };
      })()''',
          name: 'source_comic_detail.js',
          execution: request.execution,
        );
        final dynamic resolved = await facade.js.resolve(result);
        request.checkActive();
        if (resolved is! Map) {
          throw Exception('comic_details_invalid_response');
        }

        final details = _parser.parse(
          map: Map<String, dynamic>.from(resolved),
          fallbackComicId: normalizedComicId,
          sourceKey: sourceKey,
        );

        if (shouldCacheResult() &&
            identical(facade.js.engine, engine) &&
            !facade.handle.isDisposed &&
            identical(_runtimeHost.handleFor(sourceKey).facade, facade)) {
          _cache.put(
            SourceScopedComicId(
              sourceKey: details.sourceKey,
              comicId: normalizedComicId,
            ).storageKey,
            details,
            sourceKey: sourceKey,
          );
          if (details.id != normalizedComicId) {
            _cache.put(
              details.scopedId.storageKey,
              details,
              sourceKey: sourceKey,
            );
          }
        }
        return details;
      }),
    );
  }

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async {
    taskOrigin?.readerSession?.checkActive();
    taskOrigin?.downloadSession?.checkActive();
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    _runtimeHost.checkReaderSession(resolvedSourceKey, taskOrigin);
    var handle = _runtimeHost.handleFor(resolvedSourceKey);
    final callerScope = SourceUiScope.current;
    final caller = callerScope?.controllerOwner;
    final routeOwner =
        callerScope?.owner ?? SourceUiService.instance.captureOwner?.call();
    for (var attempt = 0; attempt < 2; attempt++) {
      final facade = handle.facade;
      try {
        Future<List<String>> run() => runSourceOperation(
          _runtimeHost,
          handle,
          'reader.chapter',
          (context) => _loadChapterImagesFromSource(
            comicId: comicId,
            epId: epId,
            facade: facade,
            context: context,
          ),
          origin: taskOrigin,
          retainOnSourceChange: taskOrigin == null,
          sensitiveValues: [comicId, epId],
        );
        // Attempt scopes retire independently of the caller's reading scope.
        final images = await SourceUiService.instance.run(
          run,
          inheritCurrent: false,
          abortOnScopeCancellation: false,
          owner: caller is SourceUiOwner ? caller : null,
          routeOwner: routeOwner,
          captureRouteOwner: false,
        );
        if (!handle.recreationRequested) {
          return images;
        }
      } catch (error) {
        rethrowSourceOperationStop(error);
        if (error is SourceRuntimeFailed ||
            !handle.recreationRequested ||
            attempt == 1) {
          rethrow;
        }
      }

      if (attempt == 1) {
        throw Exception('source_chapter_images_recovery_failed');
      }
      facade.addApplicationLog(
        title: 'Recreating source runtime as requested by plugin',
        level: 'warning',
        source: 'source_runtime',
        content: {
          'sourceKey': resolvedSourceKey,
          'comicId': comicId,
          'epId': epId,
          'operation': 'load_chapter_images',
        },
      );
      if (taskOrigin?.cancellation?.reason case final reason?) {
        throw SourceTaskCancelled(resolvedSourceKey, reason);
      }
      _runtimeHost.checkReaderSession(resolvedSourceKey, taskOrigin);
      final previous = handle;
      handle = _runtimeHost.recreateSourceRuntime(
        resolvedSourceKey,
        expectedHandle: handle,
      );
      _runtimeHost.transferDownloadSession(taskOrigin, previous, handle);
    }
    throw StateError('unreachable');
  }

  Future<List<String>> _loadChapterImagesFromSource({
    required String comicId,
    required String epId,
    required HazukiSourceFacade facade,
    required SourceOperationContext context,
  }) async {
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();
      context.checkActive();
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      final dynamic result = await context.evaluate(
        engine,
        'this.__hazuki_source.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)})',
        name: 'source_chapter_images.js',
      );
      final dynamic resolved = await context.resolve(facade.js.resolve(result));
      if (resolved is! Map) {
        return const [];
      }

      final imagesRaw = Map<String, dynamic>.from(resolved)['images'];
      if (imagesRaw is! List) {
        return const [];
      }

      return imagesRaw
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    });
  }

  /// 详情页顶部 `plugin` 动作：调用插件的 `comic.onHeaderAction`。
  /// 插件可在回调中自行弹窗或发请求；返回的新顶部内容同步写回详情缓存。
  Future<ComicHeaderActionResult> runComicHeaderAction({
    required String comicId,
    required String actionId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(_resolveActiveSourceKey(sourceKey)),
    'comic.headerAction',
    (operationContext) => _runComicHeaderActionTask(
      operationContext,
      comicId: comicId,
      actionId: actionId,
      sourceKey: sourceKey,
    ),
    origin: taskOrigin,
    serviceOwned: true,
    sensitiveValues: [comicId],
  );

  Future<ComicHeaderActionResult> _runComicHeaderActionTask(
    SourceOperationContext operationContext, {
    required String comicId,
    required String actionId,
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('comic_id_empty');
    }
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final facade = (operationContext.resource as SourceRuntimeHandle).facade;
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();

      final originalEngine = facade.js.engine;
      Future<ComicHeaderActionResult> runAction() async {
        final engine = facade.js.engine;
        if (engine == null) {
          throw Exception('source_not_initialized');
        }
        if (!jsAsBool(
          await operationContext.evaluate(
            engine,
            'typeof this.__hazuki_source.comic?.onHeaderAction === "function"',
          ),
        )) {
          throw Exception('comic_header_action_not_supported');
        }

        final dynamic result = await operationContext.evaluate(
          engine,
          'this.__hazuki_source.comic.onHeaderAction('
          '${jsonEncode(normalizedComicId)}, ${jsonEncode(actionId)})',
          name: 'source_comic_header_action.js',
        );
        return _parser.parseHeaderActionResult(
          await operationContext.resolve(facade.js.resolve(result)),
          sourceKey: resolvedSourceKey,
        );
      }

      final result = await _reloginCoordinator.runWithReloginRetry(
        runAction,
        context: SourceFacadeReloginContext(facade),
        checkActive: operationContext.checkActive,
      );

      if ((result.headerStats != null || result.headerBadges != null) &&
          operationContext.canCache() &&
          identical(facade.js.engine, originalEngine) &&
          identical(_runtimeHost.handleFor(resolvedSourceKey).facade, facade)) {
        final scopedId = SourceScopedComicId(
          sourceKey: resolvedSourceKey,
          comicId: normalizedComicId,
        );
        // 别名 ID 先解析到缓存里的规范 ID，保证所有别名条目一起更新。
        final cached = _cache.get(
          scopedId.storageKey,
          sourceKey: resolvedSourceKey,
        );
        _updateComicDetailsStateInMemoryCache(
          cached?.scopedId ?? scopedId,
          update: (details) => details.copyWith(
            headerStats: result.headerStats,
            headerBadges: result.headerBadges,
          ),
        );
      }
      return result;
    });
  }

  void updateFavoriteStateInMemoryCache(
    SourceScopedComicId scopedId, {
    required bool isFavorite,
  }) {
    _updateComicDetailsStateInMemoryCache(
      scopedId,
      update: (details) => details.copyWith(isFavorite: isFavorite),
    );
  }

  void _updateComicDetailsStateInMemoryCache(
    SourceScopedComicId scopedId, {
    required ComicDetailsData Function(ComicDetailsData details) update,
  }) => _cache.update(scopedId, transform: update);
}
