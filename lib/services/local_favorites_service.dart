import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazuki_models.dart';

class LocalFavoritesService extends ChangeNotifier {
  LocalFavoritesService._();

  static final LocalFavoritesService instance = LocalFavoritesService._();

  static const String _foldersKey = 'local_favorite_folders_v1';
  static const String _entriesKey = 'local_favorite_entries_v1';
  static const String _sortOrderKey = 'local_favorite_sort_order_v1';
  static const String _pageModeKey = 'favorite_page_mode_v1';
  static const int _pageSize = 24;

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
      return b.savedAtMs.compareTo(a.savedAtMs);
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

  Future<void> addFavoriteFolder(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('favorite_folder_name_required');
    }

    final store = await _loadStore();
    store.folders.add(
      _LocalFavoriteFolderRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: normalizedName,
      ),
    );
    await _saveStore(store);
    notifyListeners();
  }

  Future<void> renameFavoriteFolder({
    required String folderId,
    required String name,
  }) async {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      throw Exception('favorite_folder_id_required');
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw Exception('favorite_folder_name_required');
    }

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
  }

  Future<void> deleteFavoriteFolder(String folderId) async {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return;
    }

    final store = await _loadStore();
    store.folders.removeWhere((folder) => folder.id == normalizedFolderId);
    for (final entry in store.entries) {
      entry.folderIds.remove(normalizedFolderId);
    }
    store.entries.removeWhere((entry) => entry.folderIds.isEmpty);
    await _saveStore(store);
    notifyListeners();
  }

  Future<void> toggleFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  }) async {
    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      throw Exception('favorite_local_folder_required');
    }
    final store = await _loadStore();
    final normalizedComicId = details.id.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('favorite_comic_id_required');
    }

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
              savedAtMs: DateTime.now().millisecondsSinceEpoch,
              folderIds: <String>{},
            );

      record
        ..title = details.title.trim()
        ..subTitle = details.subTitle.trim()
        ..cover = details.cover.trim()
        ..updateTime = details.updateTime.trim()
        ..savedAtMs = DateTime.now().millisecondsSinceEpoch
        ..folderIds.add(normalizedFolderId);

      if (existingIndex < 0) {
        store.entries.add(record);
      }
    } else if (existingIndex >= 0) {
      final record = store.entries[existingIndex];
      record.folderIds.remove(normalizedFolderId);
      if (record.folderIds.isEmpty) {
        store.entries.removeAt(existingIndex);
      }
    }

    await _saveStore(store);
    notifyListeners();
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
    required this.savedAtMs,
    required Set<String> folderIds,
  }) : folderIds = Set<String>.from(folderIds);

  factory _LocalFavoriteComicRecord.fromJson(Map<String, dynamic> json) {
    final folderIds = <String>{};
    final folderIdsRaw = json['folderIds'];
    if (folderIdsRaw is List) {
      for (final item in folderIdsRaw) {
        final id = item?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          folderIds.add(id);
        }
      }
    }
    return _LocalFavoriteComicRecord(
      comicId: (json['comicId'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString(),
      subTitle: (json['subTitle'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      updateTime: (json['updateTime'] ?? '').toString(),
      savedAtMs:
          (json['savedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      folderIds: folderIds,
    );
  }

  final String comicId;
  String title;
  String subTitle;
  String cover;
  String updateTime;
  int savedAtMs;
  final Set<String> folderIds;

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
  };
}
