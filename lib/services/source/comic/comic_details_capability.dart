import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../common/source_json_coerce.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';
import 'source_comic_details_cache.dart';
import 'source_comic_details_parser.dart';
import '../models/source_task.dart';
import '../runtime/source_task_registry.dart';
import '../runtime/source_shared_request.dart';
import '../runtime/source_host_call_context.dart';
import '../debug/source_task_log_recorder.dart';
import '../interaction/source_ui_scope.dart';

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
      method: 'search.directId',
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
        if (error is SourceTaskCancelled ||
            error is SourceScriptStopped ||
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
  }) async {
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    var handle = _runtimeHost.handleFor(resolvedSourceKey);
    for (var attempt = 0; attempt < 2; attempt++) {
      final facade = handle.facade;
      try {
        final images = await _loadChapterImagesFromSource(
          comicId: comicId,
          epId: epId,
          facade: facade,
        );
        if (!handle.recreationRequested) {
          return images;
        }
      } catch (_) {
        if (!handle.recreationRequested || attempt == 1) {
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
      handle = _runtimeHost.recreateSourceRuntime(
        resolvedSourceKey,
        expectedHandle: handle,
      );
    }
    throw StateError('unreachable');
  }

  Future<List<String>> _loadChapterImagesFromSource({
    required String comicId,
    required String epId,
    required HazukiSourceFacade facade,
  }) async {
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      final dynamic result = await engine.evaluate(
        'this.__hazuki_source.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)})',
        name: 'source_chapter_images.js',
      );
      final dynamic resolved = await facade.js.resolve(result);
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

  bool get supportComicLike {
    final engine = facade.js.engine;
    if (engine == null) return false;
    try {
      return jsAsBool(
        engine.cachedValue(
          'typeof this.__hazuki_source.comic?.likeComic === "function"',
        ),
      );
    } catch (_) {
      return false;
    }
  }

  bool supportComicLikeForSource(String sourceKey) {
    if (!_runtimeHost.runtimeRegistry.isAllowedSourceKey(
      sourceKey.isEmpty ? _runtimeHost.activeSourceKey : sourceKey,
    )) {
      return false;
    }
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final targetFacade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    final engine = targetFacade.js.engine;
    if (engine == null) return false;
    try {
      return targetFacade.js.asBool(
        engine.cachedValue(
          'typeof this.__hazuki_source.comic?.likeComic === "function"',
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('comic_id_empty');
    }
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();

      final originalEngine = facade.js.engine;
      Future<void> runToggle() async {
        final engine = facade.js.engine;
        if (engine == null) {
          throw Exception('source_not_initialized');
        }
        if (!jsAsBool(
          await engine.evaluate(
            'typeof this.__hazuki_source.comic?.likeComic === "function"',
          ),
        )) {
          throw Exception('comic_like_not_supported');
        }

        final dynamic result = await engine.evaluate(
          'this.__hazuki_source.comic.likeComic(${jsonEncode(normalizedComicId)}, $isLike)',
          name: 'source_comic_like.js',
        );
        await facade.js.resolve(result);
      }

      await _reloginCoordinator.runWithReloginRetry(
        runToggle,
        context: SourceFacadeReloginContext(facade),
      );

      if (!identical(facade.js.engine, originalEngine) ||
          !identical(
            _runtimeHost.handleFor(resolvedSourceKey).facade,
            facade,
          )) {
        return;
      }

      final scopedKey = SourceScopedComicId(
        sourceKey: resolvedSourceKey,
        comicId: normalizedComicId,
      ).storageKey;
      final cached = _cache.get(scopedKey, sourceKey: resolvedSourceKey);
      if (cached != null) {
        _updateComicDetailsLikeStateInMemoryCache(
          cached.scopedId,
          isLike: isLike,
        );
      }
    });
  }

  void _updateComicDetailsLikeStateInMemoryCache(
    SourceScopedComicId scopedId, {
    required bool isLike,
  }) {
    _updateComicDetailsStateInMemoryCache(
      scopedId,
      update: (details) => details.copyWith(isLiked: isLike),
    );
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
