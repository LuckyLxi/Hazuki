import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('upgrading from v3 creates download groups with sort order', () async {
    final sqliteDatabase = sqlite3.openInMemory()
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
}
