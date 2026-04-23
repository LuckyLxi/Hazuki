part of '../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesCollectionCapability
    on HazukiSourceService {
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) async {
    try {
      final facade = this.facade;
      await _ensureFavoriteSessionReady();
      final result = await _runWithReloginRetry(() async {
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

        final hasLoadComics = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
        );
        final hasLoadNext = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadNext'),
        );

        if (!hasLoadComics && !hasLoadNext) {
          throw Exception('favorite_comics_loading_not_supported');
        }

        final normalizedFolderId = folderId.trim().isEmpty
            ? '0'
            : folderId.trim();

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
              } catch (_) {
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
                if (loadedMaxPage != null) {
                  final currentMaxPage = maxPage;
                  if (currentMaxPage == null ||
                      loadedMaxPage > currentMaxPage) {
                    maxPage = loadedMaxPage;
                  }
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
                  final map = Map<String, dynamic>.from(foldersResolved);
                  final folders = map['folders'];
                  if (folders is Map) {
                    for (final entry in folders.entries) {
                      final id = entry.key.toString().trim();
                      if (id.isNotEmpty && id != '0') {
                        folderIds.add(id);
                      }
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
                  if (loadedMaxPage != null) {
                    final currentMaxPage = maxPage;
                    if (currentMaxPage == null ||
                        loadedMaxPage > currentMaxPage) {
                      maxPage = loadedMaxPage;
                    }
                  }
                }
              }
            }
          }
        } else {
          final folderArg = jsonEncode(normalizedFolderId);
          final dynamic raw = engine.evaluate(
            'this.__hazuki_source.favorites.loadNext(null, $folderArg)',
            name: 'source_favorite_next.js',
          );
          final dynamic resolved = await facade.js.resolve(raw);
          if (resolved is Map) {
            final map = Map<String, dynamic>.from(resolved);
            final comicsRaw = map['comics'];
            if (comicsRaw is List) {
              allComics.addAll(_parseExploreComics(comicsRaw));
            }
          }
        }

        final merged = <String, ExploreComic>{};
        for (final comic in allComics) {
          if (comic.id.isEmpty) {
            continue;
          }
          merged[comic.id] = comic;
        }
        return (merged.values.toList(), maxPage);
      });
      return FavoriteComicsResult.success(result.$1, maxPage: result.$2);
    } catch (e) {
      return FavoriteComicsResult.error(e.toString());
    }
  }

  Future<FavoriteFoldersResult> loadFavoriteFolders({String? comicId}) async {
    try {
      final facade = this.facade;
      await _ensureFavoriteSessionReady();
      final result = await _runWithReloginRetry(() async {
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

        final hasLoadFolders = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
        );
        if (!hasLoadFolders) {
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
        final foldersRaw = map['folders'];
        final favoritedRaw = map['favorited'];

        final folders = <FavoriteFolder>[];
        if (foldersRaw is Map) {
          final pairs = Map<String, dynamic>.from(foldersRaw);
          for (final entry in pairs.entries) {
            final id = entry.key.toString();
            final name = entry.value?.toString() ?? id;
            if (id.isEmpty) {
              continue;
            }
            folders.add(FavoriteFolder(id: id, name: name));
          }
        }

        if (!folders.any((e) => e.id == '0')) {
          folders.insert(
            0,
            const FavoriteFolder(id: '0', name: '__favorite_all__'),
          );
        }

        final favorited = <String>{};
        if (favoritedRaw is List) {
          for (final item in favoritedRaw) {
            final id = item?.toString() ?? '';
            if (id.isNotEmpty) {
              favorited.add(id);
            }
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
            ),
          );
        }

        return (folders, favorited);
      });

      return FavoriteFoldersResult.success(
        folders: result.$1,
        favoritedFolderIds: result.$2,
      );
    } catch (e) {
      return FavoriteFoldersResult.error(e.toString());
    }
  }

  Future<Set<String>> _inferFavoritedFolderIds({
    required dynamic engine,
    required String comicId,
    required List<FavoriteFolder> folders,
  }) async {
    final facade = this.facade;
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      return const <String>{};
    }
    final hasLoadComics = facade.js.asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
    );
    if (!hasLoadComics) {
      return const <String>{};
    }

    final inferred = <String>{};
    final singleFolderOnly = favoriteSingleFolderForSingleComic;
    for (final folder in folders) {
      final folderId = folder.id.trim();
      if (folderId.isEmpty || folderId == '0') {
        continue;
      }
      final containsComic = await _favoriteFolderContainsComic(
        engine: engine,
        comicId: normalizedComicId,
        folderId: folderId,
      );
      if (!containsComic) {
        continue;
      }
      inferred.add(folderId);
      if (singleFolderOnly) {
        break;
      }
    }
    return inferred;
  }

  Future<bool> _favoriteFolderContainsComic({
    required dynamic engine,
    required String comicId,
    required String folderId,
  }) async {
    final facade = this.facade;
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
      if (resolved is! Map) {
        return false;
      }

      final map = Map<String, dynamic>.from(resolved);
      final comicsRaw = map['comics'];
      if (comicsRaw is! List || comicsRaw.isEmpty) {
        return false;
      }

      final comics = _parseExploreComics(comicsRaw);
      if (comics.any((comic) => comic.id == normalizedComicId)) {
        return true;
      }

      final maxPageRaw = map['maxPage'];
      final maxPage = switch (maxPageRaw) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(maxPageRaw?.toString() ?? ''),
      };
      if (maxPage == null || page >= maxPage) {
        return false;
      }
      page++;
    }

    return false;
  }
}
