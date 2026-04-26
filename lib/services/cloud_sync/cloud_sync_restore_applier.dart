import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../hazuki_source_service.dart';
import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';

class CloudSyncRestoreApplier {
  CloudSyncRestoreApplier({HazukiSourceService? sourceService})
    : _sourceService = sourceService ?? HazukiSourceService.instance;

  final HazukiSourceService _sourceService;

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
    return CloudSyncApplySettingsResult(
      appliedPlatformFilteredKeys: appliedPlatformFilteredKeys,
      skippedKeys: skippedKeys,
    );
  }

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
    final prefs = await SharedPreferences.getInstance();

    final historyRaw = map['history'];
    if (historyRaw is List) {
      final history = historyRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final trimmed = history.length > 150 ? history.sublist(0, 150) : history;
      await prefs.setString('hazuki_read_history', jsonEncode(trimmed));
    }

    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('reading_progress_')) {
        await prefs.remove(key);
      }
    }

    final progressRaw = map['progress'];
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
        final store = <String, dynamic>{
          'epId': progress['epId'],
          'title': progress['title'],
          'index': progress['index'],
          'timestamp': progress['timestamp'],
        };
        await prefs.setString('reading_progress_$comicId', jsonEncode(store));
      }
    }
  }

  Future<void> applySearchHistoryJsonl(String content) async {
    final lines = content.split('\n');
    final list = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) {
          final keyword = (decoded['keyword'] ?? '').toString().trim();
          if (keyword.isNotEmpty) {
            list.add(keyword);
          }
        }
      } catch (_) {}
    }
    final deduped = <String>[];
    final seen = <String>{};
    for (final keyword in list) {
      if (seen.add(keyword)) {
        deduped.add(keyword);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', deduped);
  }

  Future<bool> applySourceFile({
    required String? sourceText,
    required bool manifestHasSource,
  }) async {
    if (sourceText != null && sourceText.trim().isNotEmpty) {
      await _sourceService.writeLocalJmSource(sourceText);
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
    if (CloudSyncConfigStore.alwaysSkippedSettings.contains(normalizedKey)) {
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
      final existingRaw = prefs.getString(normalizedKey);
      if (existingRaw != null && existingRaw.trim().isNotEmpty) {
        try {
          final existingDecoded = jsonDecode(existingRaw);
          if (existingDecoded is Map && existingDecoded['account'] != null) {
            sanitized['account'] = existingDecoded['account'];
          }
        } catch (_) {}
      }
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
