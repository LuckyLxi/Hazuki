import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/hazuki_network.dart';
import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';

class CloudSyncRemoteClient {
  CloudSyncRemoteClient(
    CloudSyncConfig config, {
    required CloudSyncConfigStore configStore,
  }) : rootUrl = configStore.rootUrl(config.url),
       _client = HazukiNetworkClient(
         dio: createHazukiDio(
           baseOptions: BaseOptions(
             connectTimeout: const Duration(seconds: 25),
             receiveTimeout: const Duration(seconds: 40),
             sendTimeout: const Duration(seconds: 40),
             validateStatus: (status) => true,
             headers: {
               'authorization':
                   'Basic ${base64Encode(utf8.encode('${config.username.trim()}:${config.password}'))}',
             },
           ),
         ),
       );

  final HazukiNetworkClient _client;
  final String rootUrl;

  String get backupDirUrl => '$rootUrl/backup';
  Future<void> ensureRootDir() => _ensureDir(rootUrl);

  Future<void> ensureBackupDirs() async {
    await _ensureDir(backupDirUrl);
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

  Future<bool> tryAcquireSyncLock(String token) async {
    final response = await _client.request<dynamic>(
      '$backupDirUrl/${CloudSyncConfigStore.syncLockFileName}',
      method: 'PUT',
      data: utf8.encode(token),
      options: Options(
        headers: {
          'content-type': 'application/octet-stream',
          'if-none-match': '*',
        },
      ),
      retryPolicy: HazukiNetworkRetryPolicy.none,
    );
    final code = response.statusCode ?? 0;
    if (code == 412 || code == 423) {
      return false;
    }
    if (code >= 200 && code < 300) {
      return true;
    }
    throw Exception('cloud_sync_lock_failed:$code');
  }

  Future<String?> readSyncLock() {
    return _readSyncLockSnapshot().then((snapshot) => snapshot?.content);
  }

  Future<bool> renewSyncLock(String token) async {
    final snapshot = await _readSyncLockSnapshot();
    if (snapshot == null ||
        snapshot.etag == null ||
        !_sameSyncLockOwner(snapshot.content, token)) {
      return false;
    }
    final ownerId = _syncLockOwnerId(token);
    if (ownerId == null) {
      return false;
    }
    final renewedToken = jsonEncode({
      'id': ownerId,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    final response = await _client.request<dynamic>(
      '$backupDirUrl/${CloudSyncConfigStore.syncLockFileName}',
      method: 'PUT',
      data: utf8.encode(renewedToken),
      options: Options(
        headers: {
          'content-type': 'application/octet-stream',
          'if-match': snapshot.etag,
        },
      ),
      retryPolicy: HazukiNetworkRetryPolicy.none,
    );
    final code = response.statusCode ?? 0;
    if (code == 404 || code == 412 || code == 423) {
      return false;
    }
    if (code >= 200 && code < 300) {
      return true;
    }
    throw Exception('cloud_sync_lock_renew_failed:$code');
  }

  Future<void> releaseSyncLock(String token) async {
    final snapshot = await _readSyncLockSnapshot();
    if (snapshot == null ||
        snapshot.etag == null ||
        !_sameSyncLockOwner(snapshot.content, token)) {
      return;
    }
    await _deleteSyncLockIfMatch(snapshot.etag!);
  }

  Future<void> deleteStaleSyncLock(String observedToken) async {
    final snapshot = await _readSyncLockSnapshot();
    if (snapshot == null ||
        snapshot.etag == null ||
        snapshot.content != observedToken) {
      return;
    }
    await _deleteSyncLockIfMatch(snapshot.etag!);
  }

  Future<_SyncLockSnapshot?> _readSyncLockSnapshot() async {
    final response = await _client.get<List<int>>(
      '$backupDirUrl/${CloudSyncConfigStore.syncLockFileName}',
      options: Options(responseType: ResponseType.bytes),
      retryPolicy: HazukiNetworkRetryPolicy.none,
    );
    final code = response.statusCode ?? 0;
    if (code == 404) {
      return null;
    }
    if (code < 200 || code >= 300) {
      throw Exception('cloud_sync_download_failed:$code');
    }
    return _SyncLockSnapshot(
      content: utf8.decode(response.data ?? const <int>[]),
      etag: response.headers.value('etag'),
    );
  }

  Future<bool> _deleteSyncLockIfMatch(String etag) async {
    final response = await _client.request<dynamic>(
      '$backupDirUrl/${CloudSyncConfigStore.syncLockFileName}',
      method: 'DELETE',
      options: Options(headers: {'if-match': etag}),
      retryPolicy: HazukiNetworkRetryPolicy.none,
    );
    final code = response.statusCode ?? 0;
    if (code == 404 || code == 412 || code == 423) {
      return false;
    }
    if (code >= 200 && code < 300) {
      return true;
    }
    throw Exception('cloud_sync_delete_failed:$code');
  }

  bool _sameSyncLockOwner(String first, String second) {
    final firstId = _syncLockOwnerId(first);
    return firstId != null && firstId == _syncLockOwnerId(second);
  }

  String? _syncLockOwnerId(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final id = (decoded['id'] ?? '').toString().trim();
        return id.isEmpty ? null : id;
      }
    } catch (_) {}
    return null;
  }

  Future<String> getBackupFile(String fileName) {
    return _getString('$backupDirUrl/$fileName');
  }

  Future<String?> tryGetBackupFile(String fileName) {
    return _tryGetString('$backupDirUrl/$fileName');
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
    final response = await _client.request<dynamic>(
      url,
      method: 'MKCOL',
      retryPolicy: HazukiNetworkRetryPolicy.none,
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
    final response = await _client.request<dynamic>(
      url,
      method: 'PUT',
      data: utf8.encode(content),
      options: Options(headers: {'content-type': 'application/octet-stream'}),
      retryPolicy: HazukiNetworkRetryPolicy.none,
    );
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception('cloud_sync_upload_failed:$code');
    }
  }

  Future<void> _deleteIfExists(String url) async {
    final response = await _client.request<dynamic>(
      url,
      method: 'DELETE',
      retryPolicy: HazukiNetworkRetryPolicy.none,
    );
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
    final response = await _client.get<List<int>>(
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
    final response = await _client.get<List<int>>(
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

class _SyncLockSnapshot {
  const _SyncLockSnapshot({required this.content, required this.etag});

  final String content;
  final String? etag;
}
