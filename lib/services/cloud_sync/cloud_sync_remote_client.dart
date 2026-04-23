import 'dart:convert';

import 'package:dio/dio.dart';

import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';

class CloudSyncRemoteClient {
  CloudSyncRemoteClient(
    CloudSyncConfig config, {
    required CloudSyncConfigStore configStore,
  }) : rootUrl = configStore.rootUrl(config.url),
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 25),
           receiveTimeout: const Duration(seconds: 40),
           sendTimeout: const Duration(seconds: 40),
           validateStatus: (status) => true,
           headers: {
             'authorization':
                 'Basic ${base64Encode(utf8.encode('${config.username.trim()}:${config.password}'))}',
           },
         ),
       );

  final Dio _dio;
  final String rootUrl;

  String get backupDirUrl => '$rootUrl/backup';
  String get sourceDirUrl =>
      '$backupDirUrl/${CloudSyncConfigStore.sourceDirName}';

  Future<void> ensureRootDir() => _ensureDir(rootUrl);

  Future<void> ensureBackupDirs() async {
    await _ensureDir(backupDirUrl);
    await _ensureDir(sourceDirUrl);
  }

  Future<CloudSyncConnectionStatus> testConnection() async {
    try {
      await ensureRootDir();
      final probeUrl = '$rootUrl/.connectivity_probe';
      await _putString(
        probeUrl,
        jsonEncode({'time': DateTime.now().toIso8601String()}),
      );
      await _deleteIfExists(probeUrl);
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

  Future<void> putBackupFile(String fileName, String content) {
    return _putString('$backupDirUrl/$fileName', content);
  }

  Future<void> putSourceFile(String fileName, String content) {
    return _putString('$sourceDirUrl/$fileName', content);
  }

  Future<String> getBackupFile(String fileName) {
    return _getString('$backupDirUrl/$fileName');
  }

  Future<String?> tryGetBackupFile(String fileName) {
    return _tryGetString('$backupDirUrl/$fileName');
  }

  Future<String?> tryGetSourceFile(String fileName) {
    return _tryGetString('$sourceDirUrl/$fileName');
  }

  Future<Map<String, dynamic>> loadManifest() async {
    final manifestText = await tryGetBackupFile(
      CloudSyncConfigStore.manifestFileName,
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

  Future<String> loadReadingSnapshotText() async {
    final current = await tryGetBackupFile(
      CloudSyncConfigStore.readingFileName,
    );
    if (current != null) {
      return current;
    }
    final legacy = await tryGetBackupFile(
      CloudSyncConfigStore.legacyReadingFileName,
    );
    if (legacy != null) {
      return legacy;
    }
    throw Exception('cloud_sync_reading_missing');
  }

  Future<void> _ensureDir(String url) async {
    final response = await _dio.request<dynamic>(
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

  Future<void> _putString(String url, String content) async {
    final response = await _dio.put<dynamic>(
      url,
      data: utf8.encode(content),
      options: Options(headers: {'content-type': 'application/octet-stream'}),
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('cloud_sync_upload_failed:$code');
    }
  }

  Future<void> _deleteIfExists(String url) async {
    final response = await _dio.delete<dynamic>(url);
    final code = response.statusCode ?? 0;
    if (code == 404 || code == 405) {
      return;
    }
    if (code >= 200 && code < 300) {
      return;
    }
    throw Exception('cloud_sync_delete_failed:$code');
  }

  Future<String> _getString(String url) async {
    final response = await _dio.get<List<int>>(
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

  Future<String?> _tryGetString(String url) async {
    final response = await _dio.get<List<int>>(
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
}
