import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazuki_models.dart';

class LocalFavoritesService extends ChangeNotifier {
  LocalFavoritesService._();

  static final LocalFavoritesService instance = LocalFavoritesService._();

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
  static const String _sortOrderKey = 'local_favorite_sort_order_v1';
  static const String _pageModeKey = 'favorite_page_mode_v1';
  static const String _selectedCloudFolderKey =
      'favorite_selected_cloud_folder_v1';
  static const String _selectedLocalFolderKey =
      'favorite_selected_local_folder_v1';
  static const int _tombstoneTtlMs = 90 * 24 * 60 * 60 * 1000;
  static const int _pageSize = 24;

  void onExternalDataChanged() {
    notifyListeners();
  }

  Future<String> loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sortOrderKey)?.trim();
    return raw == 'mp' ? 'mp' : 'mr';
  }

  Future<void> saveSortOrder(String order) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = order.trim() == 'mp' ? 'mp' : 'mr';
    await prefs.setString(_sortOrderKey, normalized);
  }

  Future<FavoritePageMode> loadFavoritePageMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pageModeKey);
    return raw == 'local' ? FavoritePageMode.local : FavoritePageMode.cloud;
  }

  Future<void> saveFavoritePageMode(FavoritePageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pageModeKey,
      mode == FavoritePageMode.local ? 'local' : 'cloud',
    );
  }

  Future<String> loadSelectedFavoriteFolderId(FavoritePageMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = mode == FavoritePageMode.local
        ? _selectedLocalFolderKey
        : _selectedCloudFolderKey;
    final raw = prefs.getString(key)?.trim() ?? '';
    if (mode == FavoritePageMode.cloud && raw.isEmpty) {
      return '0';
    }
    return raw;
  }

  Future<void> saveSelectedFavoriteFolderId(
    FavoritePageMode mode,
    String folderId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = mode == FavoritePageMode.local
        ? _selectedLocalFolderKey
        : _selectedCloudFolderKey;
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

  Future<FavoriteFoldersResult> loadFavoriteFolders({String? comicId}) async {
    final store = await _loadStore();
    final folders = store.folders
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
      final entry = store.findEntry(normalizedComicId);
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
  }) async {
    final store = await _loadStore();
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return const FavoriteComicsResult.success(<ExploreComic>[], maxPage: 1);
    }
    final normalizedSortOrder =
        (sortOrder ?? await loadSortOrder()).trim() == 'mp' ? 'mp' : 'mr';

    final filteredEntries = store.entries
        .where((entry) => entry.folderIds.contains(normalizedFolderId))
        .toList();

    filteredEntries.sort((a, b) {
      if (normalizedSortOrder == 'mp') {
        final updateCompare = b.updateTime.compareTo(a.updateTime);
        if (updateCompare != 0) {
          return updateCompare;
        }
      }
      final aMs = a.folderSavedAtMs[normalizedFolderId] ?? 0;
      final bMs = b.folderSavedAtMs[normalizedFolderId] ?? 0;
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
        .map((entry) => entry.toExploreComic())
        .toList(growable: false);

    return FavoriteComicsResult.success(comics, maxPage: maxPage);
  }

  Future<void> addFavoriteFolder(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('favorite_folder_name_required');
    }
    return _serialized(() async {
      final store = await _loadStore();
      store.folders.add(
        _LocalFavoriteFolderRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: normalizedName,
        ),
      );
      await _saveStore(store);
      notifyListeners();
    });
  }

  Future<void> renameFavoriteFolder({
    required String folderId,
    required String name,
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
      final store = await _loadStore();
      final folderIndex = store.folders.indexWhere(
        (folder) => folder.id == normalizedFolderId,
      );
      if (folderIndex < 0) {
        throw Exception('favorite_folder_not_found');
      }
      final current = store.folders[folderIndex];
      store.folders[folderIndex] = _LocalFavoriteFolderRecord(
        id: current.id,
        name: normalizedName,
      );
      await _saveStore(store);
      notifyListeners();
    });
  }

  Future<void> deleteFavoriteFolder(String folderId) {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return Future.value();
    }
    return _serialized(() async {
      final store = await _loadStore();
      store.folders.removeWhere((folder) => folder.id == normalizedFolderId);
      for (final entry in store.entries) {
        entry.folderSavedAtMs.remove(normalizedFolderId);
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
  }) {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      throw Exception('favorite_local_folder_required');
    }
    final normalizedComicId = details.id.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('favorite_comic_id_required');
    }
    return _serialized(() async {
      final store = await _loadStore();

      final existingIndex = store.entries.indexWhere(
        (entry) => entry.comicId == normalizedComicId,
      );

      if (isAdding) {
        final record = existingIndex >= 0
            ? store.entries[existingIndex]
            : _LocalFavoriteComicRecord(
                comicId: normalizedComicId,
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
          await _appendEntryTombstone(normalizedComicId);
          notifyListeners();
          return;
        }
      }

      await _saveStore(store);
      notifyListeners();
    });
  }

  Future<bool> isComicFavorited(String comicId) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      return false;
    }
    final store = await _loadStore();
    final entry = store.findEntry(normalizedComicId);
    return entry != null && entry.folderIds.isNotEmpty;
  }

  Future<void> _appendFolderTombstone(String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final tombstones = _decodeTombstones(prefs.getString(_folderTombstonesKey));
    tombstones.removeWhere((t) => t['id'] == folderId);
    tombstones.add({'id': folderId, 'deletedAtMs': now});
    final cutoff = now - _tombstoneTtlMs;
    tombstones.removeWhere(
      (t) => ((t['deletedAtMs'] as num?)?.toInt() ?? 0) < cutoff,
    );
    await prefs.setString(_folderTombstonesKey, jsonEncode(tombstones));
  }

  Future<void> _appendEntryTombstone(String comicId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final tombstones = _decodeTombstones(prefs.getString(_entryTombstonesKey));
    tombstones.removeWhere((t) => t['comicId'] == comicId);
    tombstones.add({'comicId': comicId, 'deletedAtMs': now});
    final cutoff = now - _tombstoneTtlMs;
    tombstones.removeWhere(
      (t) => ((t['deletedAtMs'] as num?)?.toInt() ?? 0) < cutoff,
    );
    await prefs.setString(_entryTombstonesKey, jsonEncode(tombstones));
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
    final prefs = await SharedPreferences.getInstance();
    return _LocalFavoritesStore(
      folders: _decodeFolders(prefs.getString(_foldersKey)),
      entries: _decodeEntries(prefs.getString(_entriesKey)),
    );
  }

  Future<void> _saveStore(_LocalFavoritesStore store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _foldersKey,
      jsonEncode(store.folders.map((folder) => folder.toJson()).toList()),
    );
    await prefs.setString(
      _entriesKey,
      jsonEncode(store.entries.map((entry) => entry.toJson()).toList()),
    );
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

  _LocalFavoriteComicRecord? findEntry(String comicId) {
    for (final entry in entries) {
      if (entry.comicId == comicId) {
        return entry;
      }
    }
    return null;
  }
}

class _LocalFavoriteFolderRecord {
  _LocalFavoriteFolderRecord({required this.id, required this.name});

  factory _LocalFavoriteFolderRecord.fromJson(Map<String, dynamic> json) {
    return _LocalFavoriteFolderRecord(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
    );
  }

  final String id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}

class _LocalFavoriteComicRecord {
  _LocalFavoriteComicRecord({
    required this.comicId,
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
      title: (json['title'] ?? '').toString(),
      subTitle: (json['subTitle'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      updateTime: (json['updateTime'] ?? '').toString(),
      folderSavedAtMs: folderSavedAtMs,
    );
  }

  final String comicId;
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

  ExploreComic toExploreComic() {
    return ExploreComic(
      id: comicId,
      title: title,
      subTitle: subTitle,
      cover: cover,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'comicId': comicId,
    'title': title,
    'subTitle': subTitle,
    'cover': cover,
    'updateTime': updateTime,
    'savedAtMs': savedAtMs,
    'folderIds': folderIds.toList(growable: false),
    'folderSavedAtMs': folderSavedAtMs,
  };
}
