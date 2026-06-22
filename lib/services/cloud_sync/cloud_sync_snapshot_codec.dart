import 'dart:convert';
import 'dart:io';
import 'package:hazuki/app/service_locator.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_preferences.dart';
import '../hazuki_source_service.dart';
import '../local_favorites_service.dart';
import '../download_groups_service.dart';
import '../reading_progress_service.dart';
import '../read_history_service.dart';
import '../../features/search/support/search_history_service.dart';
import '../../models/hazuki_models.dart';
import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_remote_client.dart';

class CloudSyncSnapshotCodec {
  CloudSyncSnapshotCodec({
    required CloudSyncConfigStore configStore,
    HazukiSourceService? sourceService,
    ReadHistoryService? readHistoryService,
    ReadingProgressService? readingProgressService,
    LocalFavoritesService? localFavoritesService,
    DownloadGroupsService? downloadGroupsService,
    SearchHistoryService? searchHistoryService,
  }) : _sourceService = sourceService ?? sl<HazukiSourceService>(),
       _readHistoryService = readHistoryService ?? sl<ReadHistoryService>(),
       _readingProgressService =
           readingProgressService ?? sl<ReadingProgressService>(),
       _localFavoritesService =
           localFavoritesService ?? sl<LocalFavoritesService>(),
       _downloadGroupsService =
           downloadGroupsService ?? sl<DownloadGroupsService>(),
       _searchHistoryService =
           searchHistoryService ?? sl<SearchHistoryService>();

  final HazukiSourceService _sourceService;
  final ReadHistoryService _readHistoryService;
  final ReadingProgressService _readingProgressService;
  final LocalFavoritesService _localFavoritesService;
  final DownloadGroupsService _downloadGroupsService;
  final SearchHistoryService _searchHistoryService;

  Future<void> mergeRemoteIntoLocal(
    CloudSyncRemoteClient client, {
    bool applyRemoteSettings = false,
  }) async {
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

    final localHistorySnapshot = jsonEncode(
      await _readHistoryService.exportJsonList(),
    );
    final localProgressSnapshot = await _readingProgressService
        .exportJsonList();
    final localCommentFilterKeywordsSnapshot =
        prefs.getStringList(hazukiCommentFilterKeywordsKey) ?? const <String>[];
    final localFoldersSnapshot = await _localFavoritesService
        .exportFoldersJsonString();
    final localEntriesSnapshot = await _localFavoritesService
        .exportEntriesJsonString();
    final localDownloadGroupsSnapshot = await _downloadGroupsService
        .exportJsonString();

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
        try {
          final decoded = jsonDecode(localHistorySnapshot);
          if (decoded is List) {
            localHistory = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } catch (_) {}

        final mergedHistory = <String, Map<String, dynamic>>{};
        for (final entry in [...localHistory, ...remoteHistory]) {
          final comicId = (entry['id'] ?? '').toString().trim();
          if (comicId.isEmpty) continue;
          final sourceKey =
              (entry['sourceKey'] ?? _sourceService.activeSourceKey)
                  .toString()
                  .trim();
          entry['sourceKey'] = sourceKey;
          final storageKey = SourceScopedComicId(
            sourceKey: sourceKey,
            comicId: comicId,
          ).storageKey;
          final ts = (entry['timestamp'] as num?)?.toInt() ?? 0;
          final existing = mergedHistory[storageKey];
          final existingTs = (existing?['timestamp'] as num?)?.toInt() ?? 0;
          if (existing == null || ts > existingTs) {
            mergedHistory[storageKey] = entry;
          }
        }
        var historyList = mergedHistory.values.toList()
          ..sort(
            (a, b) => ((b['timestamp'] as num?)?.toInt() ?? 0).compareTo(
              (a['timestamp'] as num?)?.toInt() ?? 0,
            ),
          );
        if (historyList.length > hazukiReadHistoryMaxCount) {
          historyList = historyList.sublist(0, hazukiReadHistoryMaxCount);
        }
        await _readHistoryService.importJsonList(historyList, replace: true);

        final remoteProgressRaw = readingMap['progress'];
        final remoteProgress = <String, Map<String, dynamic>>{};
        if (remoteProgressRaw is List) {
          for (final item in remoteProgressRaw) {
            if (item is! Map) continue;
            final entry = Map<String, dynamic>.from(item);
            final comicId = (entry['comicId'] ?? '').toString().trim();
            if (comicId.isEmpty) continue;
            final sourceKey =
                (entry['sourceKey'] ?? _sourceService.activeSourceKey)
                    .toString()
                    .trim();
            entry['sourceKey'] = sourceKey;
            remoteProgress[SourceScopedComicId(
                  sourceKey: sourceKey,
                  comicId: comicId,
                ).storageKey] =
                entry;
          }
        }

        final localProgress = <String, Map<String, dynamic>>{};
        for (final entry in localProgressSnapshot) {
          final comicId = (entry['comicId'] ?? '').toString().trim();
          if (comicId.isEmpty) continue;
          final sourceKey =
              (entry['sourceKey'] ?? _sourceService.activeSourceKey)
                  .toString()
                  .trim();
          entry['sourceKey'] = sourceKey;
          localProgress[SourceScopedComicId(
                sourceKey: sourceKey,
                comicId: comicId,
              ).storageKey] =
              entry;
        }

        final allStorageKeys = {...localProgress.keys, ...remoteProgress.keys};
        for (final storageKey in allStorageKeys) {
          final local = localProgress[storageKey];
          final remote = remoteProgress[storageKey];
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
          final scoped = SourceScopedComicId.fromStorageKey(
            storageKey,
            fallbackSourceKey:
                (winner['sourceKey'] ?? _sourceService.activeSourceKey)
                    .toString(),
          );
          winner['comicId'] = scoped.comicId;
          winner['sourceKey'] = scoped.sourceKey;
          await _readingProgressService.mergeJsonList([winner]);
        }
      }
    }

    if (searchText != null) {
      await _searchHistoryService.mergeSyncJsonl(searchText);
    } else if (settingsText != null) {
      try {
        final decoded = jsonDecode(settingsText);
        if (decoded is Map) {
          final data = decoded['data'];
          if (data is Map) {
            final raw = data['search_history'];
            if (raw is List) {
              await _searchHistoryService.mergeSyncJsonl(
                raw
                    .map((keyword) => jsonEncode({'keyword': keyword}))
                    .join('\n'),
              );
            }
          }
        }
      } catch (_) {}
    }

    if (settingsText != null) {
      try {
        final settingsDecoded = jsonDecode(settingsText);
        if (settingsDecoded is Map) {
          final data = settingsDecoded['data'];
          if (data is Map) {
            if (applyRemoteSettings) {
              await _applyRemotePreferences(prefs, data);
            }
            await _mergeLocalFavorites(
              prefs,
              data,
              localFoldersSnapshot: localFoldersSnapshot,
              localEntriesSnapshot: localEntriesSnapshot,
            );
            await _mergeCommentFilterKeywords(
              prefs,
              data,
              localKeywordsSnapshot: localCommentFilterKeywordsSnapshot,
            );
            final remoteGroupsRaw =
                data[CloudSyncConfigStore.downloadGroupsKey];
            final remoteGroups = remoteGroupsRaw is String
                ? remoteGroupsRaw
                : null;
            await _downloadGroupsService.importJsonString(
              localDownloadGroupsSnapshot,
            );
            await _downloadGroupsService.importJsonString(remoteGroups);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _applyRemotePreferences(
    SharedPreferences prefs,
    Map<dynamic, dynamic> remoteData,
  ) async {
    final remoteKeys = remoteData.keys
        .map((key) => key.toString().trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    for (final key in prefs.getKeys()) {
      if (remoteKeys.contains(key) ||
          key == hazukiFirstUseDatePreferenceKey ||
          key == hazukiCommentFilterKeywordsKey ||
          CloudSyncConfigStore.shouldAlwaysSkipSetting(key) ||
          CloudSyncConfigStore.restoreSkippedSettings.contains(key) ||
          CloudSyncConfigStore.windowsOnlySettings.contains(key) ||
          CloudSyncConfigStore.androidOnlySettings.contains(key)) {
        continue;
      }
      await prefs.remove(key);
    }

    for (final entry in remoteData.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty ||
          CloudSyncConfigStore.shouldAlwaysSkipSetting(key) ||
          CloudSyncConfigStore.restoreSkippedSettings.contains(key) ||
          (CloudSyncConfigStore.windowsOnlySettings.contains(key) &&
              !Platform.isWindows) ||
          (CloudSyncConfigStore.androidOnlySettings.contains(key) &&
              !Platform.isAndroid)) {
        continue;
      }

      var value = entry.value;
      if (key == hazukiFirstUseDatePreferenceKey) {
        value = _earliestFirstUseDate(prefs.getString(key), value);
      } else if (key.startsWith('source_data_') && value is String) {
        value = _stripAccountFromSourceData(value);
      }
      await _setPrefValue(prefs, key, value);
    }
  }

  String? _earliestFirstUseDate(String? localRaw, dynamic remoteValue) {
    final remoteRaw = remoteValue is String ? remoteValue : null;
    final localDate = localRaw == null ? null : DateTime.tryParse(localRaw);
    final remoteDate = remoteRaw == null ? null : DateTime.tryParse(remoteRaw);
    if (localDate == null) {
      return remoteRaw;
    }
    if (remoteDate == null) {
      return localRaw;
    }
    return remoteDate.isBefore(localDate) ? remoteRaw : localRaw;
  }

  Future<void> _setPrefValue(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((item) => '$item').toList());
    }
  }

  Future<CloudSyncLocalSnapshot> buildLocalSnapshotFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (CloudSyncConfigStore.shouldAlwaysSkipSetting(key)) {
        continue;
      }
      final value = prefs.get(key);
      if (key.startsWith('source_data_') && value is String) {
        settingsMap[key] = _stripAccountFromSourceData(value);
      } else {
        settingsMap[key] = value;
      }
    }
    settingsMap[CloudSyncConfigStore.downloadGroupsKey] =
        await _downloadGroupsService.exportJsonString();
    settingsMap[CloudSyncConfigStore.localFavoriteFoldersKey] =
        await _localFavoritesService.exportFoldersJsonString();
    settingsMap[CloudSyncConfigStore.localFavoriteEntriesKey] =
        await _localFavoritesService.exportEntriesJsonString();
    settingsMap[CloudSyncConfigStore.folderTombstonesKey] =
        await _localFavoritesService.exportFolderTombstonesJsonString();
    settingsMap[CloudSyncConfigStore.entryTombstonesKey] =
        await _localFavoritesService.exportEntryTombstonesJsonString();
    settingsMap[CloudSyncConfigStore.comicFolderTombstonesKey] =
        await _localFavoritesService.exportComicFolderTombstonesJsonString();
    final settingsJson = jsonEncode({
      'version': 2,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'data': settingsMap,
    });

    List<Map<String, dynamic>> history = await _readHistoryService
        .exportJsonList();
    if (history.length > hazukiReadHistoryMaxCount) {
      history = history.sublist(0, hazukiReadHistoryMaxCount);
    }

    final progress = await _readingProgressService.exportJsonList();

    final readingJson = jsonEncode({
      'version': 1,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'history': history,
      'progress': progress,
    });

    final search = (await _searchHistoryService.load()).take(
      hazukiSearchHistoryMaxCount,
    );
    final lines = await _searchHistoryService.exportSyncJsonl();

    // 仅当用户手动编辑过源文件时才将其上传到云端，
    // 避免把自动下载的官方源错误地同步到其他设备。
    final hasCustomSource = await _sourceService.hasCustomEditedActiveSource();
    final jmSource = hasCustomSource
        ? await _sourceService.readLocalActiveSourceIfExists()
        : null;

    return CloudSyncLocalSnapshot(
      settings: settingsJson,
      reading: readingJson,
      searchHistoryJsonl: lines,
      historyCount: history.length,
      progressCount: progress.length,
      searchCount: search.length,
      jmSource: jmSource,
    );
  }

  Future<void> _mergeCommentFilterKeywords(
    SharedPreferences prefs,
    Map<dynamic, dynamic> remoteData, {
    required List<String> localKeywordsSnapshot,
  }) async {
    final remoteRaw = remoteData[hazukiCommentFilterKeywordsKey];
    if (remoteRaw is! List) {
      return;
    }

    final merged = <String>[];
    final seen = <String>{};
    for (final keyword in [
      ...remoteRaw.map((e) => e.toString()),
      ...localKeywordsSnapshot,
    ]) {
      if (keyword.trim().isEmpty) {
        continue;
      }
      if (seen.add(keyword)) {
        merged.add(keyword);
      }
    }
    await prefs.setStringList(hazukiCommentFilterKeywordsKey, merged);
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
        await _localFavoritesService.exportFolderTombstonesJsonString(),
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
      _decodeEntryTombstoneMap(
        await _localFavoritesService.exportEntryTombstonesJsonString(),
      ),
      _decodeEntryTombstoneMap(
        remoteData[CloudSyncConfigStore.entryTombstonesKey] is String
            ? remoteData[CloudSyncConfigStore.entryTombstonesKey] as String
            : null,
      ),
    );
    final comicFolderTombstones = _mergeTombstoneMaps(
      _decodeComicFolderTombstoneMap(
        await _localFavoritesService.exportComicFolderTombstonesJsonString(),
      ),
      _decodeComicFolderTombstoneMap(
        remoteData[CloudSyncConfigStore.comicFolderTombstonesKey] is String
            ? remoteData[CloudSyncConfigStore.comicFolderTombstonesKey]
                  as String
            : null,
      ),
    );

    List<Map<String, dynamic>> localFolders = const [];
    final localFoldersRaw = localFoldersSnapshot;
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
    final remoteFoldersRaw =
        remoteData[CloudSyncConfigStore.localFavoriteFoldersKey];
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
    final mergedFoldersById = <String, Map<String, dynamic>>{};
    for (final folder in localFolders) {
      final id = folder['id']?.toString() ?? '';
      if (id.isEmpty || isFolderTombstoned(id)) continue;
      mergedFoldersById[id] = folder;
    }
    for (final folder in remoteFolders) {
      final id = folder['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (isFolderTombstoned(id)) continue;
      final existing = mergedFoldersById[id];
      final existingUpdatedAtMs =
          (existing?['updatedAtMs'] as num?)?.toInt() ?? 0;
      final remoteUpdatedAtMs = (folder['updatedAtMs'] as num?)?.toInt() ?? 0;
      if (existing == null || remoteUpdatedAtMs > existingUpdatedAtMs) {
        mergedFoldersById[id] = folder;
      }
    }
    mergedFolders.addAll(mergedFoldersById.values);
    final mergedFolderIds = mergedFoldersById.keys.toSet();

    List<Map<String, dynamic>> localEntries = const [];
    final localEntriesRaw = localEntriesSnapshot;
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
    final remoteEntriesRaw =
        remoteData[CloudSyncConfigStore.localFavoriteEntriesKey];
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

    bool isEntryTombstoned(String storageKey, int savedAtMs) {
      final deletedAtMs = entryTombstones[storageKey];
      if (deletedAtMs == null) return false;
      return deletedAtMs >= savedAtMs;
    }

    final mergedEntries = <String, Map<String, dynamic>>{};
    for (final entry in localEntries) {
      var normalizedEntry = _normalizeLocalFavoriteEntry(entry);
      if (normalizedEntry == null) continue;
      final comicId = normalizedEntry['comicId'] as String;
      final sourceKey = (normalizedEntry['sourceKey'] ?? '').toString();
      final storageKey = SourceScopedComicId(
        sourceKey: sourceKey,
        comicId: comicId,
      ).storageKey;
      normalizedEntry = _withoutTombstonedComicFolders(
        normalizedEntry,
        storageKey,
        comicFolderTombstones,
      );
      final savedAtMs = _localFavoriteEntrySavedAtMs(normalizedEntry);
      if (savedAtMs <= 0) continue;
      if (isEntryTombstoned(storageKey, savedAtMs)) continue;
      mergedEntries[storageKey] = normalizedEntry;
    }
    for (final entry in remoteEntries) {
      var normalizedEntry = _normalizeLocalFavoriteEntry(entry);
      if (normalizedEntry == null) continue;
      final comicId = normalizedEntry['comicId'] as String;
      final sourceKey = (normalizedEntry['sourceKey'] ?? '').toString();
      final storageKey = SourceScopedComicId(
        sourceKey: sourceKey,
        comicId: comicId,
      ).storageKey;
      normalizedEntry = _withoutTombstonedComicFolders(
        normalizedEntry,
        storageKey,
        comicFolderTombstones,
      );
      final savedAtMs = _localFavoriteEntrySavedAtMs(normalizedEntry);
      if (savedAtMs <= 0) continue;
      if (isEntryTombstoned(storageKey, savedAtMs)) continue;
      final existing = mergedEntries[storageKey];
      if (existing == null) {
        mergedEntries[storageKey] = normalizedEntry;
      } else {
        final localTs = _localFavoriteEntrySavedAtMs(existing);
        final remoteTs = savedAtMs;
        final winner = remoteTs > localTs ? normalizedEntry : existing;
        mergedEntries[storageKey] = _withNormalizedLocalFavoriteEntry(
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

    final mergedFoldersRaw = jsonEncode(mergedFolders);
    final mergedEntriesRaw = jsonEncode(mergedEntries.values.toList());

    // Persist merged tombstones (pruned to 90 days)
    await _localFavoritesService.importJsonStrings(
      foldersRaw: mergedFoldersRaw,
      entriesRaw: mergedEntriesRaw,
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

  Map<String, int> _decodeEntryTombstoneMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final result = <String, int>{};
      for (final item in decoded.whereType<Map>()) {
        final comicId = (item['comicId'] ?? '').toString().trim();
        if (comicId.isEmpty) continue;
        final ts = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
        if (ts <= 0) continue;
        final sourceKey = (item['sourceKey'] ?? '').toString().trim();
        final storageKey = SourceScopedComicId(
          sourceKey: sourceKey,
          comicId: comicId,
        ).storageKey;
        final existing = result[storageKey];
        if (existing == null || ts > existing) {
          result[storageKey] = ts;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Map<String, int> _decodeComicFolderTombstoneMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      final result = <String, int>{};
      for (final item in decoded.whereType<Map>()) {
        final comicId = (item['comicId'] ?? '').toString().trim();
        final folderId = (item['folderId'] ?? '').toString().trim();
        final deletedAtMs = (item['deletedAtMs'] as num?)?.toInt() ?? 0;
        if (comicId.isEmpty || folderId.isEmpty || deletedAtMs <= 0) continue;
        final storageKey = SourceScopedComicId(
          sourceKey: (item['sourceKey'] ?? '').toString().trim(),
          comicId: comicId,
        ).storageKey;
        final key = _comicFolderTombstoneKey(storageKey, folderId);
        final existing = result[key];
        if (existing == null || deletedAtMs > existing) {
          result[key] = deletedAtMs;
        }
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

  String _encodeEntryTombstoneMap(Map<String, int> map, int cutoff) {
    final pruned = map.entries.where((e) => e.value >= cutoff).map((e) {
      final scoped = SourceScopedComicId.fromStorageKey(e.key);
      return {
        'comicId': scoped.comicId,
        if (scoped.sourceKey.isNotEmpty) 'sourceKey': scoped.sourceKey,
        'deletedAtMs': e.value,
      };
    }).toList();
    return jsonEncode(pruned);
  }

  String _encodeComicFolderTombstoneMap(Map<String, int> map, int cutoff) {
    final pruned = map.entries.where((e) => e.value >= cutoff).map((e) {
      final parts = jsonDecode(e.key) as List<dynamic>;
      final scoped = SourceScopedComicId.fromStorageKey(parts[0] as String);
      return {
        'comicId': scoped.comicId,
        if (scoped.sourceKey.isNotEmpty) 'sourceKey': scoped.sourceKey,
        'folderId': parts[1] as String,
        'deletedAtMs': e.value,
      };
    }).toList();
    return jsonEncode(pruned);
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
      sourceKey: (entry['sourceKey'] ?? '').toString().trim(),
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
    String? sourceKey,
    required Map<String, int> folderSavedAtMs,
  }) {
    final normalizedComicId =
        comicId ?? (entry['comicId'] ?? '').toString().trim();
    final normalizedSourceKey =
        sourceKey ?? (entry['sourceKey'] ?? '').toString().trim();
    var latest = 0;
    for (final savedAtMs in folderSavedAtMs.values) {
      if (savedAtMs > latest) {
        latest = savedAtMs;
      }
    }
    return {
      ...entry,
      'comicId': normalizedComicId,
      if (normalizedSourceKey.isNotEmpty) 'sourceKey': normalizedSourceKey,
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
      sanitized.remove('token');
      return jsonEncode(sanitized);
    } catch (_) {
      return raw;
    }
  }
}
