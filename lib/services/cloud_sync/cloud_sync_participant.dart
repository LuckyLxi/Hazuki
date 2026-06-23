import '../search_history_service.dart';
import '../local_favorites_service.dart';
import '../download_groups_service.dart';

/// A data owner that can export, merge, and restore its own sync format.
abstract interface class CloudSyncParticipant<T> {
  Future<T> exportSnapshot();
  Future<void> mergeSnapshot(T snapshot);
  Future<void> restoreSnapshot(T snapshot);
}

/// Keeps the search-history JSONL format and merge rules inside its owner.
class SearchHistorySyncParticipant implements CloudSyncParticipant<String> {
  const SearchHistorySyncParticipant(this._service);

  final SearchHistoryService _service;

  @override
  Future<String> exportSnapshot() => _service.exportSyncJsonl();

  Future<List<String>> exportLegacyKeywords() => _service.load();

  @override
  Future<void> mergeSnapshot(String snapshot) =>
      _service.mergeSyncJsonl(snapshot);

  @override
  Future<void> restoreSnapshot(String snapshot) =>
      _service.restoreSyncJsonl(snapshot);
}

class LocalFavoritesSyncParticipant {
  const LocalFavoritesSyncParticipant(this._service);

  final LocalFavoritesService _service;

  Future<String> exportFoldersJsonString() =>
      _service.exportFoldersJsonString();
  Future<String> exportEntriesJsonString() =>
      _service.exportEntriesJsonString();
  Future<String> exportFolderTombstonesJsonString() =>
      _service.exportFolderTombstonesJsonString();
  Future<String> exportEntryTombstonesJsonString() =>
      _service.exportEntryTombstonesJsonString();
  Future<String> exportComicFolderTombstonesJsonString() =>
      _service.exportComicFolderTombstonesJsonString();

  Future<void> importJsonStrings({
    String? foldersRaw,
    String? entriesRaw,
    String? folderTombstonesRaw,
    String? entryTombstonesRaw,
    String? comicFolderTombstonesRaw,
    required bool replace,
  }) => _service.importJsonStrings(
    foldersRaw: foldersRaw,
    entriesRaw: entriesRaw,
    folderTombstonesRaw: folderTombstonesRaw,
    entryTombstonesRaw: entryTombstonesRaw,
    comicFolderTombstonesRaw: comicFolderTombstonesRaw,
    replace: replace,
  );
}

class DownloadGroupsSyncParticipant implements CloudSyncParticipant<String?> {
  const DownloadGroupsSyncParticipant(this._service);

  final DownloadGroupsService _service;

  Future<String> exportJsonString() => _service.exportJsonString();
  Future<void> importJsonString(String? snapshot) =>
      _service.importJsonString(snapshot);

  @override
  Future<String> exportSnapshot() => exportJsonString();

  @override
  Future<void> mergeSnapshot(String? snapshot) => importJsonString(snapshot);

  @override
  Future<void> restoreSnapshot(String? snapshot) => importJsonString(snapshot);
}
