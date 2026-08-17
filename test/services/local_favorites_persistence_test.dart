import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/local_favorites/local_favorites_migration.dart';
import 'package:hazuki/services/local_favorites/local_favorites_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_persistence.dart';
import 'package:hazuki/services/local_favorites/local_favorites_sync_codec.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Drift persistence round-trips source-scoped favorites', () async {
    final database = HazukiDatabase.memory();
    addTearDown(database.close);
    final persistence = DriftLocalFavoritesPersistence(database);

    await persistence.replace(
      LocalFavoritesSnapshot(
        folders: [
          LocalFavoriteFolderRecord(
            id: 'folder-1',
            name: 'Reading',
            sourceKey: 'copy_manga',
            updatedAtMs: 100,
          ),
        ],
        entries: [
          LocalFavoriteComicRecord(
            comicId: 'comic-1',
            sourceKey: 'copy_manga',
            title: 'Title',
            subTitle: 'Subtitle',
            cover: 'cover',
            updateTime: '2026-01-01',
            tags: ['Action'],
            folderSavedAtMs: {'folder-1': 200},
          ),
        ],
      ),
    );

    final restored = await persistence.load();
    expect(restored.folders.single.name, 'Reading');
    expect(restored.entries.single.sourceKey, 'copy_manga');
    expect(restored.entries.single.tags, ['Action']);
    expect(restored.entries.single.folderSavedAtMs, {'folder-1': 200});
  });

  test('sync codec round-trips snapshots and all tombstone types', () async {
    final sourceDatabase = HazukiDatabase.memory();
    final sourcePersistence = DriftLocalFavoritesPersistence(sourceDatabase);
    final sourceCodec = LocalFavoritesSyncCodec(sourcePersistence);

    await sourcePersistence.replace(
      LocalFavoritesSnapshot(
        folders: [
          LocalFavoriteFolderRecord(
            id: 'folder-1',
            name: 'Saved',
            sourceKey: 'jm',
            updatedAtMs: 10,
          ),
        ],
        entries: [
          LocalFavoriteComicRecord(
            comicId: 'comic-1',
            sourceKey: 'jm',
            title: 'Title',
            subTitle: '',
            cover: '',
            updateTime: '',
            folderSavedAtMs: {'folder-1': 20},
          ),
        ],
      ),
    );
    await sourcePersistence.appendFolderTombstone('deleted-folder');
    await sourcePersistence.appendEntryTombstone(
      'deleted-comic',
      sourceKey: 'copy_manga',
    );
    await sourcePersistence.appendComicFolderTombstone(
      'comic-1',
      'removed-folder',
      sourceKey: 'jm',
    );

    final foldersRaw = await sourceCodec.exportFoldersJsonString();
    final entriesRaw = await sourceCodec.exportEntriesJsonString();
    final folderTombstonesRaw = await sourceCodec
        .exportFolderTombstonesJsonString();
    final entryTombstonesRaw = await sourceCodec
        .exportEntryTombstonesJsonString();
    final comicFolderTombstonesRaw = await sourceCodec
        .exportComicFolderTombstonesJsonString();
    await sourceDatabase.close();

    final targetDatabase = HazukiDatabase.memory();
    addTearDown(targetDatabase.close);
    final targetPersistence = DriftLocalFavoritesPersistence(targetDatabase);
    final targetCodec = LocalFavoritesSyncCodec(targetPersistence);
    await targetCodec.importJsonStrings(
      foldersRaw: foldersRaw,
      entriesRaw: entriesRaw,
      folderTombstonesRaw: folderTombstonesRaw,
      entryTombstonesRaw: entryTombstonesRaw,
      comicFolderTombstonesRaw: comicFolderTombstonesRaw,
      replace: true,
    );

    final restored = await targetPersistence.load();
    expect(restored.folders.single.id, 'folder-1');
    expect(restored.entries.single.comicId, 'comic-1');
    expect(
      (await targetPersistence.loadFolderTombstones()).single.folderId,
      'deleted-folder',
    );
    final entryTombstone =
        (await targetPersistence.loadEntryTombstones()).single;
    expect(entryTombstone.comicId, 'deleted-comic');
    expect(entryTombstone.sourceKey, 'copy_manga');
    expect(
      (await targetPersistence.loadComicFolderTombstones()).single.folderId,
      'removed-folder',
    );
  });

  test('migration imports legacy preferences only once', () async {
    SharedPreferences.setMockInitialValues({
      'local_favorite_folders_v1': jsonEncode([
        {'id': 'legacy-folder', 'name': 'Legacy', 'updatedAtMs': 1},
      ]),
      'local_favorite_entries_v1': jsonEncode([
        {
          'comicId': 'legacy-comic',
          'title': 'Legacy comic',
          'folderIds': ['legacy-folder'],
          'savedAtMs': 2,
        },
      ]),
    });
    final database = HazukiDatabase.memory();
    addTearDown(database.close);
    final persistence = DriftLocalFavoritesPersistence(database);
    final codec = LocalFavoritesSyncCodec(persistence);
    final migration = LocalFavoritesMigration(syncCodec: codec);

    await migration.ensureMigrated();
    final first = await persistence.load();
    expect(first.folders.single.id, 'legacy-folder');
    expect(first.entries.single.comicId, 'legacy-comic');

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('local_favorite_folders_v1', '[]');
    await migration.ensureMigrated();
    final second = await persistence.load();
    expect(second.folders.single.id, 'legacy-folder');
  });
}
