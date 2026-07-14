import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../models/source_identity.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';

typedef SourceFavoritesComicParser =
    List<ExploreComic> Function(List comics, {String sourceKey});

typedef SourceFavoriteStateUpdater =
    void Function({
      required String sourceKey,
      required String comicId,
      required bool isFavorite,
    });

/// Loads and mutates remote favorites through explicit runtime collaborators.
class SourceFavoritesCapability {
  SourceFavoritesCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceReloginCoordinator reloginCoordinator,
    required SourceFavoritesComicParser parseExploreComics,
    required SourceFavoriteStateUpdater updateComicDetailsFavoriteState,
    required void Function() notifyCloudFavoritesChanged,
  }) : _runtimeHost = runtimeHost,
       _reloginCoordinator = reloginCoordinator,
       _parseExploreComics = parseExploreComics,
       _updateComicDetailsFavoriteState = updateComicDetailsFavoriteState,
       _notifyCloudFavoritesChanged = notifyCloudFavoritesChanged;

  final SourceRuntimeHost _runtimeHost;
  final SourceReloginCoordinator _reloginCoordinator;
  final SourceFavoritesComicParser _parseExploreComics;
  final SourceFavoriteStateUpdater _updateComicDetailsFavoriteState;
  final void Function() _notifyCloudFavoritesChanged;

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  HazukiSourceFacade _facadeForSource(String sourceKey) =>
      _runtimeHost.handleFor(_resolveSourceKey(sourceKey)).facade;

  HazukiSourceFacade get _activeFacade => _runtimeHost.activeHandle.facade;

  SourceFacadeReloginContext _reloginContext(HazukiSourceFacade facade) =>
      SourceFacadeReloginContext(facade);

  static String normalizeFolderId(String folderId) =>
      folderId.trim().isEmpty ? '0' : folderId.trim();

  static List<ExploreComic> mergeFavoriteComics(Iterable<ExploreComic> comics) {
    final merged = <String, ExploreComic>{};
    for (final comic in comics) {
      if (comic.id.isNotEmpty) merged[comic.id] = comic;
    }
    return merged.values.toList();
  }

  List<ExploreComic> parseFavoriteComicsForTesting(
    List comics, {
    String sourceKey = '',
  }) => _parseExploreComics(comics, sourceKey: sourceKey);

  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) {
    final targetFacade = _facadeForSource(sourceKey);
    final engine = targetFacade.js.engine;
    if (engine == null) return false;
    return targetFacade.js.asBool(
      engine.evaluate(
        'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
      ),
    );
  }

  bool supportFavoriteFolderAddForSource(String sourceKey) {
    final targetFacade = _facadeForSource(sourceKey);
    final engine = targetFacade.js.engine;
    return engine != null &&
        targetFacade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
        );
  }

  bool supportFavoriteFolderDeleteForSource(String sourceKey) {
    final targetFacade = _facadeForSource(sourceKey);
    final engine = targetFacade.js.engine;
    return engine != null &&
        targetFacade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
        );
  }

  bool supportFavoriteFolderLoadForSource(String sourceKey) {
    final targetFacade = _facadeForSource(sourceKey);
    final engine = targetFacade.js.engine;
    return engine != null &&
        targetFacade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
        );
  }

  bool supportFavoriteToggleForSource(String sourceKey) {
    final targetFacade = _facadeForSource(sourceKey);
    final engine = targetFacade.js.engine;
    return engine != null &&
        targetFacade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
        );
  }

  bool get favoriteSingleFolderForSingleComic {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    if (engine == null) return false;
    return facade.js.asBool(
      facade.js.evaluate(
        'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
      ),
    );
  }

  bool get supportFavoriteFolderManagement {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    if (engine == null) return false;
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  bool get supportFavoriteFolderAdd {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    if (engine == null) return false;
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
    );
  }

  bool get supportFavoriteFolderDelete {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    if (engine == null) return false;
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
    );
  }

  bool get supportFavoriteFolderLoad {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    if (engine == null) return false;
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  String get favoriteSortOrder {
    final facade = _activeFacade;
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) return 'mr';
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      final raw = facade.loadSourceSetting(
        sourceMeta.key,
        'favorites_ordering',
      );
      final normalized = raw?.toString().trim() ?? '';
      return favoriteSortOrders.contains(normalized)
          ? normalized
          : '-datetime_updated';
    }
    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      final raw = facade.loadSourceSetting(sourceMeta.key, 'favoriteSort');
      final normalized = raw?.toString().trim() ?? '';
      return favoriteSortOrders.contains(normalized) ? normalized : 'dd';
    }
    final raw = facade.loadSourceSetting(sourceMeta.key, 'favoriteOrder');
    return raw?.toString().trim() == 'mp' ? 'mp' : 'mr';
  }

  Future<void> setFavoriteSortOrder(String order) async {
    final facade = _activeFacade;
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) throw Exception('source_not_initialized');
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      final normalized = favoriteSortOrders.contains(order.trim())
          ? order.trim()
          : '-datetime_updated';
      await facade.saveSourceSetting(
        sourceMeta.key,
        'favorites_ordering',
        normalized,
      );
      return;
    }
    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      final normalized = favoriteSortOrders.contains(order.trim())
          ? order.trim()
          : 'dd';
      await facade.saveSourceSetting(
        sourceMeta.key,
        'favoriteSort',
        normalized,
      );
      return;
    }
    await facade.saveSourceSetting(
      sourceMeta.key,
      'favoriteOrder',
      order.trim() == 'mp' ? 'mp' : 'mr',
    );
  }

  List<String> get favoriteSortOrders {
    final sourceMeta = _activeFacade.sourceMeta;
    if (sourceMeta != null && isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      return const <String>[
        '-datetime_updated',
        '-datetime_modifier',
        '-datetime_browse',
      ];
    }
    if (sourceMeta != null && isHazukiPicacgSourceKey(sourceMeta.key)) {
      return const <String>['dd', 'da'];
    }
    return const <String>['mr', 'mp'];
  }

  bool get supportFavoriteSortOrder {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    if (engine == null) return false;
    return facade.js.asBool(
      facade.js.evaluate(
        '!!(this.__hazuki_source.settings?.favoriteOrder || this.__hazuki_source.settings?.favorites_ordering || this.__hazuki_source.settings?.favoriteSort)',
      ),
    );
  }

  bool get supportFavoriteLoadComics {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null &&
        facade.js.asBool(
          facade.js.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
        );
  }

  bool get supportFavoriteLoadNext {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null &&
        facade.js.asBool(
          facade.js.evaluate('!!this.__hazuki_source.favorites?.loadNext'),
        );
  }

  bool get supportFavoriteToggle {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null &&
        facade.js.asBool(
          facade.js.evaluate(
            '!!this.__hazuki_source.favorites?.addOrDelFavorite',
          ),
        );
  }

  bool get supportCommentSend {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null &&
        facade.js.asBool(
          facade.js.evaluate('!!this.__hazuki_source.comic?.sendComment'),
        );
  }

  bool get supportCommentLike {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null &&
        facade.js.asBool(
          facade.js.evaluate('!!this.__hazuki_source.comic?.likeComment'),
        );
  }

  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) async {
    try {
      final facade = _activeFacade;
      final context = _reloginContext(facade);
      final sessionReady = await _reloginCoordinator.ensureFavoriteSessionReady(
        context,
      );
      if (!sessionReady) throw Exception('login_expired');
      final result = await _reloginCoordinator.runWithReloginRetry(() async {
        final engine = facade.js.engine;
        if (engine == null) throw Exception('source_not_initialized');
        final hasFavorites = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites'),
        );
        if (!hasFavorites) throw Exception('favorites_not_supported');
        final hasLoadComics = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
        );
        final hasLoadNext = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadNext'),
        );
        if (!hasLoadComics && !hasLoadNext) {
          throw Exception('favorite_comics_loading_not_supported');
        }
        final normalizedFolderId = normalizeFolderId(folderId);

        Future<(List<ExploreComic>, int?)> loadComicsByFolderArg(
          String folderArg,
          String scriptName,
        ) async {
          final allComics = <ExploreComic>[];
          int? maxPage;
          final dynamic raw = engine.evaluate(
            'this.__hazuki_source.favorites.loadComics($page, $folderArg)',
            name: scriptName,
          );
          final dynamic resolved = await facade.js.resolve(raw);
          if (resolved is Map) {
            final map = Map<String, dynamic>.from(resolved);
            final comicsRaw = map['comics'];
            if (comicsRaw is List) {
              allComics.addAll(_parseExploreComics(comicsRaw));
            }
            final maxPageRaw = map['maxPage'];
            maxPage = switch (maxPageRaw) {
              int value => value,
              num value => value.toInt(),
              _ => int.tryParse(maxPageRaw?.toString() ?? ''),
            };
          }
          return (allComics, maxPage);
        }

        final allComics = <ExploreComic>[];
        int? maxPage;
        if (hasLoadComics) {
          if (normalizedFolderId != '0') {
            final loaded = await loadComicsByFolderArg(
              jsonEncode(normalizedFolderId),
              'source_favorite_comics.js',
            );
            allComics.addAll(loaded.$1);
            maxPage = loaded.$2;
          } else {
            Future<(List<ExploreComic>, int?)?> tryLoadComicsByFolderArg(
              String folderArg,
              String scriptName,
            ) async {
              try {
                return await loadComicsByFolderArg(folderArg, scriptName);
              } catch (error) {
                if (SourceReloginCoordinator.isLoginExpiredError(error)) {
                  rethrow;
                }
                return null;
              }
            }

            final loadedNull = await tryLoadComicsByFolderArg(
              'null',
              'source_favorite_comics_all_null.js',
            );
            final loadedZero = await tryLoadComicsByFolderArg(
              jsonEncode('0'),
              'source_favorite_comics_all_0.js',
            );
            if (loadedNull != null && loadedNull.$1.isNotEmpty) {
              allComics.addAll(loadedNull.$1);
              maxPage = loadedNull.$2;
              if (loadedZero != null && loadedZero.$1.isNotEmpty) {
                allComics.addAll(loadedZero.$1);
                final loadedMaxPage = loadedZero.$2;
                if (loadedMaxPage != null &&
                    (maxPage == null || loadedMaxPage > maxPage)) {
                  maxPage = loadedMaxPage;
                }
              }
            } else if (loadedZero != null && loadedZero.$1.isNotEmpty) {
              allComics.addAll(loadedZero.$1);
              maxPage = loadedZero.$2;
            } else {
              final hasLoadFolders = facade.js.asBool(
                engine.evaluate(
                  '!!this.__hazuki_source.favorites?.loadFolders',
                ),
              );
              if (hasLoadFolders) {
                final dynamic foldersRaw = engine.evaluate(
                  'this.__hazuki_source.favorites.loadFolders(null)',
                  name: 'source_favorite_folders_for_all.js',
                );
                final dynamic foldersResolved = await facade.js.resolve(
                  foldersRaw,
                );
                final folderIds = <String>[];
                if (foldersResolved is Map) {
                  final folders = Map<String, dynamic>.from(
                    foldersResolved,
                  )['folders'];
                  if (folders is Map) {
                    for (final entry in folders.entries) {
                      final id = entry.key.toString().trim();
                      if (id.isNotEmpty && id != '0') folderIds.add(id);
                    }
                  }
                }
                for (final fid in folderIds) {
                  final loaded = await loadComicsByFolderArg(
                    jsonEncode(fid),
                    'source_favorite_comics_folder_$fid.js',
                  );
                  allComics.addAll(loaded.$1);
                  final loadedMaxPage = loaded.$2;
                  if (loadedMaxPage != null &&
                      (maxPage == null || loadedMaxPage > maxPage)) {
                    maxPage = loadedMaxPage;
                  }
                }
              }
            }
          }
        } else {
          final dynamic raw = engine.evaluate(
            'this.__hazuki_source.favorites.loadNext(null, ${jsonEncode(normalizedFolderId)})',
            name: 'source_favorite_next.js',
          );
          final dynamic resolved = await facade.js.resolve(raw);
          if (resolved is Map) {
            final comicsRaw = Map<String, dynamic>.from(resolved)['comics'];
            if (comicsRaw is List) {
              allComics.addAll(_parseExploreComics(comicsRaw));
            }
          }
        }
        return (mergeFavoriteComics(allComics), maxPage);
      }, context: context);
      return FavoriteComicsResult.success(result.$1, maxPage: result.$2);
    } catch (error) {
      return FavoriteComicsResult.error(error.toString());
    }
  }

  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) async {
    try {
      final resolvedSourceKey = _resolveSourceKey(sourceKey);
      final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
      await facade.ensureInitialized();
      final context = _reloginContext(facade);
      final sessionReady = await _reloginCoordinator.ensureFavoriteSessionReady(
        context,
      );
      if (!sessionReady) throw Exception('login_expired');
      Future<(List<FavoriteFolder>, Set<String>)> runLoad() async {
        final engine = facade.js.engine;
        if (engine == null) throw Exception('source_not_initialized');
        final hasFavorites = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites'),
        );
        if (!hasFavorites) throw Exception('favorites_not_supported');
        final hasLoadFolders = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
        );
        if (!hasLoadFolders) {
          final hasLoadComics = facade.js.asBool(
            engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
          );
          if (hasLoadComics) {
            return (
              const <FavoriteFolder>[
                FavoriteFolder(id: '0', name: '__favorite_all__'),
              ],
              const <String>{},
            );
          }
          throw Exception('favorite_folders_not_supported');
        }
        final dynamic raw = engine.evaluate(
          'this.__hazuki_source.favorites.loadFolders(${jsonEncode(comicId)})',
          name: 'source_favorite_folders.js',
        );
        final dynamic resolved = await facade.js.resolve(raw);
        if (resolved is! Map) {
          throw Exception('favorite_folders_invalid_response');
        }
        final map = Map<String, dynamic>.from(resolved);
        final folders = <FavoriteFolder>[];
        final foldersRaw = map['folders'];
        if (foldersRaw is Map) {
          for (final entry in Map<String, dynamic>.from(foldersRaw).entries) {
            final id = entry.key.toString();
            if (id.isNotEmpty) {
              folders.add(
                FavoriteFolder(id: id, name: entry.value?.toString() ?? id),
              );
            }
          }
        }
        if (!folders.any((folder) => folder.id == '0')) {
          folders.insert(
            0,
            const FavoriteFolder(id: '0', name: '__favorite_all__'),
          );
        }
        final favorited = <String>{};
        final favoritedRaw = map['favorited'];
        if (favoritedRaw is List) {
          for (final item in favoritedRaw) {
            final id = item?.toString() ?? '';
            if (id.isNotEmpty) favorited.add(id);
          }
        }
        favorited.removeWhere(
          (id) => !folders.any((folder) => folder.id == id),
        );
        final normalizedComicId = comicId?.trim() ?? '';
        if (normalizedComicId.isNotEmpty &&
            favorited.isEmpty &&
            folders.any((folder) => folder.id != '0')) {
          favorited.addAll(
            await _inferFavoritedFolderIds(
              engine: engine,
              comicId: normalizedComicId,
              folders: folders,
              facade: facade,
              sourceKey: resolvedSourceKey,
            ),
          );
        }
        return (folders, favorited);
      }

      final result = await _reloginCoordinator.runWithReloginRetry(
        runLoad,
        context: context,
      );
      return FavoriteFoldersResult.success(
        folders: result.$1,
        favoritedFolderIds: result.$2,
      );
    } catch (error) {
      return FavoriteFoldersResult.error(error.toString());
    }
  }

  Future<Set<String>> _inferFavoritedFolderIds({
    required dynamic engine,
    required String comicId,
    required List<FavoriteFolder> folders,
    required HazukiSourceFacade facade,
    required String sourceKey,
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty ||
        !facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
        )) {
      return const <String>{};
    }
    final inferred = <String>{};
    final singleFolderOnly = favoriteSingleFolderForSingleComicForSource(
      sourceKey,
    );
    for (final folder in folders) {
      final folderId = folder.id.trim();
      if (folderId.isEmpty || folderId == '0') continue;
      final containsComic = await _favoriteFolderContainsComic(
        engine: engine,
        comicId: normalizedComicId,
        folderId: folderId,
        facade: facade,
        sourceKey: sourceKey,
      );
      if (!containsComic) continue;
      inferred.add(folderId);
      if (singleFolderOnly) break;
    }
    return inferred;
  }

  Future<bool> _favoriteFolderContainsComic({
    required dynamic engine,
    required String comicId,
    required String folderId,
    required HazukiSourceFacade facade,
    required String sourceKey,
  }) async {
    final normalizedComicId = comicId.trim();
    final normalizedFolderId = folderId.trim();
    if (normalizedComicId.isEmpty ||
        normalizedFolderId.isEmpty ||
        normalizedFolderId == '0') {
      return false;
    }
    final safeFolderId = normalizedFolderId.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    var page = 1;
    const maxProbePages = 120;
    while (page <= maxProbePages) {
      final dynamic raw = engine.evaluate(
        'this.__hazuki_source.favorites.loadComics($page, ${jsonEncode(normalizedFolderId)})',
        name: 'source_favorite_folder_probe_${safeFolderId}_$page.js',
      );
      final dynamic resolved = await facade.js.resolve(raw);
      if (resolved is! Map) return false;
      final map = Map<String, dynamic>.from(resolved);
      final comicsRaw = map['comics'];
      if (comicsRaw is! List || comicsRaw.isEmpty) return false;
      final comics = _parseExploreComics(comicsRaw, sourceKey: sourceKey);
      if (comics.any((comic) => comic.id == normalizedComicId)) return true;
      final maxPageRaw = map['maxPage'];
      final maxPage = switch (maxPageRaw) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(maxPageRaw?.toString() ?? ''),
      };
      if (maxPage == null || page >= maxPage) return false;
      page++;
    }
    return false;
  }

  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) async {
    final facade = _facadeForSource(sourceKey);
    await facade.ensureInitialized();
    await _reloginCoordinator.runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
      )) {
        throw Exception('favorite_folder_creation_not_supported');
      }
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.addFolder(${jsonEncode(name)})',
        name: 'source_favorite_add_folder.js',
      );
      await facade.js.resolve(result);
    }, context: _reloginContext(facade));
  }

  Future<void> deleteFavoriteFolder(
    String folderId, {
    String sourceKey = '',
  }) async {
    final facade = _facadeForSource(sourceKey);
    await facade.ensureInitialized();
    await _reloginCoordinator.runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
      )) {
        throw Exception('favorite_folder_deletion_not_supported');
      }
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.deleteFolder(${jsonEncode(folderId)})',
        name: 'source_favorite_delete_folder.js',
      );
      await facade.js.resolve(result);
    }, context: _reloginContext(facade));
  }

  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    await facade.ensureInitialized();
    await _reloginCoordinator.runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites'),
      )) {
        throw Exception('favorites_not_supported');
      }
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
      )) {
        throw Exception('favorite_toggle_not_supported');
      }
      final normalizedFolderId = normalizeFolderId(folderId);
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.favorites.addOrDelFavorite(${jsonEncode(comicId)}, ${jsonEncode(normalizedFolderId)}, $isAdding, ${jsonEncode(favoriteId)})',
        name: 'source_toggle_favorite.js',
      );
      await facade.js.resolve(result);
    }, context: _reloginContext(facade));
    if (normalizedComicId.isNotEmpty) {
      _updateComicDetailsFavoriteState(
        sourceKey: resolvedSourceKey,
        comicId: normalizedComicId,
        isFavorite: isAdding,
      );
    }
    _notifyCloudFavoritesChanged();
  }
}
