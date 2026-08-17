import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('upgrading from v3 creates download groups with sort order', () async {
    final sqliteDatabase = sqlite3.openInMemory();
    _createVersion3Schema(sqliteDatabase);
    sqliteDatabase.execute('PRAGMA user_version = 3');
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
    final sqliteDatabase = sqlite3.openInMemory();
    _createVersion3Schema(sqliteDatabase);
    _createVersion4DownloadTables(sqliteDatabase);
    sqliteDatabase
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
    final sqliteDatabase = sqlite3.openInMemory();
    _createVersion3Schema(sqliteDatabase);
    _createVersion4DownloadTables(sqliteDatabase, includeSortOrder: true);
    sqliteDatabase.execute('PRAGMA user_version = 5');
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

void _createVersion3Schema(Database database) {
  database
    ..execute('''
      CREATE TABLE read_history_entries (
        storage_key TEXT NOT NULL PRIMARY KEY,
        comic_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        title TEXT NOT NULL,
        cover TEXT NOT NULL,
        sub_title TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL
      );
    ''')
    ..execute('''
      CREATE TABLE reading_progress_entries (
        storage_key TEXT NOT NULL PRIMARY KEY,
        comic_id TEXT NOT NULL,
        source_key TEXT NOT NULL,
        ep_id TEXT NOT NULL,
        title TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        page_index INTEGER NOT NULL DEFAULT 0,
        timestamp_ms INTEGER NOT NULL
      );
    ''')
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
      CREATE TABLE local_favorite_comics (
        storage_key TEXT NOT NULL PRIMARY KEY,
        comic_id TEXT NOT NULL,
        source_key TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL,
        sub_title TEXT NOT NULL,
        cover TEXT NOT NULL,
        update_time TEXT NOT NULL
      );
    ''')
    ..execute('''
      CREATE TABLE local_favorite_comic_folders (
        comic_storage_key TEXT NOT NULL,
        folder_id TEXT NOT NULL,
        saved_at_ms INTEGER NOT NULL,
        PRIMARY KEY (comic_storage_key, folder_id)
      );
    ''')
    ..execute('''
      CREATE TABLE local_favorite_folder_tombstones (
        folder_id TEXT NOT NULL PRIMARY KEY,
        deleted_at_ms INTEGER NOT NULL
      );
    ''')
    ..execute('''
      CREATE TABLE local_favorite_entry_tombstones (
        storage_key TEXT NOT NULL PRIMARY KEY,
        comic_id TEXT NOT NULL,
        source_key TEXT NOT NULL DEFAULT '',
        deleted_at_ms INTEGER NOT NULL
      );
    ''');
}

void _createVersion4DownloadTables(
  Database database, {
  bool includeSortOrder = false,
}) {
  final sortOrderColumn = includeSortOrder
      ? ', sort_order INTEGER NOT NULL DEFAULT 0'
      : '';
  database
    ..execute('''
      CREATE TABLE download_groups (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
        $sortOrderColumn
      );
    ''')
    ..execute('''
      CREATE TABLE download_group_comics (
        group_id TEXT NOT NULL,
        comic_storage_key TEXT NOT NULL,
        added_at_ms INTEGER NOT NULL,
        PRIMARY KEY (group_id, comic_storage_key)
      );
    ''')
    ..execute('''
      CREATE TABLE download_group_tombstones (
        group_id TEXT NOT NULL PRIMARY KEY,
        deleted_at_ms INTEGER NOT NULL
      );
    ''')
    ..execute('''
      CREATE TABLE download_group_comic_tombstones (
        group_id TEXT NOT NULL,
        comic_storage_key TEXT NOT NULL,
        deleted_at_ms INTEGER NOT NULL,
        PRIMARY KEY (group_id, comic_storage_key)
      );
    ''');
}
