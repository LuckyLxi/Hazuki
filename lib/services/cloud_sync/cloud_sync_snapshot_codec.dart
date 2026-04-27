import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../hazuki_source_service.dart';
import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_remote_client.dart';

class CloudSyncSnapshotCodec {
  CloudSyncSnapshotCodec({
    required CloudSyncConfigStore configStore,
    HazukiSourceService? sourceService,
  }) : _sourceService = sourceService ?? HazukiSourceService.instance;

  final HazukiSourceService _sourceService;

  Future<void> mergeRemoteIntoLocal(CloudSyncRemoteClient client) async {
    // Fetch remote files first, then snapshot local state — this ensures any
    // user actions during the network round-trip are captured in the snapshot
    // and won't be silently overwritten by the merge result.
    final readingText = await client.tryGetBackupFile(
      CloudSyncConfigStore.readingFileName,
    );
    final searchText = await client.tryGetBackupFile(
      CloudSyncConfigStore.searchHistoryFileName,
    );
    final settingsText = await client.tryGetBackupFile(
      CloudSyncConfigStore.settingsFileName,
    );

    final prefs = await SharedPreferences.getInstance();

    final localHistorySnapshot = prefs.getString('hazuki_read_history');
    final localProgressSnapshot = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('reading_progress_')) continue;
      final raw = prefs.getString(key);
      if (raw != null) localProgressSnapshot[key] = raw;
    }
    final localSearchSnapshot = prefs.getStringList('search_history');
    final localFoldersSnapshot = prefs.getString('local_favorite_folders_v1');
    final localEntriesSnapshot = prefs.getString('local_favorite_entries_v1');

    if (readingText != null) {
      Map<String, dynamic>? readingMap;
      try {
        final decoded = jsonDecode(readingText);
        if (decoded is Map) {
          readingMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      if (readingMap != null) {
        final remoteHistoryRaw = readingMap['history'];
        List<Map<String, dynamic>> remoteHistory = const [];
        if (remoteHistoryRaw is List) {
          remoteHistory = remoteHistoryRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        List<Map<String, dynamic>> localHistory = const [];
        if (localHistorySnapshot != null) {
          try {
            final decoded = jsonDecode(localHistorySnapshot);
            if (decoded is List) {
              localHistory = decoded
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          } catch (_) {}
        }

        final mergedHistory = <String, Map<String, dynamic>>{};
        for (final entry in [...localHistory, ...remoteHistory]) {
          final comicId = (entry['id'] ?? '').toString().trim();
          if (comicId.isEmpty) continue;
          final ts = (entry['timestamp'] as num?)?.toInt() ?? 0;
          final existing = mergedHistory[comicId];
          final existingTs = (existing?['timestamp'] as num?)?.toInt() ?? 0;
          if (existing == null || ts > existingTs) {
            mergedHistory[comicId] = entry;
          }
        }
        var historyList = mergedHistory.values.toList()
          ..sort(
            (a, b) => ((b['timestamp'] as num?)?.toInt() ?? 0).compareTo(
              (a['timestamp'] as num?)?.toInt() ?? 0,
            ),
          );
        if (historyList.length > 150) {
          historyList = historyList.sublist(0, 150);
        }
        await prefs.setString('hazuki_read_history', jsonEncode(historyList));

        final remoteProgressRaw = readingMap['progress'];
        final remoteProgress = <String, Map<String, dynamic>>{};
        if (remoteProgressRaw is List) {
          for (final item in remoteProgressRaw) {
            if (item is! Map) continue;
            final entry = Map<String, dynamic>.from(item);
            final comicId = (entry['comicId'] ?? '').toString().trim();
            if (comicId.isEmpty) continue;
            remoteProgress[comicId] = entry;
          }
        }

        final localProgress = <String, Map<String, dynamic>>{};
        for (final entry in localProgressSnapshot.entries) {
          final comicId = entry.key.substring('reading_progress_'.length);
          try {
            final decoded = jsonDecode(entry.value);
            if (decoded is Map) {
              localProgress[comicId] = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }

        final allComicIds = {...localProgress.keys, ...remoteProgress.keys};
        for (final comicId in allComicIds) {
          final local = localProgress[comicId];
          final remote = remoteProgress[comicId];
          final Map<String, dynamic> winner;
          if (local == null) {
            winner = remote!;
          } else if (remote == null) {
            continue;
          } else {
            final localTs = (local['timestamp'] as num?)?.toInt() ?? 0;
            final remoteTs = (remote['timestamp'] as num?)?.toInt() ?? 0;
            if (remoteTs > localTs) {
              winner = remote;
            } else {
              continue;
            }
          }
          await prefs.setString(
            'reading_progress_$comicId',
            jsonEncode({
              'epId': winner['epId'],
              'title': winner['title'],
              'index': winner['index'],
              'timestamp': winner['timestamp'],
            }),
          );
        }
      }
    }

    final remoteKeywords = <String>[];
    if (searchText != null) {
      for (final raw in searchText.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            final keyword = (decoded['keyword'] ?? '').toString().trim();
            if (keyword.isNotEmpty) remoteKeywords.add(keyword);
          }
        } catch (_) {}
      }
    } else if (settingsText != null) {
      try {
        final decoded = jsonDecode(settingsText);
        if (decoded is Map) {
          final data = decoded['data'];
          if (data is Map) {
            final raw = data['search_history'];
            if (raw is List) {
              remoteKeywords.addAll(raw.map((e) => e.toString()));
            }
          }
        }
      } catch (_) {}
    }
    final localKeywords = localSearchSnapshot ?? const <String>[];
    final merged = <String>[];
    final seen = <String>{};
    for (final keyword in [...remoteKeywords, ...localKeywords]) {
      if (seen.add(keyword)) merged.add(keyword);
    }
    await prefs.setStringList('search_history', merged);

    if (settingsText != null) {
      try {
        final settingsDecoded = jsonDecode(settingsText);
        if (settingsDecoded is Map) {
          final data = settingsDecoded['data'];
          if (data is Map) {
            await _mergeLocalFavorites(
              prefs,
              data,
              localFoldersSnapshot: localFoldersSnapshot,
              localEntriesSnapshot: localEntriesSnapshot,
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<CloudSyncLocalSnapshot> buildLocalSnapshotFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (CloudSyncConfigStore.alwaysSkippedSettings.contains(key)) {
        continue;
      }
      final value = prefs.get(key);
      if (key.startsWith('source_data_') && value is String) {
        settingsMap[key] = _stripAccountFromSourceData(value);
      } else {
        settingsMap[key] = value;
      }
    }
    final settingsJson = jsonEncode({
      'version': 2,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'data': settingsMap,
    });

    final historyRaw = prefs.getString('hazuki_read_history');
    List<Map<String, dynamic>> history = const [];
    if (historyRaw != null && historyRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(historyRaw);
        if (decoded is List) {
          history = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }
    if (history.length > 150) {
      history = history.sublist(0, 150);
    }

    final progress = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('reading_progress_')) {
        continue;
      }
      final comicId = key.substring('reading_progress_'.length);
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          progress.add({
            'comicId': comicId,
            'epId': map['epId'],
            'title': map['title'],
            'index': map['index'],
            'timestamp': map['timestamp'],
          });
        }
      } catch (_) {}
    }

    final readingJson = jsonEncode({
      'version': 1,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'history': history,
      'progress': progress,
    });

    final search = prefs.getStringList('search_history') ?? const <String>[];
    final lines = search
        .map((keyword) => jsonEncode({'keyword': keyword}))
        .join('\n');

    return CloudSyncLocalSnapshot(
      settings: settingsJson,
      reading: readingJson,
      searchHistoryJsonl: lines,
      historyCount: history.length,
      progressCount: progress.length,
      searchCount: search.length,
      jmSource: await _sourceService.readLocalJmSourceIfExists(),
    );
  }

  Future<void> _mergeLocalFavorites(
    SharedPreferences prefs,
    Map<dynamic, dynamic> remoteData, {
    String? localFoldersSnapshot,
    String? localEntriesSnapshot,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final tombstoneCutoff = nowMs - (90 * 24 * 60 * 60 * 1000);

    // Merge folder tombstones from both sides
    final folderTombstones = _mergeTombstoneMaps(
      _decodeTombstoneMap(
        prefs.getString(CloudSyncConfigStore.folderTombstonesKey),
        'id',
      ),
      _decodeTombstoneMap(
        remoteData[CloudSyncConfigStore.folderTombstonesKey] is String
            ? remoteData[CloudSyncConfigStore.folderTombstonesKey] as String
            : null,
        'id',
      ),
    );

    // Merge entry tombstones from both sides
    final entryTombstones = _mergeTombstoneMaps(
      _decodeTombstoneMap(
        prefs.getString(CloudSyncConfigStore.entryTombstonesKey),
        'comicId',
      ),
      _decodeTombstoneMap(
        remoteData[CloudSyncConfigStore.entryTombstonesKey] is String
            ? remoteData[CloudSyncConfigStore.entryTombstonesKey] as String
            : null,
        'comicId',
      ),
    );

    List<Map<String, dynamic>> localFolders = const [];
    final localFoldersRaw =
        localFoldersSnapshot ?? prefs.getString('local_favorite_folders_v1');
    if (localFoldersRaw != null) {
      try {
        final decoded = jsonDecode(localFoldersRaw);
        if (decoded is List) {
          localFolders = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    List<Map<String, dynamic>> remoteFolders = const [];
    final remoteFoldersRaw = remoteData['local_favorite_folders_v1'];
    if (remoteFoldersRaw is String && remoteFoldersRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(remoteFoldersRaw);
        if (decoded is List) {
          remoteFolders = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    // Merge folders, skipping any covered by a tombstone.
    // Folder IDs are microsecondsSinceEpoch strings; convert to ms for
    // comparison with tombstone's deletedAtMs (millisecondsSinceEpoch).
    bool isFolderTombstoned(String id) {
      final deletedAtMs = folderTombstones[id];
      if (deletedAtMs == null) return false;
      final createdAtMs = (int.tryParse(id) ?? 0) ~/ 1000;
      return deletedAtMs > createdAtMs;
    }

    final mergedFolders = <Map<String, dynamic>>[];
    final mergedFolderIds = <String>{};
    for (final folder in localFolders) {
      final id = folder['id']?.toString() ?? '';
      if (id.isEmpty || isFolderTombstoned(id)) continue;
      mergedFolders.add(folder);
      mergedFolderIds.add(id);
    }
    for (final folder in remoteFolders) {
      final id = folder['id']?.toString() ?? '';
      if (id.isEmpty || mergedFolderIds.contains(id)) continue;
      if (isFolderTombstoned(id)) continue;
      mergedFolders.add(folder);
      mergedFolderIds.add(id);
    }

    List<Map<String, dynamic>> localEntries = const [];
    final localEntriesRaw =
        localEntriesSnapshot ?? prefs.getString('local_favorite_entries_v1');
    if (localEntriesRaw != null) {
      try {
        final decoded = jsonDecode(localEntriesRaw);
        if (decoded is List) {
          localEntries = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    List<Map<String, dynamic>> remoteEntries = const [];
    final remoteEntriesRaw = remoteData['local_favorite_entries_v1'];
    if (remoteEntriesRaw is String && remoteEntriesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(remoteEntriesRaw);
        if (decoded is List) {
          remoteEntries = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    bool isEntryTombstoned(String comicId, int savedAtMs) {
      final deletedAtMs = entryTombstones[comicId];
      if (deletedAtMs == null) return false;
      return deletedAtMs > savedAtMs;
    }

    final mergedEntries = <String, Map<String, dynamic>>{};
    for (final entry in localEntries) {
      final normalizedEntry = _normalizeLocalFavoriteEntry(entry);
      if (normalizedEntry == null) continue;
      final comicId = normalizedEntry['comicId'] as String;
      final savedAtMs = _localFavoriteEntrySavedAtMs(normalizedEntry);
      if (isEntryTombstoned(comicId, savedAtMs)) continue;
      mergedEntries[comicId] = normalizedEntry;
    }
    for (final entry in remoteEntries) {
      final normalizedEntry = _normalizeLocalFavoriteEntry(entry);
      if (normalizedEntry == null) continue;
      final comicId = normalizedEntry['comicId'] as String;
      final savedAtMs = _localFavoriteEntrySavedAtMs(normalizedEntry);
      if (isEntryTombstoned(comicId, savedAtMs)) continue;
      final existing = mergedEntries[comicId];
      if (existing == null) {
        mergedEntries[comicId] = normalizedEntry;
      } else {
        final localTs = _localFavoriteEntrySavedAtMs(existing);
        final remoteTs = savedAtMs;
        final winner = remoteTs > localTs ? normalizedEntry : existing;
        mergedEntries[comicId] = _withNormalizedLocalFavoriteEntry(
          winner,
          folderSavedAtMs: _mergeFolderSavedAtMs(existing, normalizedEntry),
        );
      }
    }

    // Filter each entry's folder ids to only include folders that actually exist
    // after the merge, then drop entries that end up with no valid folder.
    for (final comicId in mergedEntries.keys.toList()) {
      final entry = mergedEntries[comicId]!;
      final folderSavedAtMs = _decodeFolderSavedAtMs(entry)
        ..removeWhere((folderId, _) => !mergedFolderIds.contains(folderId));
      if (folderSavedAtMs.isEmpty) {
        mergedEntries.remove(comicId);
      } else {
        mergedEntries[comicId] = _withNormalizedLocalFavoriteEntry(
          entry,
          folderSavedAtMs: folderSavedAtMs,
        );
      }
    }

    await prefs.setString(
      'local_favorite_folders_v1',
      jsonEncode(mergedFolders),
    );
    await prefs.setString(
      'local_favorite_entries_v1',
      jsonEncode(mergedEntries.values.toList()),
    );

    // Persist merged tombstones (pruned to 90 days)
    await prefs.setString(
      CloudSyncConfigStore.folderTombstonesKey,
      _encodeTombstoneMap(folderTombstones, 'id', tombstoneCutoff),
    );
    await prefs.setString(
      CloudSyncConfigStore.entryTombstonesKey,
      _encodeTombstoneMap(entryTombstones, 'comicId', tombstoneCutoff),
    );
  }

  Set<String> _toStringSet(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    return const {};
  }

  /// Decodes a tombstone JSON string into a map of id → deletedAtMs.
  Map<String, int> _decodeTombstoneMap(String? raw, String idField) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final result = <String, int>{};
      for (final item in decoded.whereType<Map>()) {
        final id = (item[idField] ?? '').toString().trim();
        final ts = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
        if (id.isNotEmpty && ts > 0) result[id] = ts;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Merges two tombstone maps, keeping the latest deletedAtMs per id.
  Map<String, int> _mergeTombstoneMaps(Map<String, int> a, Map<String, int> b) {
    final merged = Map<String, int>.from(a);
    for (final e in b.entries) {
      final existing = merged[e.key];
      if (existing == null || e.value > existing) merged[e.key] = e.value;
    }
    return merged;
  }

  /// Encodes a tombstone map to JSON, pruning entries older than [cutoff].
  String _encodeTombstoneMap(Map<String, int> map, String idField, int cutoff) {
    final pruned = map.entries
        .where((e) => e.value >= cutoff)
        .map((e) => {idField: e.key, 'deletedAtMs': e.value})
        .toList();
    return jsonEncode(pruned);
  }

  Map<String, int> _decodeFolderSavedAtMs(Map<String, dynamic> entry) {
    final folderSavedAtMs = <String, int>{};

    final folderSavedAtMsRaw = entry['folderSavedAtMs'];
    if (folderSavedAtMsRaw is Map) {
      for (final mapEntry in folderSavedAtMsRaw.entries) {
        final folderId = mapEntry.key.toString().trim();
        if (folderId.isEmpty) continue;
        final savedAtMs = (mapEntry.value as num?)?.toInt();
        if (savedAtMs == null) continue;
        folderSavedAtMs[folderId] = savedAtMs;
      }
    }

    if (folderSavedAtMs.isNotEmpty) {
      return folderSavedAtMs;
    }

    final fallbackSavedAtMs = (entry['savedAtMs'] as num?)?.toInt() ?? 0;
    for (final folderId in _toStringSet(entry['folderIds'])) {
      folderSavedAtMs[folderId] = fallbackSavedAtMs;
    }
    return folderSavedAtMs;
  }

  int _localFavoriteEntrySavedAtMs(Map<String, dynamic> entry) {
    var latest = 0;
    for (final savedAtMs in _decodeFolderSavedAtMs(entry).values) {
      if (savedAtMs > latest) {
        latest = savedAtMs;
      }
    }
    if (latest > 0) {
      return latest;
    }
    return (entry['savedAtMs'] as num?)?.toInt() ?? 0;
  }

  Map<String, dynamic>? _normalizeLocalFavoriteEntry(
    Map<String, dynamic> entry,
  ) {
    final comicId = (entry['comicId'] ?? '').toString().trim();
    if (comicId.isEmpty) {
      return null;
    }
    return _withNormalizedLocalFavoriteEntry(
      entry,
      comicId: comicId,
      folderSavedAtMs: _decodeFolderSavedAtMs(entry),
    );
  }

  Map<String, int> _mergeFolderSavedAtMs(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final merged = _decodeFolderSavedAtMs(first);
    for (final mapEntry in _decodeFolderSavedAtMs(second).entries) {
      final existingSavedAtMs = merged[mapEntry.key] ?? 0;
      if (mapEntry.value > existingSavedAtMs) {
        merged[mapEntry.key] = mapEntry.value;
      }
    }
    return merged;
  }

  Map<String, dynamic> _withNormalizedLocalFavoriteEntry(
    Map<String, dynamic> entry, {
    String? comicId,
    required Map<String, int> folderSavedAtMs,
  }) {
    final normalizedComicId =
        comicId ?? (entry['comicId'] ?? '').toString().trim();
    var latest = 0;
    for (final savedAtMs in folderSavedAtMs.values) {
      if (savedAtMs > latest) {
        latest = savedAtMs;
      }
    }
    return {
      ...entry,
      'comicId': normalizedComicId,
      'savedAtMs': latest,
      'folderIds': folderSavedAtMs.keys.toList(growable: false),
      'folderSavedAtMs': folderSavedAtMs,
    };
  }

  String _stripAccountFromSourceData(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return raw;
      }
      final sanitized = Map<String, dynamic>.from(decoded);
      sanitized.remove('account');
      return jsonEncode(sanitized);
    } catch (_) {
      return raw;
    }
  }
}
