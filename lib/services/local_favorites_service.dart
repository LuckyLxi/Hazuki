import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazuki_models.dart';
import 'storage/hazuki_database.dart';

class LocalFavoritesService extends ChangeNotifier {
  LocalFavoritesService({HazukiDatabase? database})
    : _database = database ?? HazukiDatabase();

  final HazukiDatabase _database;
  Future<void> _migration = Future.value();
  Future<void> _opQueue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _opQueue = _opQueue.whenComplete(() async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static const String _foldersKey = 'local_favorite_folders_v1';
  static const String _entriesKey = 'local_favorite_entries_v1';
  static const String _folderTombstonesKey =
      'local_favorite_folder_tombstones_v1';
  static const String _entryTombstonesKey =
      'local_favorite_entry_tombstones_v1';
  static const String _migrationDoneKey = 'local_favorite_drift_migrated_v1';
  static const String _sortOrderKey = 'local_favorite_sort_order_v1';
  static const String _pageModeKey = 'favorite_page_mode_v1';
  static const String _pageModeSourcePrefix = 'favorite_page_mode_source_v1_';
  static const String _selectedCloudFolderKey =
      'favorite_selected_cloud_folder_v1';
  static const String _selectedLocalFolderKey =
      'favorite_selected_local_folder_v1';
  static const String _selectedCloudFolderSourcePrefix =
      'favorite_selected_cloud_folder_source_v1_';
  static const String _selectedLocalFolderSourcePrefix =
      'favorite_selected_local_folder_source_v1_';
  static const String _legacyLocalFavoriteSourceKey = 'jm';
  static const int _tombstoneTtlMs = 90 * 24 * 60 * 60 * 1000;
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

  void onExternalDataChanged() {
    notifyListeners();
  }

  Future<void> _ensureMigrated() {
    _migration = _migration.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationDoneKey) == true) {
        return;
      }
      final store = _LocalFavoritesStore(
        folders: _decodeFolders(prefs.getString(_foldersKey)),
        entries: _decodeEntries(prefs.getString(_entriesKey)),
      );
      await _replaceStore(store);
      await _importFolderTombstonesString(prefs.getString(_folderTombstonesKey));
      await _importEntryTombstonesString(prefs.getString(_entryTombstonesKey));
      await prefs.setBool(_migrationDoneKey, true);
    });
    return _migration;
  }

  Future<String> loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sortOrderKey)?.trim();
    return _supportedSortOrders.contains(raw) ? raw! : 'mr';
  }

  Future<void> saveSortOrder(String order) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = order.trim();
    final normalized = _supportedSortOrders.contains(raw) ? raw : 'mr';
    await prefs.setString(_sortOrderKey, normalized);
  }

  Future<FavoritePageMode> loadFavoritePageMode({String sourceKey = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final sourceScopedKey = _pageModeKeyForSource(sourceKey);
    final raw = sourceScopedKey == null
        ? prefs.getString(_pageModeKey)
        : prefs.getString(sourceScopedKey) ?? prefs.getString(_pageModeKey);
    return raw == 'local' ? FavoritePageMode.local : FavoritePageMode.cloud;
  }

  Future<void> saveFavoritePageMode(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sourceScopedKey = _pageModeKeyForSource(sourceKey);
    await prefs.setString(
      sourceScopedKey ?? _pageModeKey,
      mode == FavoritePageMode.local ? 'local' : 'cloud',
    );
  }

  String? _pageModeKeyForSource(String sourceKey) {
    final normalized = sourceKey.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return '$_pageModeSourcePrefix${Uri.encodeComponent(normalized)}';
  }

  Future<String> loadSelectedFavoriteFolderId(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = mode == FavoritePageMode.local
        ? _selectedLocalFolderKey
        : _selectedCloudFolderKey;
    final sourceScopedKey = _selectedFolderKeyForSource(mode, sourceKey);
    final raw =
        (sourceScopedKey == null
                ? prefs.getString(legacyKey)
                : prefs.getString(sourceScopedKey) ??
                      prefs.getString(legacyKey))
            ?.trim() ??
        '';
    if (mode == FavoritePageMode.cloud && raw.isEmpty) {
      return '0';
    }
    return raw;
  }

  Future<void> saveSelectedFavoriteFolderId(
    FavoritePageMode mode,
    String folderId, {
    String sourceKey = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        _selectedFolderKeyForSource(mode, sourceKey) ??
        (mode == FavoritePageMode.local
            ? _selectedLocalFolderKey
            : _selectedCloudFolderKey);
    final normalized = folderId.trim();
    if (mode == FavoritePageMode.local && normalized.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(
      key,
      mode == FavoritePageMode.cloud && normalized.isEmpty ? '0' : normalized,
    );
  }

  String? _selectedFolderKeyForSource(FavoritePageMode mode, String sourceKey) {
    final normalized = sourceKey.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final prefix = mode == FavoritePageMode.local
        ? _selectedLocalFolderSourcePrefix
        : _selectedCloudFolderSourcePrefix;
    return '$prefix${Uri.encodeComponent(normalized)}';
  }

  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    await _ensureMigrated();
    final store = await _loadStore();
    final folders = store.folders
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
      final entry = store.findEntry(
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

  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
    String? sortOrder,
    String sourceKey = '',
  }) async {
    final normalizedSourceKey = sourceKey.trim();
    await _ensureMigrated();
    final store = await _loadStore();
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return const FavoriteComicsResult.success(<ExploreComic>[], maxPage: 1);
    }
    final normalizedSortOrder = _normalizeSortOrder(
      (sortOrder ?? await loadSortOrder()).trim(),
    );

    final filteredEntries = store.entries
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
        if (updateCompare != 0) {
          return updateCompare;
        }
      }
      final aMs = a.folderSavedAtMs[normalizedFolderId] ?? 0;
      final bMs = b.folderSavedAtMs[normalizedFolderId] ?? 0;
      if (normalizedSortOrder == 'da') {
        return aMs.compareTo(bMs);
      }
      return bMs.compareTo(aMs);
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

  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('favorite_folder_name_required');
    }
    return _serialized(() async {
      await _ensureMigrated();
      final store = await _loadStore();
      store.folders.add(
        _LocalFavoriteFolderRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: normalizedName,
          sourceKey: sourceKey.trim(),
        ),
      );
      await _saveStore(store);
      notifyListeners();
    });
  }

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
      final store = await _loadStore();
      final folderIndex = store.folders.indexWhere(
        (folder) =>
            folder.id == normalizedFolderId &&
            _sourceMatches(folder.sourceKey, sourceKey),
      );
      if (folderIndex < 0) {
        throw Exception('favorite_folder_not_found');
      }
      final current = store.folders[folderIndex];
      store.folders[folderIndex] = _LocalFavoriteFolderRecord(
        id: current.id,
        name: normalizedName,
        sourceKey: current.sourceKey,
      );
      await _saveStore(store);
      notifyListeners();
    });
  }

  Future<void> deleteFavoriteFolder(String folderId, {String sourceKey = ''}) {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return Future.value();
    }
    return _serialized(() async {
      await _ensureMigrated();
      final store = await _loadStore();
      store.folders.removeWhere(
        (folder) =>
            folder.id == normalizedFolderId &&
            _sourceMatches(folder.sourceKey, sourceKey),
      );
      for (final entry in store.entries) {
        if (_sourceMatches(entry.sourceKey, sourceKey)) {
          entry.folderSavedAtMs.remove(normalizedFolderId);
        }
      }
      store.entries.removeWhere((entry) => entry.folderIds.isEmpty);
      await _saveStore(store);
      await _appendFolderTombstone(normalizedFolderId);
      notifyListeners();
    });
  }

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
      final store = await _loadStore();

      final existingIndex = store.entries.indexWhere(
        (entry) =>
            entry.comicId == normalizedComicId &&
            _sourceMatches(entry.sourceKey, normalizedSourceKey),
      );

      if (isAdding) {
        final record = existingIndex >= 0
            ? store.entries[existingIndex]
            : _LocalFavoriteComicRecord(
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
          ..folderSavedAtMs.putIfAbsent(
            normalizedFolderId,
            () => DateTime.now().millisecondsSinceEpoch,
          );

        if (existingIndex < 0) {
          store.entries.add(record);
        }
      } else if (existingIndex >= 0) {
        final record = store.entries[existingIndex];
        record.folderSavedAtMs.remove(normalizedFolderId);
        if (record.folderSavedAtMs.isEmpty) {
          store.entries.removeAt(existingIndex);
          await _saveStore(store);
          await _appendEntryTombstone(
            normalizedComicId,
            sourceKey: normalizedSourceKey,
          );
          notifyListeners();
          return;
        }
      }

      await _saveStore(store);
      notifyListeners();
    });
  }

  Future<bool> isComicFavorited(String comicId, {String sourceKey = ''}) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      return false;
    }
    await _ensureMigrated();
    final store = await _loadStore();
    final entry = store.findEntry(
      normalizedComicId,
      sourceKey: sourceKey.trim(),
    );
    return entry != null && entry.folderIds.isNotEmpty;
  }

  bool _sourceMatches(String storedSourceKey, String requestedSourceKey) {
    final requested = requestedSourceKey.trim();
    if (requested.isEmpty) {
      return true;
    }
    return _effectiveStoredSourceKey(storedSourceKey) == requested;
  }

  String _effectiveStoredSourceKey(String storedSourceKey) {
    final stored = storedSourceKey.trim();
    return stored.isEmpty ? _legacyLocalFavoriteSourceKey : stored;
  }

  Future<void> _appendFolderTombstone(String folderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.into(_database.localFavoriteFolderTombstones).insertOnConflictUpdate(
      LocalFavoriteFolderTombstonesCompanion.insert(
        folderId: folderId,
        deletedAtMs: now,
      ),
    );
    await _pruneTombstones();
  }

  Future<void> _appendEntryTombstone(
    String comicId, {
    String sourceKey = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedSourceKey = sourceKey.trim();
    final storageKey = SourceScopedComicId(
      sourceKey: normalizedSourceKey,
      comicId: comicId,
    ).storageKey;
    await _database.into(_database.localFavoriteEntryTombstones).insertOnConflictUpdate(
      LocalFavoriteEntryTombstonesCompanion.insert(
        storageKey: storageKey,
        comicId: comicId,
        sourceKey: Value(normalizedSourceKey),
        deletedAtMs: now,
      ),
    );
    await _pruneTombstones();
  }

  List<Map<String, dynamic>> _decodeTombstones(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<_LocalFavoritesStore> _loadStore() async {
    final folders = await (_database.select(_database.localFavoriteFolders)).get();
    final comics = await (_database.select(_database.localFavoriteComics)).get();
    final joins = await (_database.select(_database.localFavoriteComicFolders)).get();
    final folderSavedAtByComic = <String, Map<String, int>>{};
    for (final item in joins) {
      (folderSavedAtByComic[item.comicStorageKey] ??= <String, int>{})[
          item.folderId] = item.savedAtMs;
    }
    return _LocalFavoritesStore(
      folders: folders
          .map(
            (folder) => _LocalFavoriteFolderRecord(
              id: folder.id,
              name: folder.name,
              sourceKey: folder.sourceKey,
            ),
          )
          .toList(growable: true),
      entries: comics
          .map(
            (comic) => _LocalFavoriteComicRecord(
              comicId: comic.comicId,
              sourceKey: comic.sourceKey,
              title: comic.title,
              subTitle: comic.subTitle,
              cover: comic.cover,
              updateTime: comic.updateTime,
              folderSavedAtMs:
                  folderSavedAtByComic[comic.storageKey] ?? <String, int>{},
            ),
          )
          .where((entry) => entry.comicId.isNotEmpty && entry.folderIds.isNotEmpty)
          .toList(growable: true),
    );
  }

  Future<void> _saveStore(_LocalFavoritesStore store) async {
    await _replaceStore(store);
  }

  Future<void> _replaceStore(_LocalFavoritesStore store) async {
    await _database.transaction(() async {
      await _database.delete(_database.localFavoriteComicFolders).go();
      await _database.delete(_database.localFavoriteComics).go();
      await _database.delete(_database.localFavoriteFolders).go();
      for (final folder in store.folders) {
        await _database.into(_database.localFavoriteFolders).insertOnConflictUpdate(
          LocalFavoriteFoldersCompanion.insert(
            id: folder.id,
            name: folder.name,
            sourceKey: Value(folder.sourceKey),
          ),
        );
      }
      for (final entry in store.entries) {
        if (entry.comicId.isEmpty || entry.folderSavedAtMs.isEmpty) {
          continue;
        }
        final storageKey = SourceScopedComicId(
          sourceKey: entry.sourceKey,
          comicId: entry.comicId,
        ).storageKey;
        await _database.into(_database.localFavoriteComics).insertOnConflictUpdate(
          LocalFavoriteComicsCompanion.insert(
            storageKey: storageKey,
            comicId: entry.comicId,
            sourceKey: Value(entry.sourceKey),
            title: entry.title,
            subTitle: entry.subTitle,
            cover: entry.cover,
            updateTime: entry.updateTime,
          ),
        );
        for (final saved in entry.folderSavedAtMs.entries) {
          await _database.into(_database.localFavoriteComicFolders).insertOnConflictUpdate(
            LocalFavoriteComicFoldersCompanion.insert(
              comicStorageKey: storageKey,
              folderId: saved.key,
              savedAtMs: saved.value,
            ),
          );
        }
      }
    });
  }

  Future<String> exportFoldersJsonString() async {
    await _ensureMigrated();
    final store = await _loadStore();
    return jsonEncode(store.folders.map((folder) => folder.toJson()).toList());
  }

  Future<String> exportEntriesJsonString() async {
    await _ensureMigrated();
    final store = await _loadStore();
    return jsonEncode(store.entries.map((entry) => entry.toJson()).toList());
  }

  Future<String> exportFolderTombstonesJsonString() async {
    await _ensureMigrated();
    await _pruneTombstones();
    final rows = await (_database.select(_database.localFavoriteFolderTombstones)).get();
    return jsonEncode(
      rows
          .map((row) => {'id': row.folderId, 'deletedAtMs': row.deletedAtMs})
          .toList(),
    );
  }

  Future<String> exportEntryTombstonesJsonString() async {
    await _ensureMigrated();
    await _pruneTombstones();
    final rows = await (_database.select(_database.localFavoriteEntryTombstones)).get();
    return jsonEncode(
      rows
          .map(
            (row) => {
              'comicId': row.comicId,
              if (row.sourceKey.isNotEmpty) 'sourceKey': row.sourceKey,
              'deletedAtMs': row.deletedAtMs,
            },
          )
          .toList(),
    );
  }

  Future<void> importJsonStrings({
    String? foldersRaw,
    String? entriesRaw,
    String? folderTombstonesRaw,
    String? entryTombstonesRaw,
    required bool replace,
  }) async {
    await _ensureMigrated();
    final folders = _decodeFolders(foldersRaw);
    final entries = _decodeEntries(entriesRaw);
    if (replace) {
      await _replaceStore(_LocalFavoritesStore(folders: folders, entries: entries));
    } else {
      final store = await _loadStore();
      final folderById = <String, _LocalFavoriteFolderRecord>{
        for (final folder in store.folders) folder.id: folder,
      };
      for (final folder in folders) {
        folderById.putIfAbsent(folder.id, () => folder);
      }
      final entryByKey = <String, _LocalFavoriteComicRecord>{
        for (final entry in store.entries)
          SourceScopedComicId(sourceKey: entry.sourceKey, comicId: entry.comicId).storageKey:
              entry,
      };
      for (final entry in entries) {
        final key = SourceScopedComicId(
          sourceKey: entry.sourceKey,
          comicId: entry.comicId,
        ).storageKey;
        final existing = entryByKey[key];
        if (existing == null || entry.savedAtMs > existing.savedAtMs) {
          entryByKey[key] = entry;
        }
      }
      await _replaceStore(
        _LocalFavoritesStore(
          folders: folderById.values.toList(growable: true),
          entries: entryByKey.values.toList(growable: true),
        ),
      );
    }
    await _importFolderTombstonesString(folderTombstonesRaw);
    await _importEntryTombstonesString(entryTombstonesRaw);
    notifyListeners();
  }

  Future<void> _importFolderTombstonesString(String? raw) async {
    for (final item in _decodeTombstones(raw)) {
      final id = (item['id'] ?? '').toString().trim();
      final deletedAtMs = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (id.isEmpty || deletedAtMs <= 0) {
        continue;
      }
      await _database.into(_database.localFavoriteFolderTombstones).insertOnConflictUpdate(
        LocalFavoriteFolderTombstonesCompanion.insert(
          folderId: id,
          deletedAtMs: deletedAtMs,
        ),
      );
    }
    await _pruneTombstones();
  }

  Future<void> _importEntryTombstonesString(String? raw) async {
    for (final item in _decodeTombstones(raw)) {
      final comicId = (item['comicId'] ?? '').toString().trim();
      final sourceKey = (item['sourceKey'] ?? '').toString().trim();
      final deletedAtMs = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (comicId.isEmpty || deletedAtMs <= 0) {
        continue;
      }
      final storageKey = SourceScopedComicId(
        sourceKey: sourceKey,
        comicId: comicId,
      ).storageKey;
      await _database.into(_database.localFavoriteEntryTombstones).insertOnConflictUpdate(
        LocalFavoriteEntryTombstonesCompanion.insert(
          storageKey: storageKey,
          comicId: comicId,
          sourceKey: Value(sourceKey),
          deletedAtMs: deletedAtMs,
        ),
      );
    }
    await _pruneTombstones();
  }

  Future<void> _pruneTombstones() async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _tombstoneTtlMs;
    await (_database.delete(_database.localFavoriteFolderTombstones)
      ..where((row) => row.deletedAtMs.isSmallerThanValue(cutoff))).go();
    await (_database.delete(_database.localFavoriteEntryTombstones)
      ..where((row) => row.deletedAtMs.isSmallerThanValue(cutoff))).go();
  }

  List<_LocalFavoriteFolderRecord> _decodeFolders(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <_LocalFavoriteFolderRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_LocalFavoriteFolderRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _LocalFavoriteFolderRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((folder) => folder.id.isNotEmpty)
          .toList(growable: true);
    } catch (_) {
      return <_LocalFavoriteFolderRecord>[];
    }
  }

  List<_LocalFavoriteComicRecord> _decodeEntries(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <_LocalFavoriteComicRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <_LocalFavoriteComicRecord>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => _LocalFavoriteComicRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (entry) => entry.comicId.isNotEmpty && entry.folderIds.isNotEmpty,
          )
          .toList(growable: true);
    } catch (_) {
      return <_LocalFavoriteComicRecord>[];
    }
  }
}

class _LocalFavoritesStore {
  _LocalFavoritesStore({required this.folders, required this.entries});

  final List<_LocalFavoriteFolderRecord> folders;
  final List<_LocalFavoriteComicRecord> entries;

  _LocalFavoriteComicRecord? findEntry(
    String comicId, {
    String sourceKey = '',
  }) {
    for (final entry in entries) {
      final requested = sourceKey.trim();
      final storedSourceKey = entry.sourceKey.trim().isEmpty
          ? LocalFavoritesService._legacyLocalFavoriteSourceKey
          : entry.sourceKey.trim();
      if (entry.comicId == comicId &&
          (requested.isEmpty || storedSourceKey == requested)) {
        return entry;
      }
    }
    return null;
  }
}

class _LocalFavoriteFolderRecord {
  _LocalFavoriteFolderRecord({
    required this.id,
    required this.name,
    required this.sourceKey,
  });

  factory _LocalFavoriteFolderRecord.fromJson(Map<String, dynamic> json) {
    return _LocalFavoriteFolderRecord(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      sourceKey: (json['sourceKey'] ?? '').toString().trim(),
    );
  }

  final String id;
  final String name;
  final String sourceKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
  };
}

class _LocalFavoriteComicRecord {
  _LocalFavoriteComicRecord({
    required this.comicId,
    required this.sourceKey,
    required this.title,
    required this.subTitle,
    required this.cover,
    required this.updateTime,
    required Map<String, int> folderSavedAtMs,
  }) : folderSavedAtMs = Map<String, int>.from(folderSavedAtMs);

  factory _LocalFavoriteComicRecord.fromJson(Map<String, dynamic> json) {
    final folderSavedAtMs = <String, int>{};

    final folderSavedAtMsRaw = json['folderSavedAtMs'];
    if (folderSavedAtMsRaw is Map) {
      for (final entry in folderSavedAtMsRaw.entries) {
        final id = entry.key?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          folderSavedAtMs[id] =
              (entry.value as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch;
        }
      }
    }

    // 旧格式迁移：folderIds 列表 + savedAtMs 全局时间戳
    if (folderSavedAtMs.isEmpty) {
      final fallbackMs =
          (json['savedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      final folderIdsRaw = json['folderIds'];
      if (folderIdsRaw is List) {
        for (final item in folderIdsRaw) {
          final id = item?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            folderSavedAtMs[id] = fallbackMs;
          }
        }
      }
    }

    return _LocalFavoriteComicRecord(
      comicId: (json['comicId'] ?? '').toString().trim(),
      sourceKey: (json['sourceKey'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString(),
      subTitle: (json['subTitle'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      updateTime: (json['updateTime'] ?? '').toString(),
      folderSavedAtMs: folderSavedAtMs,
    );
  }

  final String comicId;
  final String sourceKey;
  String title;
  String subTitle;
  String cover;
  String updateTime;
  final Map<String, int> folderSavedAtMs;

  int get savedAtMs {
    var latest = 0;
    for (final savedAtMs in folderSavedAtMs.values) {
      if (savedAtMs > latest) {
        latest = savedAtMs;
      }
    }
    return latest;
  }

  Set<String> get folderIds => folderSavedAtMs.keys.toSet();

  ExploreComic toExploreComic({String sourceKey = ''}) {
    final resolvedSourceKey = this.sourceKey.trim().isNotEmpty
        ? this.sourceKey
        : sourceKey.trim();
    return ExploreComic(
      id: comicId,
      title: title,
      subTitle: subTitle,
      cover: cover,
      sourceKey: resolvedSourceKey,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'comicId': comicId,
    if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
    'title': title,
    'subTitle': subTitle,
    'cover': cover,
    'updateTime': updateTime,
    'savedAtMs': savedAtMs,
    'folderIds': folderIds.toList(growable: false),
    'folderSavedAtMs': folderSavedAtMs,
  };
}
