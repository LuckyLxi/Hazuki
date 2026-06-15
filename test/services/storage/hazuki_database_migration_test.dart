import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('upgrading from v3 creates download groups with sort order', () async {
    final sqliteDatabase = sqlite3.openInMemory()
      ..execute('''
        CREATE TABLE search_history_entries (
          keyword TEXT NOT NULL PRIMARY KEY,
          position INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE local_favorite_folders (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          source_key TEXT NOT NULL DEFAULT ''
        );
      ''')
      ..execute('PRAGMA user_version = 3');
    final database = HazukiDatabase.forTesting(
      NativeDatabase.opened(sqliteDatabase),
    );

    addTearDown(database.close);

    await database
        .into(database.downloadGroups)
        .insert(
          DownloadGroupsCompanion.insert(
            id: 'group',
            name: 'Group',
            createdAtMs: 1,
          ),
        );

    final group = await database.select(database.downloadGroups).getSingle();
    expect(group.sortOrder, 0);
  });

  test('upgrading from v4 adds sort order to download groups', () async {
    final sqliteDatabase = sqlite3.openInMemory()
      ..execute('''
        CREATE TABLE search_history_entries (
          keyword TEXT NOT NULL PRIMARY KEY,
          position INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE local_favorite_folders (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          source_key TEXT NOT NULL DEFAULT ''
        );
      ''')
      ..execute('''
        CREATE TABLE download_groups (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL
        );
      ''')
      ..execute('''
        INSERT INTO download_groups (id, name, created_at_ms)
        VALUES ('group', 'Group', 1);
      ''')
      ..execute('PRAGMA user_version = 4');
    final database = HazukiDatabase.forTesting(
      NativeDatabase.opened(sqliteDatabase),
    );

    addTearDown(database.close);

    final group = await database.select(database.downloadGroups).getSingle();
    expect(group.sortOrder, 0);
  });

  test('upgrading from v5 creates favorite comic-folder tombstones', () async {
    final sqliteDatabase = sqlite3.openInMemory()
      ..execute('''
        CREATE TABLE search_history_entries (
          keyword TEXT NOT NULL PRIMARY KEY,
          position INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE local_favorite_folders (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          source_key TEXT NOT NULL DEFAULT ''
        );
      ''')
      ..execute('PRAGMA user_version = 5');
    final database = HazukiDatabase.forTesting(
      NativeDatabase.opened(sqliteDatabase),
    );

    addTearDown(database.close);

    await database
        .into(database.localFavoriteComicFolderTombstones)
        .insert(
          LocalFavoriteComicFolderTombstonesCompanion.insert(
            comicStorageKey: 'jm:comic',
            folderId: 'folder',
            deletedAtMs: 1,
          ),
        );

    final tombstone = await database
        .select(database.localFavoriteComicFolderTombstones)
        .getSingle();
    expect(tombstone.folderId, 'folder');

    await database
        .into(database.localFavoriteFolders)
        .insert(
          LocalFavoriteFoldersCompanion.insert(id: 'folder', name: 'Folder'),
        );
    final folder = await database
        .select(database.localFavoriteFolders)
        .getSingle();
    expect(folder.updatedAtMs, 0);

    await database
        .into(database.searchHistoryEntries)
        .insert(
          SearchHistoryEntriesCompanion.insert(keyword: 'keyword', position: 0),
        );
    final history = await database
        .select(database.searchHistoryEntries)
        .getSingle();
    expect(history.updatedAtMs, 0);

    await database
        .into(database.searchHistoryTombstones)
        .insert(
          SearchHistoryTombstonesCompanion.insert(
            keyword: 'deleted',
            deletedAtMs: 1,
          ),
        );
    await database
        .into(database.searchHistoryClearStates)
        .insert(
          SearchHistoryClearStatesCompanion.insert(
            id: 'global',
            clearedAtMs: 2,
          ),
        );
    expect(
      await database.select(database.searchHistoryTombstones).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.searchHistoryClearStates).get(),
      hasLength(1),
    );
  });
}
