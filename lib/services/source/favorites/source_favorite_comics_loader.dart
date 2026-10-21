import '../runtime/source_runtime_handle.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'source_favorites_response_parser.dart';
import 'source_favorites_script_factory.dart';

/// Loads favorite comic pages and applies source-specific fallbacks.
class SourceFavoriteComicsLoader {
  const SourceFavoriteComicsLoader({
    required SourceRuntimeHost runtimeHost,
    required SourceReloginCoordinator reloginCoordinator,
    required SourceFavoritesResponseParser responseParser,
    SourceFavoritesScriptFactory scriptFactory =
        const SourceFavoritesScriptFactory(),
  }) : _runtimeHost = runtimeHost,
       _reloginCoordinator = reloginCoordinator,
       _responseParser = responseParser,
       _scriptFactory = scriptFactory;

  final SourceRuntimeHost _runtimeHost;
  final SourceReloginCoordinator _reloginCoordinator;
  final SourceFavoritesResponseParser _responseParser;
  final SourceFavoritesScriptFactory _scriptFactory;

  Future<FavoriteComicsResult> load({
    required int page,
    required String folderId,
    SourceTaskOrigin? taskOrigin,
  }) async {
    try {
      return await runSourceOperation(
        _runtimeHost,
        _runtimeHost.activeHandle,
        'favorites.load',
        (operationContext) =>
            _loadTask(operationContext, page: page, folderId: folderId),
        origin: taskOrigin,
        serviceOwned: false,
      );
    } catch (error) {
      rethrowSourceOperationStop(error);
      return FavoriteComicsResult.error(error.toString());
    }
  }

  Future<FavoriteComicsResult> _loadTask(
    SourceOperationContext operationContext, {
    required int page,
    required String folderId,
  }) async {
    final facade = (operationContext.resource as SourceRuntimeHandle).facade;
    final context = SourceFacadeReloginContext(facade);
    final sessionReady = await _reloginCoordinator.ensureFavoriteSessionReady(
      context,
    );
    if (!sessionReady) throw Exception('login_expired');
    final result = await _reloginCoordinator.runWithReloginRetry(
      () => _loadWithFacade(
        operationContext,
        facade: facade,
        page: page,
        folderId: folderId,
      ),
      context: context,
      checkActive: operationContext.checkActive,
    );
    return FavoriteComicsResult.success(result.$1, maxPage: result.$2);
  }

  Future<(List<ExploreComic>, int?)> _loadWithFacade(
    SourceOperationContext operationContext, {
    required HazukiSourceFacade facade,
    required int page,
    required String folderId,
  }) async {
    return facade.handle.runOperation(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      final hasFavorites = facade.js.asBool(
        await operationContext.evaluate(
          engine,
          '!!this.__hazuki_source.favorites',
        ),
      );
      if (!hasFavorites) throw Exception('favorites_not_supported');
      final hasLoadComics = facade.js.asBool(
        await operationContext.evaluate(
          engine,
          '!!this.__hazuki_source.favorites?.loadComics',
        ),
      );
      final hasLoadNext = facade.js.asBool(
        await operationContext.evaluate(
          engine,
          '!!this.__hazuki_source.favorites?.loadNext',
        ),
      );
      if (!hasLoadComics && !hasLoadNext) {
        throw Exception('favorite_comics_loading_not_supported');
      }
      final normalizedFolderId =
          SourceFavoritesResponseParser.normalizeFolderId(folderId);
      if (!hasLoadComics) {
        final comics = await _loadNext(
          operationContext,
          facade,
          normalizedFolderId,
        );
        return (SourceFavoritesResponseParser.mergeComics(comics), null);
      }
      if (normalizedFolderId != '0') {
        final loaded = await _loadComics(
          operationContext,
          facade: facade,
          page: page,
          folderId: normalizedFolderId,
          scriptName: 'source_favorite_comics.js',
        );
        return (
          SourceFavoritesResponseParser.mergeComics(loaded.$1),
          loaded.$2,
        );
      }
      return _loadAllComics(operationContext, facade: facade, page: page);
    });
  }

  Future<List<ExploreComic>> _loadNext(
    SourceOperationContext operationContext,
    HazukiSourceFacade facade,
    String folderId,
  ) async {
    final raw = await operationContext.evaluate(
      facade.js.engine!,
      _scriptFactory.loadNext(cursor: null, folderId: folderId),
      name: 'source_favorite_next.js',
    );
    final resolved = await operationContext.resolve(facade.js.resolve(raw));
    return _responseParser.parseComicsPage(resolved).comics;
  }

  Future<(List<ExploreComic>, int?)> _loadAllComics(
    SourceOperationContext operationContext, {
    required HazukiSourceFacade facade,
    required int page,
  }) async {
    final allComics = <ExploreComic>[];
    int? maxPage;
    final loadedNull = await _tryLoadComics(
      operationContext,
      facade: facade,
      page: page,
      folderId: null,
      scriptName: 'source_favorite_comics_all_null.js',
    );
    final loadedZero = await _tryLoadComics(
      operationContext,
      facade: facade,
      page: page,
      folderId: '0',
      scriptName: 'source_favorite_comics_all_0.js',
    );
    if (loadedNull != null && loadedNull.$1.isNotEmpty) {
      allComics.addAll(loadedNull.$1);
      maxPage = loadedNull.$2;
      if (loadedZero != null && loadedZero.$1.isNotEmpty) {
        allComics.addAll(loadedZero.$1);
        maxPage = _maxPage(maxPage, loadedZero.$2);
      }
    } else if (loadedZero != null && loadedZero.$1.isNotEmpty) {
      allComics.addAll(loadedZero.$1);
      maxPage = loadedZero.$2;
    } else {
      final folders = await _loadFallbackFolderIds(operationContext, facade);
      for (final folderId in folders) {
        final loaded = await _loadComics(
          operationContext,
          facade: facade,
          page: page,
          folderId: folderId,
          scriptName: 'source_favorite_comics_folder_$folderId.js',
        );
        allComics.addAll(loaded.$1);
        maxPage = _maxPage(maxPage, loaded.$2);
      }
    }
    return (SourceFavoritesResponseParser.mergeComics(allComics), maxPage);
  }

  Future<List<String>> _loadFallbackFolderIds(
    SourceOperationContext operationContext,
    HazukiSourceFacade facade,
  ) async {
    final engine = facade.js.engine!;
    final hasLoadFolders = facade.js.asBool(
      await operationContext.evaluate(
        engine,
        '!!this.__hazuki_source.favorites?.loadFolders',
      ),
    );
    if (!hasLoadFolders) return const [];
    final raw = await operationContext.evaluate(
      engine,
      _scriptFactory.loadFolders(null),
      name: 'source_favorite_folders_for_all.js',
    );
    return _responseParser.extractFolderIds(
      await operationContext.resolve(facade.js.resolve(raw)),
    );
  }

  Future<(List<ExploreComic>, int?)?> _tryLoadComics(
    SourceOperationContext operationContext, {
    required HazukiSourceFacade facade,
    required int page,
    required String? folderId,
    required String scriptName,
  }) async {
    try {
      return await _loadComics(
        operationContext,
        facade: facade,
        page: page,
        folderId: folderId,
        scriptName: scriptName,
      );
    } catch (error) {
      rethrowSourceOperationStop(error);
      if (SourceReloginCoordinator.isLoginExpiredError(error)) rethrow;
      return null;
    }
  }

  Future<(List<ExploreComic>, int?)> _loadComics(
    SourceOperationContext operationContext, {
    required HazukiSourceFacade facade,
    required int page,
    required String? folderId,
    required String scriptName,
  }) async {
    final raw = await operationContext.evaluate(
      facade.js.engine!,
      _scriptFactory.loadComics(page: page, folderId: folderId),
      name: scriptName,
    );
    final resolved = await operationContext.resolve(facade.js.resolve(raw));
    final parsed = _responseParser.parseComicsPage(resolved);
    return (parsed.comics, parsed.maxPage);
  }

  static int? _maxPage(int? current, int? candidate) {
    if (candidate == null) return current;
    if (current == null || candidate > current) return candidate;
    return current;
  }
}
