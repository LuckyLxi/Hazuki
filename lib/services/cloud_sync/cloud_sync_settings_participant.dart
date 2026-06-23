import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_preferences.dart';
import 'cloud_sync_config_store.dart';
import 'cloud_sync_comment_filter_participant.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_participant.dart';
import 'cloud_sync_favorites_participant.dart';

class CloudSyncSettingsMergeSnapshot {
  const CloudSyncSettingsMergeSnapshot({
    required this.commentFilter,
    required this.favoriteFolders,
    required this.favoriteEntries,
    required this.downloadGroups,
  });

  final CommentFilterMergeSnapshot commentFilter;
  final String favoriteFolders;
  final String favoriteEntries;
  final String downloadGroups;
}

class CloudSyncSettingsParticipant {
  const CloudSyncSettingsParticipant({
    required LocalFavoritesSyncParticipant localFavorites,
    required DownloadGroupsSyncParticipant downloadGroups,
    required CommentFilterSyncParticipant commentFilter,
  }) : _localFavorites = localFavorites,
       _downloadGroups = downloadGroups,
       _commentFilter = commentFilter;

  final LocalFavoritesSyncParticipant _localFavorites;
  final DownloadGroupsSyncParticipant _downloadGroups;
  final CommentFilterSyncParticipant _commentFilter;

  Future<CloudSyncSettingsMergeSnapshot> captureMergeSnapshot() async {
    return CloudSyncSettingsMergeSnapshot(
      commentFilter: await _commentFilter.captureMergeSnapshot(),
      favoriteFolders: await _localFavorites.exportFoldersJsonString(),
      favoriteEntries: await _localFavorites.exportEntriesJsonString(),
      downloadGroups: await _downloadGroups.exportSnapshot(),
    );
  }

  Future<void> mergeRemote(
    String content,
    CloudSyncSettingsMergeSnapshot local, {
    required bool applyRemoteSettings,
  }) async {
    final root = _decodeMap(content);
    final rawData = root?['data'];
    if (rawData is! Map) return;
    final data = Map<dynamic, dynamic>.from(rawData);
    final prefs = await SharedPreferences.getInstance();

    if (applyRemoteSettings) {
      await _applyRemotePreferences(prefs, data);
    }
    await _localFavorites.mergeRemote(
      data,
      localFoldersSnapshot: local.favoriteFolders,
      localEntriesSnapshot: local.favoriteEntries,
    );
    await _commentFilter.mergeRemote(
      data,
      local.commentFilter,
      remoteSettingsAreNewer: applyRemoteSettings,
    );
    final remoteGroupsRaw = data[CloudSyncConfigStore.downloadGroupsKey];
    await _downloadGroups.mergeSnapshot(local.downloadGroups);
    await _downloadGroups.mergeSnapshot(
      remoteGroupsRaw is String ? remoteGroupsRaw : null,
    );
  }

  Future<String> exportSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (CloudSyncConfigStore.shouldAlwaysSkipSetting(key)) continue;
      final value = prefs.get(key);
      settingsMap[key] = key.startsWith('source_data_') && value is String
          ? _stripAccountFromSourceData(value)
          : value;
    }
    settingsMap[CloudSyncConfigStore.downloadGroupsKey] = await _downloadGroups
        .exportSnapshot();
    settingsMap[CloudSyncConfigStore.localFavoriteFoldersKey] =
        await _localFavorites.exportFoldersJsonString();
    settingsMap[CloudSyncConfigStore.localFavoriteEntriesKey] =
        await _localFavorites.exportEntriesJsonString();
    settingsMap[CloudSyncConfigStore.folderTombstonesKey] =
        await _localFavorites.exportFolderTombstonesJsonString();
    settingsMap[CloudSyncConfigStore.entryTombstonesKey] = await _localFavorites
        .exportEntryTombstonesJsonString();
    settingsMap[CloudSyncConfigStore.comicFolderTombstonesKey] =
        await _localFavorites.exportComicFolderTombstonesJsonString();
    return jsonEncode({
      'version': 2,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'data': settingsMap,
    });
  }

  Future<CloudSyncApplySettingsResult> restoreSnapshot(String content) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (error) {
      throw Exception('cloud_sync_settings_parse_failed:$error');
    }
    if (decoded is! Map) {
      throw Exception('cloud_sync_settings_invalid_format');
    }
    final dataRaw = decoded['data'];
    if (dataRaw is! Map) {
      throw Exception('cloud_sync_settings_missing_data');
    }
    final data = Map<String, dynamic>.from(dataRaw);
    final prefs = await SharedPreferences.getInstance();
    final appliedPlatformFilteredKeys = <String>[];
    final skippedKeys = <String>[];
    await _restoreManualRestoreSpecialSettings(prefs, data);
    for (final entry in data.entries) {
      final sanitized = _sanitizeRestoredSetting(
        entry.key,
        entry.value,
        skippedKeys: skippedKeys,
        appliedPlatformFilteredKeys: appliedPlatformFilteredKeys,
      );
      if (sanitized == null) continue;
      await _setPrefValue(prefs, entry.key, sanitized, stringifyUnknown: true);
    }
    await _localFavorites.importJsonStrings(
      foldersRaw: _stringValue(
        data[CloudSyncConfigStore.localFavoriteFoldersKey],
      ),
      entriesRaw: _stringValue(
        data[CloudSyncConfigStore.localFavoriteEntriesKey],
      ),
      folderTombstonesRaw: _stringValue(
        data[CloudSyncConfigStore.folderTombstonesKey],
      ),
      entryTombstonesRaw: _stringValue(
        data[CloudSyncConfigStore.entryTombstonesKey],
      ),
      comicFolderTombstonesRaw: _stringValue(
        data[CloudSyncConfigStore.comicFolderTombstonesKey],
      ),
      replace: true,
    );
    await _downloadGroups.restoreSnapshot(
      _stringValue(data[CloudSyncConfigStore.downloadGroupsKey]),
    );
    return CloudSyncApplySettingsResult(
      appliedPlatformFilteredKeys: appliedPlatformFilteredKeys,
      skippedKeys: skippedKeys,
    );
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
          key == hazukiCommentFilterKeywordsUpdatedAtKey ||
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
          key == hazukiCommentFilterKeywordsKey ||
          key == hazukiCommentFilterKeywordsUpdatedAtKey ||
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

  Future<void> _restoreManualRestoreSpecialSettings(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    for (final key in CloudSyncConfigStore.restoreSkippedSettings) {
      if (data.containsKey(key)) {
        await _setPrefValue(prefs, key, data[key], stringifyUnknown: true);
      } else {
        await prefs.remove(key);
      }
    }
  }

  dynamic _sanitizeRestoredSetting(
    String key,
    dynamic value, {
    required List<String> skippedKeys,
    required List<String> appliedPlatformFilteredKeys,
  }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return null;
    if (CloudSyncConfigStore.shouldAlwaysSkipSetting(normalizedKey) ||
        CloudSyncConfigStore.restoreSkippedSettings.contains(normalizedKey)) {
      skippedKeys.add(normalizedKey);
      return null;
    }
    if (CloudSyncConfigStore.windowsOnlySettings.contains(normalizedKey)) {
      if (!Platform.isWindows) {
        skippedKeys.add(normalizedKey);
        return null;
      }
      appliedPlatformFilteredKeys.add(normalizedKey);
    }
    if (CloudSyncConfigStore.androidOnlySettings.contains(normalizedKey)) {
      if (!Platform.isAndroid) {
        skippedKeys.add(normalizedKey);
        return null;
      }
      appliedPlatformFilteredKeys.add(normalizedKey);
    }
    return normalizedKey.startsWith('source_data_') && value is String
        ? _stripAccountFromSourceData(value)
        : value;
  }

  String? _earliestFirstUseDate(String? localRaw, dynamic remoteValue) {
    final remoteRaw = remoteValue is String ? remoteValue : null;
    final localDate = localRaw == null ? null : DateTime.tryParse(localRaw);
    final remoteDate = remoteRaw == null ? null : DateTime.tryParse(remoteRaw);
    if (localDate == null) return remoteRaw;
    if (remoteDate == null) return localRaw;
    return remoteDate.isBefore(localDate) ? remoteRaw : localRaw;
  }

  Map<String, dynamic>? _decodeMap(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _stripAccountFromSourceData(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return raw;
      final sanitized = Map<String, dynamic>.from(decoded)
        ..remove('account')
        ..remove('token');
      return jsonEncode(sanitized);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _setPrefValue(
    SharedPreferences prefs,
    String key,
    dynamic value, {
    bool stringifyUnknown = false,
  }) async {
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
      await prefs.setStringList(key, value.map((entry) => '$entry').toList());
    } else if (stringifyUnknown) {
      await prefs.setString(key, value.toString());
    }
  }

  String? _stringValue(dynamic value) => value is String ? value : null;
}
