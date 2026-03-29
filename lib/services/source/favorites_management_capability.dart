part of '../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesManagementCapability
    on HazukiSourceService {
  Future<void> addFavoriteFolder(String name) async {
    await _runWithReloginRetry(() async {
      final engine = _engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }
      final hasApi = _asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
      );
      if (!hasApi) {
        throw Exception('favorite_folder_creation_not_supported');
      }
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.addFolder(${jsonEncode(name)})',
        name: 'source_favorite_add_folder.js',
      );
      await _awaitJsResult(result);
    });
  }

  Future<void> deleteFavoriteFolder(String folderId) async {
    await _runWithReloginRetry(() async {
      final engine = _engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }
      final hasApi = _asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
      );
      if (!hasApi) {
        throw Exception('favorite_folder_deletion_not_supported');
      }
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.deleteFolder(${jsonEncode(folderId)})',
        name: 'source_favorite_delete_folder.js',
      );
      await _awaitJsResult(result);
    });
  }

  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
  }) async {
    await _runWithReloginRetry(() async {
      final engine = _engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      final hasFavorites = _asBool(
        engine.evaluate('!!this.__hazuki_source.favorites'),
      );
      if (!hasFavorites) {
        throw Exception('favorites_not_supported');
      }

      final hasAddOrDel = _asBool(
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

      await _awaitJsResult(result);
    });
  }
}
