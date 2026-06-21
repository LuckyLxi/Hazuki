part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesManagementCapability
    on HazukiSourceService {
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) async {
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final facade = _handleFor(resolvedSourceKey).facade;
    await facade.ensureInitialized();
    Future<void> runAdd() async {
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }
      final hasApi = facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
      );
      if (!hasApi) {
        throw Exception('favorite_folder_creation_not_supported');
      }
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.addFolder(${jsonEncode(name)})',
        name: 'source_favorite_add_folder.js',
      );
      await facade.js.resolve(result);
    }

    await _runWithReloginRetry(runAdd, targetFacade: facade);
  }

  Future<void> deleteFavoriteFolder(
    String folderId, {
    String sourceKey = '',
  }) async {
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final facade = _handleFor(resolvedSourceKey).facade;
    await facade.ensureInitialized();
    Future<void> runDelete() async {
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }
      final hasApi = facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
      );
      if (!hasApi) {
        throw Exception('favorite_folder_deletion_not_supported');
      }
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.deleteFolder(${jsonEncode(folderId)})',
        name: 'source_favorite_delete_folder.js',
      );
      await facade.js.resolve(result);
    }

    await _runWithReloginRetry(runDelete, targetFacade: facade);
  }

  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final facade = _handleFor(resolvedSourceKey).facade;
    await facade.ensureInitialized();
    Future<void> runToggle() async {
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      final hasFavorites = facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites'),
      );
      if (!hasFavorites) {
        throw Exception('favorites_not_supported');
      }

      final hasAddOrDel = facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
      );
      if (!hasAddOrDel) {
        throw Exception('favorite_toggle_not_supported');
      }

      final normalizedFolderId = folderId.trim().isEmpty
          ? '0'
          : folderId.trim();
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.addOrDelFavorite(${jsonEncode(comicId)}, ${jsonEncode(normalizedFolderId)}, $isAdding, ${jsonEncode(favoriteId)})',
        name: 'source_toggle_favorite.js',
      );

      await facade.js.resolve(result);
    }

    await _runWithReloginRetry(runToggle, targetFacade: facade);

    if (normalizedComicId.isNotEmpty) {
      final scopedKey = SourceScopedComicId(
        sourceKey: resolvedSourceKey,
        comicId: normalizedComicId,
      ).storageKey;
      final cached = _getComicDetailsFromMemoryCache(
        scopedKey,
        sourceKey: resolvedSourceKey,
      );
      if (cached != null) {
        _updateComicDetailsFavoriteStateInMemoryCache(
          cached.scopedId,
          isFavorite: isAdding,
        );
      }
    }

    notifyCloudFavoritesChanged();
  }
}
