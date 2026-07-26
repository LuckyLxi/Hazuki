import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/source_scoped_comic_id.dart';
import '../storage/hazuki_database.dart'
    hide
        LocalFavoriteComicFolderTombstone,
        LocalFavoriteEntryTombstone,
        LocalFavoriteFolderTombstone;
import 'local_favorites_models.dart';

abstract interface class LocalFavoritesPersistence {
  Future<LocalFavoritesSnapshot> load();
  Future<void> replace(LocalFavoritesSnapshot snapshot);

  Future<void> appendFolderTombstone(String folderId);
  Future<void> appendEntryTombstone(String comicId, {String sourceKey = ''});
  Future<void> appendComicFolderTombstone(
    String comicId,
    String folderId, {
    String sourceKey = '',
    int afterMs = 0,
  });
  Future<int> nextComicFolderSavedAtMs(String storageKey, String folderId);

  Future<List<LocalFavoriteFolderTombstone>> loadFolderTombstones();
  Future<List<LocalFavoriteEntryTombstone>> loadEntryTombstones();
  Future<List<LocalFavoriteComicFolderTombstone>> loadComicFolderTombstones();
  Future<void> upsertFolderTombstones(
    Iterable<LocalFavoriteFolderTombstone> tombstones,
  );
  Future<void> upsertEntryTombstones(
    Iterable<LocalFavoriteEntryTombstone> tombstones,
  );
  Future<void> upsertComicFolderTombstones(
    Iterable<LocalFavoriteComicFolderTombstone> tombstones,
  );
  Future<void> pruneTombstones();
}

class DriftLocalFavoritesPersistence implements LocalFavoritesPersistence {
  DriftLocalFavoritesPersistence(this._database);

  static const int _tombstoneTtlMs = 90 * 24 * 60 * 60 * 1000;

  final HazukiDatabase _database;

  @override
  Future<LocalFavoritesSnapshot> load() async {
    final folders = await _database
        .select(_database.localFavoriteFolders)
        .get();
    final comics = await _database.select(_database.localFavoriteComics).get();
    final joins = await _database
        .select(_database.localFavoriteComicFolders)
        .get();
    final folderSavedAtByComic = <String, Map<String, int>>{};
    for (final item in joins) {
      (folderSavedAtByComic[item.comicStorageKey] ??=
              <String, int>{})[item.folderId] =
          item.savedAtMs;
    }
    return LocalFavoritesSnapshot(
      folders: folders
          .map(
            (folder) => LocalFavoriteFolderRecord(
              id: folder.id,
              name: folder.name,
              sourceKey: folder.sourceKey,
              updatedAtMs: folder.updatedAtMs,
            ),
          )
          .toList(growable: true),
      entries: comics
          .map(
            (comic) => LocalFavoriteComicRecord(
              comicId: comic.comicId,
              sourceKey: comic.sourceKey,
              title: comic.title,
              subTitle: comic.subTitle,
              cover: comic.cover,
              updateTime: comic.updateTime,
              tags: _tagsFromJson(comic.tagsJson),
              folderSavedAtMs:
                  folderSavedAtByComic[comic.storageKey] ?? <String, int>{},
            ),
          )
          .where(
            (entry) => entry.comicId.isNotEmpty && entry.folderIds.isNotEmpty,
          )
          .toList(growable: true),
    );
  }

  @override
  Future<void> replace(LocalFavoritesSnapshot snapshot) async {
    await _database.transaction(() async {
      await _database.delete(_database.localFavoriteComicFolders).go();
      await _database.delete(_database.localFavoriteComics).go();
      await _database.delete(_database.localFavoriteFolders).go();
      final folderRows = <LocalFavoriteFoldersCompanion>[
        for (final folder in snapshot.folders)
          LocalFavoriteFoldersCompanion.insert(
            id: folder.id,
            name: folder.name,
            sourceKey: Value(folder.sourceKey),
            updatedAtMs: Value(folder.updatedAtMs),
          ),
      ];
      final comicRows = <LocalFavoriteComicsCompanion>[];
      final comicFolderRows = <LocalFavoriteComicFoldersCompanion>[];
      for (final entry in snapshot.entries) {
        if (entry.comicId.isEmpty || entry.folderSavedAtMs.isEmpty) continue;
        final storageKey = SourceScopedComicId(
          sourceKey: entry.sourceKey,
          comicId: entry.comicId,
        ).storageKey;
        comicRows.add(
          LocalFavoriteComicsCompanion.insert(
            storageKey: storageKey,
            comicId: entry.comicId,
            sourceKey: Value(entry.sourceKey),
            title: entry.title,
            subTitle: entry.subTitle,
            cover: entry.cover,
            updateTime: entry.updateTime,
            tagsJson: Value(jsonEncode(entry.tags)),
          ),
        );
        for (final saved in entry.folderSavedAtMs.entries) {
          comicFolderRows.add(
            LocalFavoriteComicFoldersCompanion.insert(
              comicStorageKey: storageKey,
              folderId: saved.key,
              savedAtMs: saved.value,
            ),
          );
        }
      }
      await _database.batch((batch) {
        if (folderRows.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            _database.localFavoriteFolders,
            folderRows,
          );
        }
        if (comicRows.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            _database.localFavoriteComics,
            comicRows,
          );
        }
        if (comicFolderRows.isNotEmpty) {
          batch.insertAllOnConflictUpdate(
            _database.localFavoriteComicFolders,
            comicFolderRows,
          );
        }
      });
    });
  }

  @override
  Future<void> appendFolderTombstone(String folderId) async {
    await upsertFolderTombstones([
      LocalFavoriteFolderTombstone(
        folderId,
        DateTime.now().millisecondsSinceEpoch,
      ),
    ]);
    await pruneTombstones();
  }

  @override
  Future<void> appendEntryTombstone(
    String comicId, {
    String sourceKey = '',
  }) async {
    await upsertEntryTombstones([
      LocalFavoriteEntryTombstone(
        comicId: comicId,
        sourceKey: sourceKey.trim(),
        deletedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);
    await pruneTombstones();
  }

  @override
  Future<void> appendComicFolderTombstone(
    String comicId,
    String folderId, {
    String sourceKey = '',
    int afterMs = 0,
  }) async {
    await upsertComicFolderTombstones([
      LocalFavoriteComicFolderTombstone(
        comicId: comicId,
        sourceKey: sourceKey.trim(),
        folderId: folderId,
        deletedAtMs: _timestampAfter(afterMs),
      ),
    ]);
    await pruneTombstones();
  }

  @override
  Future<int> nextComicFolderSavedAtMs(
    String storageKey,
    String folderId,
  ) async {
    final comicFolderTombstone =
        await (_database.select(_database.localFavoriteComicFolderTombstones)
              ..where(
                (row) =>
                    row.comicStorageKey.equals(storageKey) &
                    row.folderId.equals(folderId),
              ))
            .getSingleOrNull();
    final entryTombstone = await (_database.select(
      _database.localFavoriteEntryTombstones,
    )..where((row) => row.storageKey.equals(storageKey))).getSingleOrNull();
    return _timestampAfter(
      [
        comicFolderTombstone?.deletedAtMs ?? 0,
        entryTombstone?.deletedAtMs ?? 0,
      ].reduce((a, b) => a > b ? a : b),
    );
  }

  int _timestampAfter(int value) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > value ? now : value + 1;
  }

  @override
  Future<List<LocalFavoriteFolderTombstone>> loadFolderTombstones() async {
    final rows = await _database
        .select(_database.localFavoriteFolderTombstones)
        .get();
    return [
      for (final row in rows)
        LocalFavoriteFolderTombstone(row.folderId, row.deletedAtMs),
    ];
  }

  @override
  Future<List<LocalFavoriteEntryTombstone>> loadEntryTombstones() async {
    final rows = await _database
        .select(_database.localFavoriteEntryTombstones)
        .get();
    return [
      for (final row in rows)
        LocalFavoriteEntryTombstone(
          comicId: row.comicId,
          sourceKey: row.sourceKey,
          deletedAtMs: row.deletedAtMs,
        ),
    ];
  }

  @override
  Future<List<LocalFavoriteComicFolderTombstone>>
  loadComicFolderTombstones() async {
    final rows = await _database
        .select(_database.localFavoriteComicFolderTombstones)
        .get();
    return [
      for (final row in rows)
        () {
          final scoped = SourceScopedComicId.fromStorageKey(
            row.comicStorageKey,
          );
          return LocalFavoriteComicFolderTombstone(
            comicId: scoped.comicId,
            sourceKey: scoped.sourceKey,
            folderId: row.folderId,
            deletedAtMs: row.deletedAtMs,
          );
        }(),
    ];
  }

  @override
  Future<void> upsertFolderTombstones(
    Iterable<LocalFavoriteFolderTombstone> tombstones,
  ) async {
    for (final item in tombstones) {
      await _database
          .into(_database.localFavoriteFolderTombstones)
          .insertOnConflictUpdate(
            LocalFavoriteFolderTombstonesCompanion.insert(
              folderId: item.folderId,
              deletedAtMs: item.deletedAtMs,
            ),
          );
    }
  }

  @override
  Future<void> upsertEntryTombstones(
    Iterable<LocalFavoriteEntryTombstone> tombstones,
  ) async {
    for (final item in tombstones) {
      final storageKey = SourceScopedComicId(
        sourceKey: item.sourceKey,
        comicId: item.comicId,
      ).storageKey;
      await _database
          .into(_database.localFavoriteEntryTombstones)
          .insertOnConflictUpdate(
            LocalFavoriteEntryTombstonesCompanion.insert(
              storageKey: storageKey,
              comicId: item.comicId,
              sourceKey: Value(item.sourceKey),
              deletedAtMs: item.deletedAtMs,
            ),
          );
    }
  }

  @override
  Future<void> upsertComicFolderTombstones(
    Iterable<LocalFavoriteComicFolderTombstone> tombstones,
  ) async {
    for (final item in tombstones) {
      final storageKey = SourceScopedComicId(
        sourceKey: item.sourceKey,
        comicId: item.comicId,
      ).storageKey;
      await _database
          .into(_database.localFavoriteComicFolderTombstones)
          .insertOnConflictUpdate(
            LocalFavoriteComicFolderTombstonesCompanion.insert(
              comicStorageKey: storageKey,
              folderId: item.folderId,
              deletedAtMs: item.deletedAtMs,
            ),
          );
    }
  }

  @override
  Future<void> pruneTombstones() async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _tombstoneTtlMs;
    await (_database.delete(
      _database.localFavoriteFolderTombstones,
    )..where((row) => row.deletedAtMs.isSmallerThanValue(cutoff))).go();
    await (_database.delete(
      _database.localFavoriteEntryTombstones,
    )..where((row) => row.deletedAtMs.isSmallerThanValue(cutoff))).go();
    await (_database.delete(
      _database.localFavoriteComicFolderTombstones,
    )..where((row) => row.deletedAtMs.isSmallerThanValue(cutoff))).go();
  }
}

List<String> _tagsFromJson(String raw) {
  try {
    final value = jsonDecode(raw);
    if (value is! List) return const [];
    return value
        .map((tag) => tag.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}
