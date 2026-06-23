import 'dart:convert';
import 'package:hazuki/app/service_locator.dart';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_preferences.dart';
import '../hazuki_source_service.dart';
import '../local_favorites_service.dart';
import '../reading_progress_service.dart';
import '../read_history_service.dart';
import '../search_history_service.dart';
import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_participant.dart';

class CloudSyncRestoreApplier {
  CloudSyncRestoreApplier({
    HazukiSourceService? sourceService,
    LocalFavoritesService? localFavoritesService,
    ReadHistoryService? readHistoryService,
    ReadingProgressService? readingProgressService,
    SearchHistoryService? searchHistoryService,
    SearchHistorySyncParticipant? searchHistoryParticipant,
    LocalFavoritesSyncParticipant? localFavoritesParticipant,
  }) : _sourceService = sourceService ?? sl<HazukiSourceService>(),
       _localFavoritesService =
           localFavoritesParticipant ??
           LocalFavoritesSyncParticipant(
             localFavoritesService ?? sl<LocalFavoritesService>(),
           ),
       _readHistoryService = readHistoryService ?? sl<ReadHistoryService>(),
       _readingProgressService =
           readingProgressService ?? sl<ReadingProgressService>(),
       _searchHistoryParticipant =
           searchHistoryParticipant ??
           SearchHistorySyncParticipant(
             searchHistoryService ?? sl<SearchHistoryService>(),
           );

  final HazukiSourceService _sourceService;
  final LocalFavoritesSyncParticipant _localFavoritesService;
  final ReadHistoryService _readHistoryService;
  final ReadingProgressService _readingProgressService;
  final SearchHistorySyncParticipant _searchHistoryParticipant;

  Future<CloudSyncApplySettingsResult> applySettingsJson(String content) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (e) {
      throw Exception('cloud_sync_settings_parse_failed:$e');
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
        prefs,
        entry.key,
        entry.value,
        skippedKeys: skippedKeys,
        appliedPlatformFilteredKeys: appliedPlatformFilteredKeys,
      );
      if (sanitized == null) {
        continue;
      }
      await _setPrefValue(prefs, entry.key, sanitized);
    }
    await _localFavoritesService.importJsonStrings(
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
    return CloudSyncApplySettingsResult(
      appliedPlatformFilteredKeys: appliedPlatformFilteredKeys,
      skippedKeys: skippedKeys,
    );
  }

  String? _stringValue(dynamic value) => value is String ? value : null;

  Future<void> _restoreManualRestoreSpecialSettings(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    for (final key in CloudSyncConfigStore.restoreSkippedSettings) {
      if (data.containsKey(key)) {
        await _setPrefValue(prefs, key, data[key]);
      } else {
        await prefs.remove(key);
      }
    }
  }

  Future<void> applyReadingSnapshot(String content) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (e) {
      throw Exception('cloud_sync_reading_parse_failed:$e');
    }
    if (decoded is! Map) {
      throw Exception('cloud_sync_reading_invalid_format');
    }
    final map = Map<String, dynamic>.from(decoded);
    final historyRaw = map['history'];
    if (historyRaw is List) {
      final history = historyRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final trimmed = history.length > hazukiReadHistoryMaxCount
          ? history.sublist(0, hazukiReadHistoryMaxCount)
          : history;
      await _readHistoryService.importJsonList(trimmed, replace: true);
    }

    final progressRaw = map['progress'];
    final progressList = <Map<String, dynamic>>[];
    if (progressRaw is List) {
      for (final item in progressRaw) {
        if (item is! Map) {
          continue;
        }
        final progress = Map<String, dynamic>.from(item);
        final comicId = (progress['comicId'] ?? '').toString().trim();
        if (comicId.isEmpty) {
          continue;
        }
        final sourceKey =
            (progress['sourceKey'] ?? _sourceService.activeSourceKey)
                .toString()
                .trim();
        progressList.add(<String, dynamic>{
          'comicId': comicId,
          'sourceKey': sourceKey,
          'epId': progress['epId'],
          'title': progress['title'],
          'index': progress['index'],
          'pageIndex': progress['pageIndex'],
          'timestamp': progress['timestamp'],
        });
      }
    }
    await _readingProgressService.replaceFromJsonList(progressList);
  }

  Future<void> applySearchHistoryJsonl(String content) async {
    await _searchHistoryParticipant.restoreSnapshot(content);
  }

  Future<bool> applySourceFile({
    required String? sourceText,
    required bool manifestHasSource,
  }) async {
    if (sourceText != null && sourceText.trim().isNotEmpty) {
      await _sourceService.writeLocalActiveSource(sourceText);
      return true;
    }
    if (manifestHasSource) {
      throw Exception('cloud_sync_source_missing');
    }
    return false;
  }

  dynamic _sanitizeRestoredSetting(
    SharedPreferences prefs,
    String key,
    dynamic value, {
    required List<String> skippedKeys,
    required List<String> appliedPlatformFilteredKeys,
  }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    if (CloudSyncConfigStore.shouldAlwaysSkipSetting(normalizedKey)) {
      skippedKeys.add(normalizedKey);
      return null;
    }
    if (CloudSyncConfigStore.restoreSkippedSettings.contains(normalizedKey)) {
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
    if (!normalizedKey.startsWith('source_data_')) {
      return value;
    }
    if (value is! String || value.trim().isEmpty) {
      return value;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return value;
      }
      final sanitized = Map<String, dynamic>.from(decoded);
      sanitized.remove('account');
      sanitized.remove('token');
      return jsonEncode(sanitized);
    } catch (_) {
      return value;
    }
  }

  Future<void> _setPrefValue(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    if (value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (value is List) {
      await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      return;
    }
    await prefs.setString(key, value.toString());
  }
}
