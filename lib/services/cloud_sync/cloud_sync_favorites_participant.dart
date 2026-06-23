import 'dart:convert';

import '../../models/hazuki_models.dart';
import '../local_favorites_service.dart';
import 'cloud_sync_config_store.dart';

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

  Future<void> mergeRemote(
    Map<dynamic, dynamic> remoteData, {
    required String localFoldersSnapshot,
    required String localEntriesSnapshot,
  }) async {
    final tombstoneCutoff =
        DateTime.now().millisecondsSinceEpoch - (90 * 24 * 60 * 60 * 1000);
    final folderTombstones = _mergeTombstoneMaps(
      _decodeTombstoneMap(
        await _service.exportFolderTombstonesJsonString(),
        'id',
      ),
      _decodeTombstoneMap(
        _stringValue(remoteData[CloudSyncConfigStore.folderTombstonesKey]),
        'id',
      ),
    );
    final entryTombstones = _mergeTombstoneMaps(
      _decodeEntryTombstoneMap(
        await _service.exportEntryTombstonesJsonString(),
      ),
      _decodeEntryTombstoneMap(
        _stringValue(remoteData[CloudSyncConfigStore.entryTombstonesKey]),
      ),
    );
    final comicFolderTombstones = _mergeTombstoneMaps(
      _decodeComicFolderTombstoneMap(
        await _service.exportComicFolderTombstonesJsonString(),
      ),
      _decodeComicFolderTombstoneMap(
        _stringValue(remoteData[CloudSyncConfigStore.comicFolderTombstonesKey]),
      ),
    );

    final localFolders = _decodeList(localFoldersSnapshot);
    final remoteFolders = _decodeList(
      _stringValue(remoteData[CloudSyncConfigStore.localFavoriteFoldersKey]),
    );
    bool isFolderTombstoned(String id) {
      final deletedAtMs = folderTombstones[id];
      if (deletedAtMs == null) return false;
      return deletedAtMs > ((int.tryParse(id) ?? 0) ~/ 1000);
    }

    final mergedFoldersById = <String, Map<String, dynamic>>{};
    for (final folder in localFolders) {
      final id = (folder['id'] ?? '').toString();
      if (id.isNotEmpty && !isFolderTombstoned(id)) {
        mergedFoldersById[id] = folder;
      }
    }
    for (final folder in remoteFolders) {
      final id = (folder['id'] ?? '').toString();
      if (id.isEmpty || isFolderTombstoned(id)) continue;
      final existing = mergedFoldersById[id];
      final existingUpdatedAtMs =
          (existing?['updatedAtMs'] as num?)?.toInt() ?? 0;
      final remoteUpdatedAtMs = (folder['updatedAtMs'] as num?)?.toInt() ?? 0;
      if (existing == null || remoteUpdatedAtMs > existingUpdatedAtMs) {
        mergedFoldersById[id] = folder;
      }
    }
    final mergedFolderIds = mergedFoldersById.keys.toSet();

    final localEntries = _decodeList(localEntriesSnapshot);
    final remoteEntries = _decodeList(
      _stringValue(remoteData[CloudSyncConfigStore.localFavoriteEntriesKey]),
    );
    bool isEntryTombstoned(String storageKey, int savedAtMs) {
      final deletedAtMs = entryTombstones[storageKey];
      return deletedAtMs != null && deletedAtMs >= savedAtMs;
    }

    final mergedEntries = <String, Map<String, dynamic>>{};
    for (final entry in localEntries) {
      var normalized = _normalizeLocalFavoriteEntry(entry);
      if (normalized == null) continue;
      final storageKey = _favoriteStorageKey(normalized);
      normalized = _withoutTombstonedComicFolders(
        normalized,
        storageKey,
        comicFolderTombstones,
      );
      final savedAtMs = _localFavoriteEntrySavedAtMs(normalized);
      if (savedAtMs > 0 && !isEntryTombstoned(storageKey, savedAtMs)) {
        mergedEntries[storageKey] = normalized;
      }
    }
    for (final entry in remoteEntries) {
      var normalized = _normalizeLocalFavoriteEntry(entry);
      if (normalized == null) continue;
      final storageKey = _favoriteStorageKey(normalized);
      normalized = _withoutTombstonedComicFolders(
        normalized,
        storageKey,
        comicFolderTombstones,
      );
      final savedAtMs = _localFavoriteEntrySavedAtMs(normalized);
      if (savedAtMs <= 0 || isEntryTombstoned(storageKey, savedAtMs)) {
        continue;
      }
      final existing = mergedEntries[storageKey];
      if (existing == null) {
        mergedEntries[storageKey] = normalized;
      } else {
        final winner = savedAtMs > _localFavoriteEntrySavedAtMs(existing)
            ? normalized
            : existing;
        mergedEntries[storageKey] = _withNormalizedLocalFavoriteEntry(
          winner,
          folderSavedAtMs: _mergeFolderSavedAtMs(existing, normalized),
        );
      }
    }

    for (final storageKey in mergedEntries.keys.toList()) {
      final entry = mergedEntries[storageKey]!;
      final folderSavedAtMs = _decodeFolderSavedAtMs(entry)
        ..removeWhere((folderId, _) => !mergedFolderIds.contains(folderId));
      if (folderSavedAtMs.isEmpty) {
        mergedEntries.remove(storageKey);
      } else {
        mergedEntries[storageKey] = _withNormalizedLocalFavoriteEntry(
          entry,
          folderSavedAtMs: folderSavedAtMs,
        );
      }
    }

    await _service.importJsonStrings(
      foldersRaw: jsonEncode(mergedFoldersById.values.toList()),
      entriesRaw: jsonEncode(mergedEntries.values.toList()),
      folderTombstonesRaw: _encodeTombstoneMap(
        folderTombstones,
        'id',
        tombstoneCutoff,
      ),
      entryTombstonesRaw: _encodeEntryTombstoneMap(
        entryTombstones,
        tombstoneCutoff,
      ),
      comicFolderTombstonesRaw: _encodeComicFolderTombstoneMap(
        comicFolderTombstones,
        tombstoneCutoff,
      ),
      replace: true,
    );
  }

  String _favoriteStorageKey(Map<String, dynamic> entry) {
    return SourceScopedComicId(
      sourceKey: (entry['sourceKey'] ?? '').toString(),
      comicId: entry['comicId'] as String,
    ).storageKey;
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, int> _decodeTombstoneMap(String? raw, String idField) {
    final result = <String, int>{};
    for (final item in _decodeList(raw)) {
      final id = (item[idField] ?? '').toString().trim();
      final timestamp = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (id.isNotEmpty && timestamp > 0) result[id] = timestamp;
    }
    return result;
  }

  Map<String, int> _decodeEntryTombstoneMap(String? raw) {
    final result = <String, int>{};
    for (final item in _decodeList(raw)) {
      final comicId = (item['comicId'] ?? '').toString().trim();
      final timestamp = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (comicId.isEmpty || timestamp <= 0) continue;
      final storageKey = SourceScopedComicId(
        sourceKey: (item['sourceKey'] ?? '').toString().trim(),
        comicId: comicId,
      ).storageKey;
      if (timestamp > (result[storageKey] ?? 0)) {
        result[storageKey] = timestamp;
      }
    }
    return result;
  }

  Map<String, int> _decodeComicFolderTombstoneMap(String? raw) {
    final result = <String, int>{};
    for (final item in _decodeList(raw)) {
      final comicId = (item['comicId'] ?? '').toString().trim();
      final folderId = (item['folderId'] ?? '').toString().trim();
      final timestamp = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
      if (comicId.isEmpty || folderId.isEmpty || timestamp <= 0) continue;
      final storageKey = SourceScopedComicId(
        sourceKey: (item['sourceKey'] ?? '').toString().trim(),
        comicId: comicId,
      ).storageKey;
      final key = _comicFolderTombstoneKey(storageKey, folderId);
      if (timestamp > (result[key] ?? 0)) result[key] = timestamp;
    }
    return result;
  }

  Map<String, int> _mergeTombstoneMaps(
    Map<String, int> first,
    Map<String, int> second,
  ) {
    final merged = Map<String, int>.from(first);
    for (final entry in second.entries) {
      if (entry.value > (merged[entry.key] ?? 0)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  String _encodeTombstoneMap(
    Map<String, int> map,
    String idField,
    int cutoff,
  ) => jsonEncode(
    map.entries
        .where((entry) => entry.value >= cutoff)
        .map((entry) => {idField: entry.key, 'deletedAtMs': entry.value})
        .toList(),
  );

  String _encodeEntryTombstoneMap(Map<String, int> map, int cutoff) {
    return jsonEncode(
      map.entries.where((entry) => entry.value >= cutoff).map((entry) {
        final scoped = SourceScopedComicId.fromStorageKey(entry.key);
        return {
          'comicId': scoped.comicId,
          if (scoped.sourceKey.isNotEmpty) 'sourceKey': scoped.sourceKey,
          'deletedAtMs': entry.value,
        };
      }).toList(),
    );
  }

  String _encodeComicFolderTombstoneMap(Map<String, int> map, int cutoff) {
    return jsonEncode(
      map.entries.where((entry) => entry.value >= cutoff).map((entry) {
        final parts = jsonDecode(entry.key) as List<dynamic>;
        final scoped = SourceScopedComicId.fromStorageKey(parts[0] as String);
        return {
          'comicId': scoped.comicId,
          if (scoped.sourceKey.isNotEmpty) 'sourceKey': scoped.sourceKey,
          'folderId': parts[1] as String,
          'deletedAtMs': entry.value,
        };
      }).toList(),
    );
  }

  String _comicFolderTombstoneKey(String storageKey, String folderId) =>
      jsonEncode([storageKey, folderId]);

  Map<String, dynamic> _withoutTombstonedComicFolders(
    Map<String, dynamic> entry,
    String storageKey,
    Map<String, int> tombstones,
  ) {
    final folderSavedAtMs = _decodeFolderSavedAtMs(entry)
      ..removeWhere((folderId, savedAtMs) {
        final deletedAtMs =
            tombstones[_comicFolderTombstoneKey(storageKey, folderId)];
        return deletedAtMs != null && deletedAtMs >= savedAtMs;
      });
    return _withNormalizedLocalFavoriteEntry(
      entry,
      folderSavedAtMs: folderSavedAtMs,
    );
  }

  Map<String, int> _decodeFolderSavedAtMs(Map<String, dynamic> entry) {
    final result = <String, int>{};
    final raw = entry['folderSavedAtMs'];
    if (raw is Map) {
      for (final item in raw.entries) {
        final folderId = item.key.toString().trim();
        final savedAtMs = (item.value as num?)?.toInt();
        if (folderId.isNotEmpty && savedAtMs != null) {
          result[folderId] = savedAtMs;
        }
      }
    }
    if (result.isNotEmpty) return result;
    final fallback = (entry['savedAtMs'] as num?)?.toInt() ?? 0;
    for (final folderId in _toStringSet(entry['folderIds'])) {
      result[folderId] = fallback;
    }
    return result;
  }

  int _localFavoriteEntrySavedAtMs(Map<String, dynamic> entry) {
    var latest = 0;
    for (final timestamp in _decodeFolderSavedAtMs(entry).values) {
      if (timestamp > latest) latest = timestamp;
    }
    return latest > 0 ? latest : (entry['savedAtMs'] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic>? _normalizeLocalFavoriteEntry(
    Map<String, dynamic> entry,
  ) {
    final comicId = (entry['comicId'] ?? '').toString().trim();
    if (comicId.isEmpty) return null;
    return _withNormalizedLocalFavoriteEntry(
      entry,
      comicId: comicId,
      sourceKey: (entry['sourceKey'] ?? '').toString().trim(),
      folderSavedAtMs: _decodeFolderSavedAtMs(entry),
    );
  }

  Map<String, int> _mergeFolderSavedAtMs(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final result = _decodeFolderSavedAtMs(first);
    for (final entry in _decodeFolderSavedAtMs(second).entries) {
      if (entry.value > (result[entry.key] ?? 0)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<String, dynamic> _withNormalizedLocalFavoriteEntry(
    Map<String, dynamic> entry, {
    String? comicId,
    String? sourceKey,
    required Map<String, int> folderSavedAtMs,
  }) {
    var latest = 0;
    for (final timestamp in folderSavedAtMs.values) {
      if (timestamp > latest) latest = timestamp;
    }
    final normalizedSourceKey =
        sourceKey ?? (entry['sourceKey'] ?? '').toString().trim();
    return {
      ...entry,
      'comicId': comicId ?? (entry['comicId'] ?? '').toString().trim(),
      if (normalizedSourceKey.isNotEmpty) 'sourceKey': normalizedSourceKey,
      'savedAtMs': latest,
      'folderIds': folderSavedAtMs.keys.toList(growable: false),
      'folderSavedAtMs': folderSavedAtMs,
    };
  }

  Set<String> _toStringSet(dynamic value) {
    return value is List
        ? value.map((entry) => entry.toString()).toSet()
        : const {};
  }

  String? _stringValue(dynamic value) => value is String ? value : null;
}
