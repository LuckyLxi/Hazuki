import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_preferences.dart';
import 'hazuki_source_service.dart';

class CloudSyncConfig {
  const CloudSyncConfig({
    required this.enabled,
    required this.url,
    required this.username,
    required this.password,
  });

  final bool enabled;
  final String url;
  final String username;
  final String password;

  bool get isComplete =>
      url.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  CloudSyncConfig copyWith({
    bool? enabled,
    String? url,
    String? username,
    String? password,
  }) {
    return CloudSyncConfig(
      enabled: enabled ?? this.enabled,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

class CloudSyncConnectionStatus {
  const CloudSyncConnectionStatus({
    required this.ok,
    required this.message,
    required this.checkedAt,
  });

  final bool ok;
  final String message;
  final DateTime checkedAt;
}

class CloudSyncRestoreResult {
  const CloudSyncRestoreResult({
    required this.restoredSettings,
    required this.restoredReading,
    required this.restoredSearchHistory,
    required this.restoredSourceFile,
    required this.appliedPlatformFilteredKeys,
    required this.skippedKeys,
  });

  final bool restoredSettings;
  final bool restoredReading;
  final bool restoredSearchHistory;
  final bool restoredSourceFile;
  final List<String> appliedPlatformFilteredKeys;
  final List<String> skippedKeys;
}

class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  static const _enabledKey = 'cloud_sync_enabled';
  static const _urlKey = 'cloud_sync_url';
  static const _usernameKey = 'cloud_sync_username';
  static const _passwordKey = 'cloud_sync_password';
  static const _lastSyncedRemoteTsKey = 'cloud_sync_last_synced_remote_ts';
  static const _downloadStateKey = 'manga_download_service_state_v2';
  static const _downloadsRootPathKey = 'manga_download_root_path_v1';

  static const _settingsFileName = 'settings.json';
  static const _readingFileName = 'reading.json';
  static const _legacyReadingFileName = 'reading.sqlite';
  static const _searchHistoryFileName = 'search_history.jsonl';
  static const _manifestFileName = 'manifest.json';
  static const _sourceDirName = 'source';
  static const _sourceFileName = 'jm.js';

  static const Set<String> _alwaysSkippedSettings = {
    'cookie_store_v1',
    _downloadStateKey,
    _downloadsRootPathKey,
  };
  static const Set<String> _windowsOnlySettings = {
    hazukiUseSystemTitleBarPreferenceKey,
  };
  static const Set<String> _androidOnlySettings = {'appearance_display_mode'};

  bool _autoSyncRunning = false;

  Future<CloudSyncConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return CloudSyncConfig(
      enabled: prefs.getBool(_enabledKey) ?? false,
      url: prefs.getString(_urlKey) ?? '',
      username: prefs.getString(_usernameKey) ?? '',
      password: prefs.getString(_passwordKey) ?? '',
    );
  }

  Future<void> saveConfig(CloudSyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, config.enabled);
    await prefs.setString(_urlKey, config.url.trim());
    await prefs.setString(_usernameKey, config.username.trim());
    await prefs.setString(_passwordKey, config.password);
  }

  Future<void> autoSyncOnce() async {
    if (_autoSyncRunning) {
      return;
    }
    _autoSyncRunning = true;
    try {
      final config = await loadConfig();
      if (!config.enabled || !config.isComplete) {
        return;
      }

      final dio = _buildDio(config);
      final rootUrl = _rootUrl(config.url);
      final backupDirUrl = '$rootUrl/backup';
      final prefs = await SharedPreferences.getInstance();

      final remoteManifestText = await _tryGetString(
        dio,
        '$backupDirUrl/$_manifestFileName',
      );

      if (remoteManifestText != null) {
        int remoteUpdatedAtMs = 0;
        try {
          final decoded = jsonDecode(remoteManifestText);
          if (decoded is Map) {
            remoteUpdatedAtMs = (decoded['updatedAtMs'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}

        final lastSyncedRemoteTs = prefs.getInt(_lastSyncedRemoteTsKey) ?? 0;
        if (remoteUpdatedAtMs > lastSyncedRemoteTs) {
          await _mergeRemoteIntoLocal(dio, backupDirUrl);
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await uploadBackup(configOverride: config);
      await prefs.setInt(_lastSyncedRemoteTsKey, nowMs);
    } catch (_) {
      // Background best-effort sync should never interrupt app startup.
    } finally {
      _autoSyncRunning = false;
    }
  }

  Future<CloudSyncConnectionStatus> testConnection({
    CloudSyncConfig? configOverride,
  }) async {
    final config = configOverride ?? await loadConfig();
    if (!config.isComplete) {
      return CloudSyncConnectionStatus(
        ok: false,
        message: 'cloud_sync_config_incomplete',
        checkedAt: DateTime.now(),
      );
    }
    final dio = _buildDio(config);
    final rootUrl = _rootUrl(config.url);
    try {
      await _ensureDir(dio, rootUrl);
      final probeUrl = '$rootUrl/.connectivity_probe';
      await _putString(
        dio,
        probeUrl,
        jsonEncode({'time': DateTime.now().toIso8601String()}),
      );
      await _deleteIfExists(dio, probeUrl);
      return CloudSyncConnectionStatus(
        ok: true,
        message: 'cloud_sync_connected',
        checkedAt: DateTime.now(),
      );
    } catch (e) {
      return CloudSyncConnectionStatus(
        ok: false,
        message: 'cloud_sync_connection_failed:$e',
        checkedAt: DateTime.now(),
      );
    }
  }

  Future<void> uploadBackup({CloudSyncConfig? configOverride}) async {
    final config = configOverride ?? await loadConfig();
    if (!config.isComplete) {
      throw Exception('cloud_sync_config_incomplete');
    }

    final dio = _buildDio(config);
    final rootUrl = _rootUrl(config.url);
    await _ensureDir(dio, rootUrl);

    final backupDirUrl = '$rootUrl/backup';
    await _ensureDir(dio, backupDirUrl);
    final sourceDirUrl = '$backupDirUrl/$_sourceDirName';
    await _ensureDir(dio, sourceDirUrl);

    final snapshot = await _buildLocalSnapshotFiles();
    await _putString(
      dio,
      '$backupDirUrl/$_settingsFileName',
      snapshot.settings,
    );
    await _putString(dio, '$backupDirUrl/$_readingFileName', snapshot.reading);
    await _putString(
      dio,
      '$backupDirUrl/$_searchHistoryFileName',
      snapshot.searchHistoryJsonl,
    );

    if (snapshot.jmSource != null && snapshot.jmSource!.trim().isNotEmpty) {
      await _putString(
        dio,
        '$sourceDirUrl/$_sourceFileName',
        snapshot.jmSource!,
      );
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final manifest = {
      'version': 2,
      'updatedAtMs': nowMs,
      'historyCount': snapshot.historyCount,
      'progressCount': snapshot.progressCount,
      'searchCount': snapshot.searchCount,
      'sourcePlatform': _currentPlatformName,
      'hasSourceFile': snapshot.jmSource?.trim().isNotEmpty == true,
    };
    await _putString(
      dio,
      '$backupDirUrl/$_manifestFileName',
      jsonEncode(manifest),
    );
  }

  Future<CloudSyncRestoreResult> restoreLatestBackup({
    CloudSyncConfig? configOverride,
  }) async {
    final config = configOverride ?? await loadConfig();
    if (!config.isComplete) {
      throw Exception('cloud_sync_config_incomplete');
    }

    final dio = _buildDio(config);
    final rootUrl = _rootUrl(config.url);
    final backupDirUrl = '$rootUrl/backup';
    final manifest = await _loadManifest(dio, backupDirUrl);
    final settingsText = await _getString(
      dio,
      '$backupDirUrl/$_settingsFileName',
    );
    final readingText = await _loadReadingSnapshotText(dio, backupDirUrl);
    final searchHistoryText = await _getString(
      dio,
      '$backupDirUrl/$_searchHistoryFileName',
    );
    final sourceText = await _tryGetString(
      dio,
      '$backupDirUrl/$_sourceDirName/$_sourceFileName',
    );

    final settingsResult = await _applySettingsJson(settingsText);
    await _applyReadingSnapshot(readingText);
    await _applySearchHistoryJsonl(searchHistoryText);

    var restoredSourceFile = false;
    final manifestHasSource = manifest['hasSourceFile'] == true;
    if (sourceText != null && sourceText.trim().isNotEmpty) {
      await HazukiSourceService.instance.writeLocalJmSource(sourceText);
      restoredSourceFile = true;
    } else if (manifestHasSource) {
      throw Exception('cloud_sync_source_missing');
    }

    return CloudSyncRestoreResult(
      restoredSettings: true,
      restoredReading: true,
      restoredSearchHistory: true,
      restoredSourceFile: restoredSourceFile,
      appliedPlatformFilteredKeys: settingsResult.appliedPlatformFilteredKeys,
      skippedKeys: settingsResult.skippedKeys,
    );
  }

  Dio _buildDio(CloudSyncConfig config) {
    final auth = base64Encode(
      utf8.encode('${config.username.trim()}:${config.password}'),
    );
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 40),
        sendTimeout: const Duration(seconds: 40),
        validateStatus: (status) => true,
        headers: {'authorization': 'Basic $auth'},
      ),
    );
  }

  String _rootUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return '$normalized/HazukiSync';
  }

  String get _currentPlatformName {
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    return 'unknown';
  }

  Future<void> _ensureDir(Dio dio, String url) async {
    final response = await dio.request<dynamic>(
      url,
      options: Options(method: 'MKCOL'),
    );
    final code = response.statusCode ?? 0;
    if (code == 201 || code == 301 || code == 302 || code == 405) {
      return;
    }
    if (code >= 200 && code < 300) {
      return;
    }
    throw Exception('cloud_sync_directory_create_failed:$code');
  }

  Future<void> _putString(Dio dio, String url, String content) async {
    final response = await dio.put<dynamic>(
      url,
      data: utf8.encode(content),
      options: Options(headers: {'content-type': 'application/octet-stream'}),
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('cloud_sync_upload_failed:$code');
    }
  }

  Future<void> _deleteIfExists(Dio dio, String url) async {
    final response = await dio.delete<dynamic>(url);
    final code = response.statusCode ?? 0;
    if (code == 404 || code == 405) {
      return;
    }
    if (code >= 200 && code < 300) {
      return;
    }
    throw Exception('cloud_sync_delete_failed:$code');
  }

  Future<String> _getString(Dio dio, String url) async {
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('cloud_sync_download_failed:$code');
    }
    final bytes = response.data ?? const <int>[];
    return utf8.decode(bytes);
  }

  Future<String?> _tryGetString(Dio dio, String url) async {
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final code = response.statusCode ?? 0;
    if (code == 404) {
      return null;
    }
    if (code < 200 || code >= 300) {
      throw Exception('cloud_sync_download_failed:$code');
    }
    final bytes = response.data ?? const <int>[];
    return utf8.decode(bytes);
  }

  Future<Map<String, dynamic>> _loadManifest(
    Dio dio,
    String backupDirUrl,
  ) async {
    final manifestText = await _tryGetString(
      dio,
      '$backupDirUrl/$_manifestFileName',
    );
    if (manifestText == null || manifestText.trim().isEmpty) {
      return const {'version': 1};
    }
    try {
      final decoded = jsonDecode(manifestText);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const {'version': 1};
  }

  Future<String> _loadReadingSnapshotText(Dio dio, String backupDirUrl) async {
    final current = await _tryGetString(dio, '$backupDirUrl/$_readingFileName');
    if (current != null) {
      return current;
    }
    final legacy = await _tryGetString(
      dio,
      '$backupDirUrl/$_legacyReadingFileName',
    );
    if (legacy != null) {
      return legacy;
    }
    throw Exception('cloud_sync_reading_missing');
  }

  Future<void> _mergeRemoteIntoLocal(Dio dio, String backupDirUrl) async {
    final prefs = await SharedPreferences.getInstance();

    final readingText = await _tryGetString(
      dio,
      '$backupDirUrl/$_readingFileName',
    );
    if (readingText != null) {
      Map<String, dynamic>? readingMap;
      try {
        final decoded = jsonDecode(readingText);
        if (decoded is Map) {
          readingMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      if (readingMap != null) {
        // 合并阅读历史
        final remoteHistoryRaw = readingMap['history'];
        List<Map<String, dynamic>> remoteHistory = const [];
        if (remoteHistoryRaw is List) {
          remoteHistory = remoteHistoryRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        List<Map<String, dynamic>> localHistory = const [];
        final localHistoryRaw = prefs.getString('hazuki_read_history');
        if (localHistoryRaw != null) {
          try {
            final decoded = jsonDecode(localHistoryRaw);
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
          // 历史记录条目的 ID 字段名为 'id'（非 'comicId'）
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

        // 合并阅读进度
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
        for (final key in prefs.getKeys()) {
          if (!key.startsWith('reading_progress_')) continue;
          final comicId = key.substring('reading_progress_'.length);
          final raw = prefs.getString(key);
          if (raw == null) continue;
          try {
            final decoded = jsonDecode(raw);
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
            continue; // 本地独有，不动
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

    // 合并搜索历史
    final searchText = await _tryGetString(
      dio,
      '$backupDirUrl/$_searchHistoryFileName',
    );
    if (searchText != null) {
      final remoteKeywords = <String>[];
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

      final localKeywords = prefs.getStringList('search_history') ?? [];
      final merged = <String>[];
      final seen = <String>{};
      for (final k in [...remoteKeywords, ...localKeywords]) {
        if (seen.add(k)) merged.add(k);
      }
      await prefs.setStringList('search_history', merged);
    }

    // 应用用户设置并合并本地收藏
    final settingsText = await _tryGetString(
      dio,
      '$backupDirUrl/$_settingsFileName',
    );
    if (settingsText != null) {
      try {
        // 先将远端设置（外观、阅读器偏好等）写入本地，平台过滤逻辑与手动恢复一致。
        await _applySettingsJson(settingsText);
      } catch (_) {}
      try {
        final settingsDecoded = jsonDecode(settingsText);
        if (settingsDecoded is Map) {
          final data = settingsDecoded['data'];
          if (data is Map) {
            // 收藏需要增量合并而非直接覆盖，在设置写入后再处理。
            await _mergeLocalFavorites(prefs, data);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _mergeLocalFavorites(
    SharedPreferences prefs,
    Map<dynamic, dynamic> remoteData,
  ) async {
    // 合并收藏夹：按 id 去重，同 id 保留本地名称，远端独有夹子追加
    List<Map<String, dynamic>> localFolders = const [];
    final localFoldersRaw = prefs.getString('local_favorite_folders_v1');
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

    final localFolderIds = {
      for (final f in localFolders) f['id'].toString(): f,
    };
    final mergedFolders = List<Map<String, dynamic>>.from(localFolders);
    for (final folder in remoteFolders) {
      final id = folder['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (!localFolderIds.containsKey(id)) {
        mergedFolders.add(folder);
      }
      // 同 id 保留本地版本（夹名可能被用户改过）
    }

    // 合并收藏条目：按 comicId 去重，保留 savedAtMs 较大的，folderIds 取并集
    List<Map<String, dynamic>> localEntries = const [];
    final localEntriesRaw = prefs.getString('local_favorite_entries_v1');
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

    final mergedEntries = <String, Map<String, dynamic>>{};
    for (final entry in localEntries) {
      final comicId = (entry['comicId'] ?? '').toString().trim();
      if (comicId.isEmpty) continue;
      mergedEntries[comicId] = entry;
    }
    for (final entry in remoteEntries) {
      final comicId = (entry['comicId'] ?? '').toString().trim();
      if (comicId.isEmpty) continue;
      final existing = mergedEntries[comicId];
      if (existing == null) {
        mergedEntries[comicId] = entry;
      } else {
        final localTs = (existing['savedAtMs'] as num?)?.toInt() ?? 0;
        final remoteTs = (entry['savedAtMs'] as num?)?.toInt() ?? 0;
        final winner = remoteTs > localTs ? entry : existing;
        // folderIds 取并集
        final localIds = _toStringSet(existing['folderIds']);
        final remoteIds = _toStringSet(entry['folderIds']);
        final mergedIds = {...localIds, ...remoteIds}.toList();
        mergedEntries[comicId] = {...winner, 'folderIds': mergedIds};
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
  }

  Set<String> _toStringSet(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toSet();
    }
    return const {};
  }

  Future<_LocalSnapshot> _buildLocalSnapshotFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsMap = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_alwaysSkippedSettings.contains(key)) {
        continue;
      }
      final value = prefs.get(key);
      // 对 source_data_* 键进行净化：账号凭证属于敏感信息，不应上传至云端。
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

    return _LocalSnapshot(
      settings: settingsJson,
      reading: readingJson,
      searchHistoryJsonl: lines,
      historyCount: history.length,
      progressCount: progress.length,
      searchCount: search.length,
      jmSource: await HazukiSourceService.instance.readLocalJmSourceIfExists(),
    );
  }

  Future<_ApplySettingsResult> _applySettingsJson(String content) async {
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
    return _ApplySettingsResult(
      appliedPlatformFilteredKeys: appliedPlatformFilteredKeys,
      skippedKeys: skippedKeys,
    );
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
    if (_alwaysSkippedSettings.contains(normalizedKey)) {
      skippedKeys.add(normalizedKey);
      return null;
    }
    if (_windowsOnlySettings.contains(normalizedKey)) {
      if (!Platform.isWindows) {
        skippedKeys.add(normalizedKey);
        return null;
      }
      appliedPlatformFilteredKeys.add(normalizedKey);
    }
    if (_androidOnlySettings.contains(normalizedKey)) {
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
      // 账号凭证属于敏感会话数据，不应从备份恢复，
      // 先无条件移除备份中携带的 account 字段。
      sanitized.remove('account');
      // 若本地设备已有登录账号，则将其写回，保持本地状态不变。
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

  Future<void> _applyReadingSnapshot(String content) async {
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

  Future<void> _applySearchHistoryJsonl(String content) async {
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
      final asStrings = value.map((e) => e.toString()).toList();
      await prefs.setStringList(key, asStrings);
      return;
    }
    await prefs.setString(key, value.toString());
  }

  /// 从 source_data_* 的 JSON 字符串中剔除 account 字段。
  /// 账号凭证属于敏感会话数据，不应出现在云端备份中。
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
      // 解析失败时原样保留，避免破坏其他数据
      return raw;
    }
  }
}

class _LocalSnapshot {
  const _LocalSnapshot({
    required this.settings,
    required this.reading,
    required this.searchHistoryJsonl,
    required this.historyCount,
    required this.progressCount,
    required this.searchCount,
    required this.jmSource,
  });

  final String settings;
  final String reading;
  final String searchHistoryJsonl;
  final int historyCount;
  final int progressCount;
  final int searchCount;
  final String? jmSource;
}

class _ApplySettingsResult {
  const _ApplySettingsResult({
    required this.appliedPlatformFilteredKeys,
    required this.skippedKeys,
  });

  final List<String> appliedPlatformFilteredKeys;
  final List<String> skippedKeys;
}
