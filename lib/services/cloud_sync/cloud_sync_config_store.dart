import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_preferences.dart';
import 'cloud_sync_models.dart';

class CloudSyncConfigStore {
  static const enabledKey = 'cloud_sync_enabled';
  static const urlKey = 'cloud_sync_url';
  static const usernameKey = 'cloud_sync_username';
  static const passwordKey = 'cloud_sync_password';
  static const lastSyncedRemoteTsKey = 'cloud_sync_last_synced_remote_ts';
  static const downloadStateKey = 'manga_download_service_state_v2';
  static const downloadsRootPathKey = 'manga_download_root_path_v1';

  static const settingsFileName = 'settings.json';
  static const readingFileName = 'reading.json';
  static const legacyReadingFileName = 'reading.sqlite';
  static const searchHistoryFileName = 'search_history.jsonl';
  static const manifestFileName = 'manifest.json';
  static const sourceDirName = 'source';
  static const sourceFileName = 'jm.js';

  static const folderTombstonesKey = 'local_favorite_folder_tombstones_v1';
  static const entryTombstonesKey = 'local_favorite_entry_tombstones_v1';

  static const Set<String> alwaysSkippedSettings = {
    'cookie_store_v1',
    downloadStateKey,
    downloadsRootPathKey,
  };

  /// Keys that bypass the generic settings-restore loop and are restored
  /// specially during manual full restore so missing keys clear local state.
  static const Set<String> restoreSkippedSettings = {
    folderTombstonesKey,
    entryTombstonesKey,
  };
  static const Set<String> windowsOnlySettings = {
    hazukiUseSystemTitleBarPreferenceKey,
  };
  static const Set<String> androidOnlySettings = {'appearance_display_mode'};

  Future<CloudSyncConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return CloudSyncConfig(
      enabled: prefs.getBool(enabledKey) ?? false,
      url: prefs.getString(urlKey) ?? '',
      username: prefs.getString(usernameKey) ?? '',
      password: prefs.getString(passwordKey) ?? '',
    );
  }

  Future<void> saveConfig(CloudSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, config.enabled);
    await prefs.setString(urlKey, config.url.trim());
    await prefs.setString(usernameKey, config.username.trim());
    await prefs.setString(passwordKey, config.password);
  }

  Future<int> loadLastSyncedRemoteTs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(lastSyncedRemoteTsKey) ?? 0;
  }

  Future<void> saveLastSyncedRemoteTs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastSyncedRemoteTsKey, value);
  }

  String rootUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return '$normalized/HazukiSync';
  }

  String get currentPlatformName {
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    return 'unknown';
  }
}
