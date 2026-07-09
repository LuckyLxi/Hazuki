import 'package:shared_preferences/shared_preferences.dart';

import 'local_favorites_sync_codec.dart';

class LocalFavoritesMigration {
  LocalFavoritesMigration({
    required LocalFavoritesSyncCodec syncCodec,
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _syncCodec = syncCodec,
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const String _foldersKey = 'local_favorite_folders_v1';
  static const String _entriesKey = 'local_favorite_entries_v1';
  static const String _folderTombstonesKey =
      'local_favorite_folder_tombstones_v1';
  static const String _entryTombstonesKey =
      'local_favorite_entry_tombstones_v1';
  static const String _comicFolderTombstonesKey =
      'local_favorite_comic_folder_tombstones_v1';
  static const String _migrationDoneKey = 'local_favorite_drift_migrated_v1';

  final LocalFavoritesSyncCodec _syncCodec;
  final Future<SharedPreferences> Function() _loadPreferences;
  Future<void> _migration = Future.value();

  Future<void> ensureMigrated() {
    _migration = _migration.then((_) async {
      final preferences = await _loadPreferences();
      if (preferences.getBool(_migrationDoneKey) == true) return;
      await _syncCodec.importJsonStrings(
        foldersRaw: preferences.getString(_foldersKey),
        entriesRaw: preferences.getString(_entriesKey),
        folderTombstonesRaw: preferences.getString(_folderTombstonesKey),
        entryTombstonesRaw: preferences.getString(_entryTombstonesKey),
        comicFolderTombstonesRaw: preferences.getString(
          _comicFolderTombstonesKey,
        ),
        replace: true,
      );
      await preferences.setBool(_migrationDoneKey, true);
    });
    return _migration;
  }
}
