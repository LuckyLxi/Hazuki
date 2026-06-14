import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'hazuki_database.g.dart';

class ReadHistoryEntries extends Table {
  TextColumn get storageKey => text()();
  TextColumn get comicId => text()();
  TextColumn get sourceKey => text()();
  TextColumn get title => text()();
  TextColumn get cover => text()();
  TextColumn get subTitle => text()();
  IntColumn get timestampMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {storageKey};
}

class ReadingProgressEntries extends Table {
  TextColumn get storageKey => text()();
  TextColumn get comicId => text()();
  TextColumn get sourceKey => text()();
  TextColumn get epId => text()();
  TextColumn get title => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get pageIndex => integer().withDefault(const Constant(0))();
  IntColumn get timestampMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {storageKey};
}

class SearchHistoryEntries extends Table {
  TextColumn get keyword => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {keyword};
}

class LocalFavoriteFolders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sourceKey => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalFavoriteComics extends Table {
  TextColumn get storageKey => text()();
  TextColumn get comicId => text()();
  TextColumn get sourceKey => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get subTitle => text()();
  TextColumn get cover => text()();
  TextColumn get updateTime => text()();

  @override
  Set<Column<Object>> get primaryKey => {storageKey};
}

class LocalFavoriteComicFolders extends Table {
  TextColumn get comicStorageKey => text()();
  TextColumn get folderId => text()();
  IntColumn get savedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {comicStorageKey, folderId};
}

class LocalFavoriteFolderTombstones extends Table {
  TextColumn get folderId => text()();
  IntColumn get deletedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {folderId};
}

class LocalFavoriteEntryTombstones extends Table {
  TextColumn get storageKey => text()();
  TextColumn get comicId => text()();
  TextColumn get sourceKey => text().withDefault(const Constant(''))();
  IntColumn get deletedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {storageKey};
}

class DownloadGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAtMs => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DownloadGroupComics extends Table {
  TextColumn get groupId => text()();
  TextColumn get comicStorageKey => text()();
  IntColumn get addedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {groupId, comicStorageKey};
}

class DownloadGroupTombstones extends Table {
  TextColumn get groupId => text()();
  IntColumn get deletedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

class DownloadGroupComicTombstones extends Table {
  TextColumn get groupId => text()();
  TextColumn get comicStorageKey => text()();
  IntColumn get deletedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {groupId, comicStorageKey};
}

@DriftDatabase(
  tables: [
    ReadHistoryEntries,
    ReadingProgressEntries,
    SearchHistoryEntries,
    LocalFavoriteFolders,
    LocalFavoriteComics,
    LocalFavoriteComicFolders,
    LocalFavoriteFolderTombstones,
    LocalFavoriteEntryTombstones,
    DownloadGroups,
    DownloadGroupComics,
    DownloadGroupTombstones,
    DownloadGroupComicTombstones,
  ],
)
class HazukiDatabase extends _$HazukiDatabase {
  HazukiDatabase() : super(_openConnection());

  HazukiDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(searchHistoryEntries);
      }
      if (from < 3) {
        await m.createTable(readingProgressEntries);
      }
      if (from < 4) {
        await m.createTable(downloadGroups);
        await m.createTable(downloadGroupComics);
        await m.createTable(downloadGroupTombstones);
        await m.createTable(downloadGroupComicTombstones);
      }
      if (from < 5) {
        await m.addColumn(downloadGroups, downloadGroups.sortOrder);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      return NativeDatabase(File(p.join(dir.path, 'hazuki.sqlite')));
    } catch (_) {
      return NativeDatabase.memory();
    }
  });
}
