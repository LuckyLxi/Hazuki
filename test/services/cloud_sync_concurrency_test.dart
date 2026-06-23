import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_remote_client.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_participant_set.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SharedRemote {
  final Map<String, String> files = <String, String>{};
  String? lockToken;
  bool failNextSettingsUpload = false;
  Duration uploadDelay = const Duration(milliseconds: 10);
  int lockRenewalCount = 0;
}

class _FakeLockedRemoteClient extends CloudSyncRemoteClient {
  _FakeLockedRemoteClient(this.remote)
    : super(_config, configStore: CloudSyncConfigStore());

  static const _config = CloudSyncConfig(
    enabled: true,
    url: 'https://example.test',
    username: 'user',
    password: 'pass',
  );

  final _SharedRemote remote;

  @override
  Future<void> ensureRootDir() async {}

  @override
  Future<void> ensureBackupDirs() async {}

  @override
  Future<bool> tryAcquireSyncLock(String token) async {
    if (remote.lockToken != null) {
      return false;
    }
    remote.lockToken = token;
    return true;
  }

  @override
  Future<String?> readSyncLock() async => remote.lockToken;

  @override
  Future<bool> renewSyncLock(String token) async {
    final current = remote.lockToken;
    if (current == null || _lockId(current) != _lockId(token)) {
      return false;
    }
    remote.lockRenewalCount++;
    remote.lockToken = jsonEncode({
      'id': _lockId(token),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  }

  @override
  Future<void> releaseSyncLock(String token) async {
    if (_lockId(remote.lockToken) == _lockId(token)) {
      remote.lockToken = null;
    }
  }

  @override
  Future<void> deleteStaleSyncLock(String observedToken) async {
    if (remote.lockToken == observedToken) {
      remote.lockToken = null;
    }
  }

  @override
  Future<String?> tryGetBackupFile(String fileName) async {
    return remote.files[fileName];
  }

  @override
  Future<void> putBackupFile(String fileName, String content) async {
    await Future<void>.delayed(remote.uploadDelay);
    if (fileName == CloudSyncConfigStore.settingsFileName &&
        remote.failNextSettingsUpload) {
      remote.failNextSettingsUpload = false;
      throw Exception('simulated_upload_failure');
    }
    remote.files[fileName] = content;
  }

  @override
  Future<void> putSourceFile(String fileName, String content) async {}

  String? _lockId(String? token) {
    if (token == null) return null;
    final decoded = jsonDecode(token);
    return decoded is Map ? decoded['id']?.toString() : null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('concurrent uploads merge both devices under the remote lock', () async {
    final remote = _SharedRemote();
    final deviceA = await _createDevice(remote, 'A');
    final deviceB = await _createDevice(remote, 'B');
    addTearDown(deviceA.dispose);
    addTearDown(deviceB.dispose);

    await Future.wait([
      deviceA.service.uploadBackup(
        configOverride: _FakeLockedRemoteClient._config,
      ),
      deviceB.service.uploadBackup(
        configOverride: _FakeLockedRemoteClient._config,
      ),
    ]);

    final settings =
        jsonDecode(remote.files[CloudSyncConfigStore.settingsFileName]!)
            as Map<String, dynamic>;
    final data = settings['data'] as Map<String, dynamic>;
    final entries =
        jsonDecode(data[CloudSyncConfigStore.localFavoriteEntriesKey] as String)
            as List<dynamic>;

    expect(entries.map((entry) => (entry as Map)['comicId']).toSet(), {
      'comic-A',
      'comic-B',
    });
    expect(remote.lockToken, isNull);
  });

  test('releases the remote lock when an upload fails', () async {
    final remote = _SharedRemote()..failNextSettingsUpload = true;
    final device = await _createDevice(remote, 'A');
    addTearDown(device.dispose);

    await expectLater(
      device.service.uploadBackup(
        configOverride: _FakeLockedRemoteClient._config,
      ),
      throwsException,
    );
    expect(remote.lockToken, isNull);

    await device.service.uploadBackup(
      configOverride: _FakeLockedRemoteClient._config,
    );
    expect(remote.files[CloudSyncConfigStore.manifestFileName], isNotNull);
    expect(remote.lockToken, isNull);
  });

  test('applies newer remote user settings before uploading', () async {
    final remote = _SharedRemote()
      ..files[CloudSyncConfigStore.manifestFileName] = jsonEncode({
        'version': 2,
        'updatedAtMs': 200,
      })
      ..files[CloudSyncConfigStore.settingsFileName] = jsonEncode({
        'version': 2,
        'data': {
          'test_user_setting': 'remote',
          hazukiFirstUseDatePreferenceKey: '2024-01-02T00:00:00.000Z',
          CloudSyncConfigStore.passwordKey: 'remote-password',
        },
      });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('test_user_setting', 'local');
    await prefs.setString(
      hazukiFirstUseDatePreferenceKey,
      '2026-01-02T00:00:00.000Z',
    );
    await prefs.setString(CloudSyncConfigStore.passwordKey, 'local-password');
    await prefs.setString('removed_user_setting', 'stale');
    await CloudSyncConfigStore().saveLastSyncedRemoteTs(
      100,
      _FakeLockedRemoteClient._config,
    );
    final device = await _createDevice(remote, 'A');
    addTearDown(device.dispose);

    await device.service.uploadBackup(
      configOverride: _FakeLockedRemoteClient._config,
      uploadAtMs: 300,
    );

    expect(prefs.getString('test_user_setting'), 'remote');
    expect(
      prefs.getString(hazukiFirstUseDatePreferenceKey),
      '2024-01-02T00:00:00.000Z',
    );
    expect(prefs.getString(CloudSyncConfigStore.passwordKey), 'local-password');
    expect(prefs.containsKey('removed_user_setting'), isFalse);
    final uploaded =
        jsonDecode(remote.files[CloudSyncConfigStore.settingsFileName]!)
            as Map<String, dynamic>;
    final uploadedData = uploaded['data'] as Map<String, dynamic>;
    expect(uploadedData['test_user_setting'], 'remote');
    expect(
      uploadedData[hazukiFirstUseDatePreferenceKey],
      '2024-01-02T00:00:00.000Z',
    );
    expect(uploadedData, isNot(contains(CloudSyncConfigStore.passwordKey)));
    expect(
      uploadedData,
      isNot(contains(CloudSyncConfigStore.lastSyncedRemoteTsKey)),
    );
    expect(uploadedData, isNot(contains('removed_user_setting')));
  });

  test(
    'keeps local user settings when remote is already synchronized',
    () async {
      final remote = _SharedRemote()
        ..files[CloudSyncConfigStore.manifestFileName] = jsonEncode({
          'version': 2,
          'updatedAtMs': 200,
        })
        ..files[CloudSyncConfigStore.settingsFileName] = jsonEncode({
          'version': 2,
          'data': {'test_user_setting': 'remote'},
        });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_user_setting', 'local');
      await CloudSyncConfigStore().saveLastSyncedRemoteTs(
        200,
        _FakeLockedRemoteClient._config,
      );
      final device = await _createDevice(remote, 'A');
      addTearDown(device.dispose);

      await device.service.uploadBackup(
        configOverride: _FakeLockedRemoteClient._config,
        uploadAtMs: 300,
      );

      expect(prefs.getString('test_user_setting'), 'local');
      final uploaded =
          jsonDecode(remote.files[CloudSyncConfigStore.settingsFileName]!)
              as Map<String, dynamic>;
      expect((uploaded['data'] as Map)['test_user_setting'], 'local');
    },
  );

  test('does not reuse the settings cursor for another remote', () async {
    const otherConfig = CloudSyncConfig(
      enabled: true,
      url: 'https://other.example.test',
      username: 'other-user',
      password: 'pass',
    );
    final remote = _SharedRemote()
      ..files[CloudSyncConfigStore.manifestFileName] = jsonEncode({
        'version': 2,
        'updatedAtMs': 200,
      })
      ..files[CloudSyncConfigStore.settingsFileName] = jsonEncode({
        'version': 2,
        'data': {'test_user_setting': 'other-remote'},
      });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('test_user_setting', 'local');
    await CloudSyncConfigStore().saveLastSyncedRemoteTs(
      500,
      _FakeLockedRemoteClient._config,
    );
    final device = await _createDevice(remote, 'A');
    addTearDown(device.dispose);

    await device.service.uploadBackup(
      configOverride: otherConfig,
      uploadAtMs: 300,
    );

    expect(prefs.getString('test_user_setting'), 'other-remote');
  });

  test('recovers a stale remote lock before uploading', () async {
    final remote = _SharedRemote()
      ..lockToken = jsonEncode({
        'id': 'stale',
        'createdAtMs': DateTime.now()
            .subtract(const Duration(minutes: 3))
            .millisecondsSinceEpoch,
      });
    final device = await _createDevice(remote, 'A');
    addTearDown(device.dispose);

    await device.service.uploadBackup(
      configOverride: _FakeLockedRemoteClient._config,
    );

    expect(remote.files[CloudSyncConfigStore.manifestFileName], isNotNull);
    expect(remote.lockToken, isNull);
  });

  test('renews an active lock during a long upload', () async {
    final remote = _SharedRemote()
      ..uploadDelay = const Duration(milliseconds: 20);
    final deviceA = await _createDevice(
      remote,
      'A',
      syncLockStaleAfter: const Duration(milliseconds: 15),
      syncLockRenewInterval: const Duration(milliseconds: 5),
    );
    final deviceB = await _createDevice(
      remote,
      'B',
      syncLockStaleAfter: const Duration(milliseconds: 15),
      syncLockRenewInterval: const Duration(milliseconds: 5),
    );
    addTearDown(deviceA.dispose);
    addTearDown(deviceB.dispose);

    await Future.wait([
      deviceA.service.uploadBackup(
        configOverride: _FakeLockedRemoteClient._config,
      ),
      Future<void>.delayed(const Duration(milliseconds: 25)).then(
        (_) => deviceB.service.uploadBackup(
          configOverride: _FakeLockedRemoteClient._config,
        ),
      ),
    ]);

    final settings =
        jsonDecode(remote.files[CloudSyncConfigStore.settingsFileName]!)
            as Map<String, dynamic>;
    final data = settings['data'] as Map<String, dynamic>;
    final entries =
        jsonDecode(data[CloudSyncConfigStore.localFavoriteEntriesKey] as String)
            as List<dynamic>;
    expect(entries.map((entry) => (entry as Map)['comicId']).toSet(), {
      'comic-A',
      'comic-B',
    });
    expect(remote.lockRenewalCount, greaterThan(0));
    expect(remote.lockToken, isNull);
  });
}

Future<_TestDevice> _createDevice(
  _SharedRemote remote,
  String suffix, {
  Duration syncLockStaleAfter = const Duration(minutes: 2),
  Duration syncLockRenewInterval = const Duration(seconds: 30),
}) async {
  final database = HazukiDatabase.memory();
  final favorites = LocalFavoritesService(database: database);
  final groups = DownloadGroupsService(database: database);
  final source = HazukiSourceService();
  final readHistory = ReadHistoryService(database: database);
  final readingProgress = ReadingProgressService(database: database);
  final searchHistory = SearchHistoryService(database: database);
  final participants = createCloudSyncParticipantSet(
    source: HazukiSourceSyncAdapter(source),
    readHistory: readHistory,
    readingProgress: readingProgress,
    localFavorites: favorites,
    downloadGroups: groups,
    searchHistory: searchHistory,
  );
  final service = CloudSyncService(
    localFavorites: favorites,
    commentFilter: CommentFilterService(),
    downloadGroups: groups,
    participants: participants,
    remoteClientFactory: (_, _) => _FakeLockedRemoteClient(remote),
    syncLockStaleAfter: syncLockStaleAfter,
    syncLockRenewInterval: syncLockRenewInterval,
  );

  await favorites.addFavoriteFolder('Folder $suffix', sourceKey: 'jm');
  final folder = (await favorites.loadFavoriteFolders(
    sourceKey: 'jm',
  )).folders.single;
  await favorites.toggleFavorite(
    details: ComicDetailsData(
      id: 'comic-$suffix',
      sourceKey: 'jm',
      title: 'Comic $suffix',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: const {},
      tags: const {},
      recommend: const [],
      isFavorite: false,
      subId: '',
    ),
    isAdding: true,
    folderId: folder.id,
  );
  return _TestDevice(
    service: service,
    database: database,
    groups: groups,
    source: source,
  );
}

class _TestDevice {
  const _TestDevice({
    required this.service,
    required this.database,
    required this.groups,
    required this.source,
  });

  final CloudSyncService service;
  final HazukiDatabase database;
  final DownloadGroupsService groups;
  final HazukiSourceService source;

  Future<void> dispose() async {
    groups.dispose();
    source.dispose();
    await database.close();
  }
}
