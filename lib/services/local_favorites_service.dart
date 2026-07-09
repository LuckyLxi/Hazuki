import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/hazuki_models.dart';
import 'local_favorites/local_favorites_contracts.dart';
import 'local_favorites/local_favorites_migration.dart';
import 'local_favorites/local_favorites_models.dart';
import 'local_favorites/local_favorites_persistence.dart';
import 'local_favorites/local_favorites_preferences_store.dart';
import 'local_favorites/local_favorites_sync_codec.dart';
import 'storage/hazuki_database.dart';

class LocalFavoritesService extends ChangeNotifier
    implements LocalFavoritesRepository, LocalFavoritesSyncStore {
  factory LocalFavoritesService({
    HazukiDatabase? database,
    LocalFavoritesPreferencesStore? preferences,
    LocalFavoritesPersistence? persistence,
    LocalFavoritesSyncCodec? syncCodec,
    LocalFavoritesMigration? migration,
  }) {
    final resolvedPersistence =
        persistence ??
        DriftLocalFavoritesPersistence(database ?? HazukiDatabase());
    final resolvedSyncCodec =
        syncCodec ?? LocalFavoritesSyncCodec(resolvedPersistence);
    return LocalFavoritesService._(
      preferences:
          preferences ?? SharedPreferencesLocalFavoritesPreferencesStore(),
      persistence: resolvedPersistence,
      syncCodec: resolvedSyncCodec,
      migration:
          migration ?? LocalFavoritesMigration(syncCodec: resolvedSyncCodec),
    );
  }

  LocalFavoritesService._({
    required LocalFavoritesPreferencesStore preferences,
    required LocalFavoritesPersistence persistence,
    required LocalFavoritesSyncCodec syncCodec,
    required LocalFavoritesMigration migration,
  }) : _preferences = preferences,
       _persistence = persistence,
       _syncCodec = syncCodec,
       _migration = migration;

  final LocalFavoritesPreferencesStore _preferences;
  final LocalFavoritesPersistence _persistence;
  final LocalFavoritesSyncCodec _syncCodec;
  final LocalFavoritesMigration _migration;
  Future<void> _opQueue = Future.value();

  static const int _pageSize = 24;
  static const Set<String> _supportedSortOrders = <String>{
    'mr',
    'mp',
    'dd',
    'da',
    '-datetime_updated',
    '-datetime_modifier',
    '-datetime_browse',
  };

  Future<T> _serialized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _opQueue = _opQueue.whenComplete(() async {
      try {
        completer.complete(await fn());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  void onExternalDataChanged() {
    notifyListeners();
  }

  Future<void> _ensureMigrated() => _migration.ensureMigrated();

  Future<String> loadSortOrder() => _preferences.loadSortOrder();

  Future<void> saveSortOrder(String order) => _preferences.saveSortOrder(order);

  Future<FavoritePageMode> loadFavoritePageMode({String sourceKey = ''}) =>
      _preferences.loadFavoritePageMode(sourceKey: sourceKey);

  Future<void> saveFavoritePageMode(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) => _preferences.saveFavoritePageMode(mode, sourceKey: sourceKey);

  Future<String> loadSelectedFavoriteFolderId(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) => _preferences.loadSelectedFavoriteFolderId(mode, sourceKey: sourceKey);

  Future<void> saveSelectedFavoriteFolderId(
    FavoritePageMode mode,
    String folderId, {
    String sourceKey = '',
  }) => _preferences.saveSelectedFavoriteFolderId(
    mode,
    folderId,
    sourceKey: sourceKey,
  );

  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    await _ensureMigrated();
    final snapshot = await _persistence.load();
    final folders = snapshot.folders
        .where(
          (folder) => _sourceMatches(folder.sourceKey, normalizedSourceKey),
        )
        .map(
          (folder) => FavoriteFolder(
            id: folder.id,
            name: folder.name,
            source: FavoriteFolderSource.local,
          ),
        )
        .toList(growable: false);

    final normalizedComicId = comicId?.trim() ?? '';
    final favoritedFolderIds = <String>{};
    if (normalizedComicId.isNotEmpty) {
      final entry = snapshot.findEntry(
        normalizedComicId,
        sourceKey: normalizedSourceKey,
      );
      if (entry != null) {
        favoritedFolderIds.addAll(entry.folderIds);
      }
    }

    return FavoriteFoldersResult.success(
      folders: folders,
      favoritedFolderIds: favoritedFolderIds,
    );
  }

  @override
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
    String? sortOrder,
    String sourceKey = '',
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    await _ensureMigrated();
    final snapshot = await _persistence.load();
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return const FavoriteComicsResult.success(<ExploreComic>[], maxPage: 1);
    }
    final normalizedSortOrder = _normalizeSortOrder(
      (sortOrder ?? await loadSortOrder()).trim(),
    );

    final filteredEntries = snapshot.entries
        .where(
          (entry) =>
              entry.folderIds.contains(normalizedFolderId) &&
              _sourceMatches(entry.sourceKey, normalizedSourceKey),
        )
        .toList();

    filteredEntries.sort((a, b) {
      if (normalizedSortOrder == 'mp' ||
          normalizedSortOrder == '-datetime_updated') {
        final updateCompare = b.updateTime.compareTo(a.updateTime);
        if (updateCompare != 0) return updateCompare;
      }
      final aMs = a.folderSavedAtMs[normalizedFolderId] ?? 0;
      final bMs = b.folderSavedAtMs[normalizedFolderId] ?? 0;
      return normalizedSortOrder == 'da'
          ? aMs.compareTo(bMs)
          : bMs.compareTo(aMs);
    });

    final totalCount = filteredEntries.length;
    if (totalCount == 0) {
      return const FavoriteComicsResult.success(<ExploreComic>[], maxPage: 1);
    }
    final maxPage = (totalCount / _pageSize).ceil();
    final normalizedPage = page.clamp(1, maxPage);
    final start = (normalizedPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, totalCount);
    final comics = filteredEntries
        .sublist(start, end)
        .map((entry) => entry.toExploreComic(sourceKey: normalizedSourceKey))
        .toList(growable: false);
    return FavoriteComicsResult.success(comics, maxPage: maxPage);
  }

  String _normalizeSortOrder(String order) {
    final normalized = order.trim();
    return _supportedSortOrders.contains(normalized) ? normalized : 'mr';
  }

  @override
  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('favorite_folder_name_required');
    }
    return _serialized(() async {
      await _ensureMigrated();
      final snapshot = await _persistence.load();
      snapshot.folders.add(
        LocalFavoriteFolderRecord(
          id: _nextFavoriteFolderId(snapshot),
          name: normalizedName,
          sourceKey: sourceKey.trim(),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _persistence.replace(snapshot);
      notifyListeners();
    });
  }

  String _nextFavoriteFolderId(LocalFavoritesSnapshot snapshot) {
    var candidate = DateTime.now().microsecondsSinceEpoch;
    final existingIds = snapshot.folders.map((folder) => folder.id).toSet();
    while (existingIds.contains(candidate.toString())) {
      candidate++;
    }
    return candidate.toString();
  }

  @override
  Future<void> renameFavoriteFolder({
    required String folderId,
    required String name,
    String sourceKey = '',
  }) {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      throw Exception('favorite_folder_id_required');
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('favorite_folder_name_required');
    }
    return _serialized(() async {
      await _ensureMigrated();
      final snapshot = await _persistence.load();
      final folderIndex = snapshot.folders.indexWhere(
        (folder) =>
            folder.id == normalizedFolderId &&
            _sourceMatches(folder.sourceKey, sourceKey),
      );
      if (folderIndex < 0) throw Exception('favorite_folder_not_found');
      final current = snapshot.folders[folderIndex];
      snapshot.folders[folderIndex] = LocalFavoriteFolderRecord(
        id: current.id,
        name: normalizedName,
        sourceKey: current.sourceKey,
        updatedAtMs: _timestampAfter(current.updatedAtMs),
      );
      await _persistence.replace(snapshot);
      notifyListeners();
    });
  }

  @override
  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) return Future.value();
    return _serialized(() async {
      await _ensureMigrated();
      final snapshot = await _persistence.load();
      snapshot.folders.removeWhere(
        (folder) =>
            folder.id == normalizedFolderId &&
            _sourceMatches(folder.sourceKey, sourceKey),
      );
      for (final entry in snapshot.entries) {
        if (_sourceMatches(entry.sourceKey, sourceKey)) {
          entry.folderSavedAtMs.remove(normalizedFolderId);
        }
      }
      snapshot.entries.removeWhere((entry) => entry.folderIds.isEmpty);
      await _persistence.replace(snapshot);
      await _persistence.appendFolderTombstone(normalizedFolderId);
      notifyListeners();
    });
  }

  @override
  Future<void> toggleFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
    String sourceKey = '',
  }) {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      throw Exception('favorite_local_folder_required');
    }
    final normalizedComicId = details.id.trim();
    final normalizedSourceKey = sourceKey.trim().isNotEmpty
        ? sourceKey.trim()
        : details.sourceKey.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('favorite_comic_id_required');
    }
    return _serialized(() async {
      await _ensureMigrated();
      final snapshot = await _persistence.load();
      final existingIndex = snapshot.entries.indexWhere(
        (entry) =>
            entry.comicId == normalizedComicId &&
            _sourceMatches(entry.sourceKey, normalizedSourceKey),
      );

      if (isAdding) {
        final storageKey = SourceScopedComicId(
          sourceKey: normalizedSourceKey,
          comicId: normalizedComicId,
        ).storageKey;
        final savedAtMs = await _persistence.nextComicFolderSavedAtMs(
          storageKey,
          normalizedFolderId,
        );
        final record = existingIndex >= 0
            ? snapshot.entries[existingIndex]
            : LocalFavoriteComicRecord(
                comicId: normalizedComicId,
                sourceKey: normalizedSourceKey,
                title: details.title.trim(),
                subTitle: details.subTitle.trim(),
                cover: details.cover.trim(),
                updateTime: details.updateTime.trim(),
                folderSavedAtMs: <String, int>{},
              );
        record
          ..title = details.title.trim()
          ..subTitle = details.subTitle.trim()
          ..cover = details.cover.trim()
          ..updateTime = details.updateTime.trim()
          ..folderSavedAtMs.putIfAbsent(normalizedFolderId, () => savedAtMs);
        if (existingIndex < 0) snapshot.entries.add(record);
      } else if (existingIndex >= 0) {
        final record = snapshot.entries[existingIndex];
        final removedSavedAtMs =
            record.folderSavedAtMs[normalizedFolderId] ?? 0;
        record.folderSavedAtMs.remove(normalizedFolderId);
        await _persistence.appendComicFolderTombstone(
          normalizedComicId,
          normalizedFolderId,
          sourceKey: normalizedSourceKey,
          afterMs: removedSavedAtMs,
        );
        if (record.folderSavedAtMs.isEmpty) {
          snapshot.entries.removeAt(existingIndex);
          await _persistence.replace(snapshot);
          await _persistence.appendEntryTombstone(
            normalizedComicId,
            sourceKey: normalizedSourceKey,
          );
          notifyListeners();
          return;
        }
      }

      await _persistence.replace(snapshot);
      notifyListeners();
    });
  }

  @override
  Future<bool> isComicFavorited(String comicId, {String sourceKey = ''}) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) return false;
    await _ensureMigrated();
    final snapshot = await _persistence.load();
    final entry = snapshot.findEntry(
      normalizedComicId,
      sourceKey: sourceKey.trim(),
    );
    return entry != null && entry.folderIds.isNotEmpty;
  }

  bool _sourceMatches(String storedSourceKey, String requestedSourceKey) {
    final requested = requestedSourceKey.trim();
    if (requested.isEmpty) return true;
    return _effectiveStoredSourceKey(storedSourceKey) == requested;
  }

  String _effectiveStoredSourceKey(String storedSourceKey) {
    final stored = storedSourceKey.trim();
    return stored.isEmpty ? legacyLocalFavoriteSourceKey : stored;
  }

  int _timestampAfter(int value) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > value ? now : value + 1;
  }

  @override
  Future<String> exportFoldersJsonString() async {
    await _ensureMigrated();
    return _syncCodec.exportFoldersJsonString();
  }

  @override
  Future<String> exportEntriesJsonString() async {
    await _ensureMigrated();
    return _syncCodec.exportEntriesJsonString();
  }

  @override
  Future<String> exportFolderTombstonesJsonString() async {
    await _ensureMigrated();
    return _syncCodec.exportFolderTombstonesJsonString();
  }

  @override
  Future<String> exportEntryTombstonesJsonString() async {
    await _ensureMigrated();
    return _syncCodec.exportEntryTombstonesJsonString();
  }

  @override
  Future<String> exportComicFolderTombstonesJsonString() async {
    await _ensureMigrated();
    return _syncCodec.exportComicFolderTombstonesJsonString();
  }

  @override
  Future<void> importJsonStrings({
    String? foldersRaw,
    String? entriesRaw,
    String? folderTombstonesRaw,
    String? entryTombstonesRaw,
    String? comicFolderTombstonesRaw,
    required bool replace,
  }) async {
    await _ensureMigrated();
    await _syncCodec.importJsonStrings(
      foldersRaw: foldersRaw,
      entriesRaw: entriesRaw,
      folderTombstonesRaw: folderTombstonesRaw,
      entryTombstonesRaw: entryTombstonesRaw,
      comicFolderTombstonesRaw: comicFolderTombstonesRaw,
      replace: replace,
    );
    notifyListeners();
  }
}
