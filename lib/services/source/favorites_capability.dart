part of '../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesCapability on HazukiSourceService {
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) async {
    try {
      await _ensureFavoriteSessionReady();
      final result = await _runWithReloginRetry(() async {
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

        final hasLoadComics = _asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
        );
        final hasLoadNext = _asBool(
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
          final dynamic resolved = await _awaitJsResult(raw);
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
              final hasLoadFolders = _asBool(
                engine.evaluate(
                  '!!this.__hazuki_source.favorites?.loadFolders',
                ),
              );
              if (hasLoadFolders) {
                final dynamic foldersRaw = engine.evaluate(
                  'this.__hazuki_source.favorites.loadFolders(null)',
                  name: 'source_favorite_folders_for_all.js',
                );
                final dynamic foldersResolved = await _awaitJsResult(
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
          final dynamic resolved = await _awaitJsResult(raw);
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
      await _ensureFavoriteSessionReady();
      final result = await _runWithReloginRetry(() async {
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

        final hasLoadFolders = _asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
        );
        if (!hasLoadFolders) {
          throw Exception('favorite_folders_not_supported');
        }

        final dynamic raw = engine.evaluate(
          'this.__hazuki_source.favorites.loadFolders(${jsonEncode(comicId)})',
          name: 'source_favorite_folders.js',
        );
        final dynamic resolved = await _awaitJsResult(raw);
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

  bool get favoriteSingleFolderForSingleComic {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate(
        'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
      ),
    );
  }

  bool get supportFavoriteFolderManagement {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  bool get supportFavoriteFolderAdd {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
    );
  }

  bool get supportFavoriteFolderDelete {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
    );
  }

  bool get supportFavoriteFolderLoad {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  String get favoriteSortOrder {
    final sourceMeta = _sourceMeta;
    if (sourceMeta == null) {
      return 'mr';
    }
    final raw = _loadSourceSetting(sourceMeta.key, 'favoriteOrder');
    final normalized = raw?.toString().trim() ?? '';
    if (normalized == 'mp') {
      return 'mp';
    }
    return 'mr';
  }

  Future<void> setFavoriteSortOrder(String order) async {
    final sourceMeta = _sourceMeta;
    if (sourceMeta == null) {
      throw Exception('source_not_initialized');
    }
    final normalized = order.trim() == 'mp' ? 'mp' : 'mr';
    await _saveSourceSetting(sourceMeta.key, 'favoriteOrder', normalized);
  }

  bool get supportFavoriteSortOrder {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.settings?.favoriteOrder'),
    );
  }

  bool get supportFavoriteLoadComics {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
    );
  }

  bool get supportFavoriteLoadNext {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadNext'),
    );
  }

  bool get supportFavoriteToggle {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
    );
  }

  bool get supportCommentSend {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.comic?.sendComment'),
    );
  }
}
