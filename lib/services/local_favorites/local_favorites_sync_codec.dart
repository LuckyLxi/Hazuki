import 'dart:convert';

import '../../models/source_scoped_comic_id.dart';
import 'local_favorites_models.dart';
import 'local_favorites_persistence.dart';

class LocalFavoritesSyncCodec {
  const LocalFavoritesSyncCodec(this._persistence);

  final LocalFavoritesPersistence _persistence;

  Future<String> exportFoldersJsonString() async {
    final snapshot = await _persistence.load();
    return jsonEncode(
      snapshot.folders.map((folder) => folder.toJson()).toList(),
    );
  }

  Future<String> exportEntriesJsonString() async {
    final snapshot = await _persistence.load();
    return jsonEncode(snapshot.entries.map((entry) => entry.toJson()).toList());
  }

  Future<String> exportFolderTombstonesJsonString() async {
    await _persistence.pruneTombstones();
    final tombstones = await _persistence.loadFolderTombstones();
    return jsonEncode([
      for (final item in tombstones)
        {'id': item.folderId, 'deletedAtMs': item.deletedAtMs},
    ]);
  }

  Future<String> exportEntryTombstonesJsonString() async {
    await _persistence.pruneTombstones();
    final tombstones = await _persistence.loadEntryTombstones();
    return jsonEncode([
      for (final item in tombstones)
        {
          'comicId': item.comicId,
          if (item.sourceKey.isNotEmpty) 'sourceKey': item.sourceKey,
          'deletedAtMs': item.deletedAtMs,
        },
    ]);
  }

  Future<String> exportComicFolderTombstonesJsonString() async {
    await _persistence.pruneTombstones();
    final tombstones = await _persistence.loadComicFolderTombstones();
    return jsonEncode([
      for (final item in tombstones)
        {
          'comicId': item.comicId,
          if (item.sourceKey.isNotEmpty) 'sourceKey': item.sourceKey,
          'folderId': item.folderId,
          'deletedAtMs': item.deletedAtMs,
        },
    ]);
  }

  Future<void> importJsonStrings({
    String? foldersRaw,
    String? entriesRaw,
    String? folderTombstonesRaw,
    String? entryTombstonesRaw,
    String? comicFolderTombstonesRaw,
    required bool replace,
  }) async {
    final folders = decodeFolders(foldersRaw);
    final entries = decodeEntries(entriesRaw);
    if (replace) {
      await _persistence.replace(
        LocalFavoritesSnapshot(folders: folders, entries: entries),
      );
    } else {
      final snapshot = await _persistence.load();
      final folderById = <String, LocalFavoriteFolderRecord>{
        for (final folder in snapshot.folders) folder.id: folder,
      };
      for (final folder in folders) {
        folderById.putIfAbsent(folder.id, () => folder);
      }
      final entryByKey = <String, LocalFavoriteComicRecord>{
        for (final entry in snapshot.entries)
          SourceScopedComicId(
            sourceKey: entry.sourceKey,
            comicId: entry.comicId,
          ).storageKey: entry,
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
      await _persistence.replace(
        LocalFavoritesSnapshot(
          folders: folderById.values.toList(growable: true),
          entries: entryByKey.values.toList(growable: true),
        ),
      );
    }

    await _persistence.upsertFolderTombstones(
      _decodeTombstones(folderTombstonesRaw)
          .map(
            (item) => LocalFavoriteFolderTombstone(
              (item['id'] ?? '').toString().trim(),
              (item['deletedAtMs'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((item) => item.folderId.isNotEmpty && item.deletedAtMs > 0),
    );
    await _persistence.upsertEntryTombstones(
      _decodeTombstones(entryTombstonesRaw)
          .map(
            (item) => LocalFavoriteEntryTombstone(
              comicId: (item['comicId'] ?? '').toString().trim(),
              sourceKey: (item['sourceKey'] ?? '').toString().trim(),
              deletedAtMs: (item['deletedAtMs'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((item) => item.comicId.isNotEmpty && item.deletedAtMs > 0),
    );
    await _persistence.upsertComicFolderTombstones(
      _decodeTombstones(comicFolderTombstonesRaw)
          .map(
            (item) => LocalFavoriteComicFolderTombstone(
              comicId: (item['comicId'] ?? '').toString().trim(),
              sourceKey: (item['sourceKey'] ?? '').toString().trim(),
              folderId: (item['folderId'] ?? '').toString().trim(),
              deletedAtMs: (item['deletedAtMs'] as num?)?.toInt() ?? 0,
            ),
          )
          .where(
            (item) =>
                item.comicId.isNotEmpty &&
                item.folderId.isNotEmpty &&
                item.deletedAtMs > 0,
          ),
    );
    await _persistence.pruneTombstones();
  }

  List<LocalFavoriteFolderRecord> decodeFolders(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <LocalFavoriteFolderRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <LocalFavoriteFolderRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => LocalFavoriteFolderRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((folder) => folder.id.isNotEmpty)
          .toList(growable: true);
    } catch (_) {
      return <LocalFavoriteFolderRecord>[];
    }
  }

  List<LocalFavoriteComicRecord> decodeEntries(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <LocalFavoriteComicRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <LocalFavoriteComicRecord>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => LocalFavoriteComicRecord.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (entry) => entry.comicId.isNotEmpty && entry.folderIds.isNotEmpty,
          )
          .toList(growable: true);
    } catch (_) {
      return <LocalFavoriteComicRecord>[];
    }
  }

  List<Map<String, dynamic>> _decodeTombstones(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
