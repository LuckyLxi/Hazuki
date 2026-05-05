import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_models.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_remote_client.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_restore_applier.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_snapshot_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCloudSyncRemoteClient extends CloudSyncRemoteClient {
  _FakeCloudSyncRemoteClient(this.files)
    : super(
        const CloudSyncConfig(
          enabled: true,
          url: 'https://example.test',
          username: 'user',
          password: 'pass',
        ),
        configStore: CloudSyncConfigStore(),
      );

  final Map<String, String> files;

  @override
  Future<String?> tryGetBackupFile(String fileName) async => files[fileName];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncRestoreApplier source-scoped reading data', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
    });

    test(
      'restores progress with sourceKey in the preference key and payload',
      () async {
        await CloudSyncRestoreApplier().applyReadingSnapshot(
          jsonEncode({
            'history': [
              {
                'id': '123',
                'sourceKey': 'jm',
                'title': 'Title',
                'timestamp': 1,
              },
            ],
            'progress': [
              {
                'comicId': '123',
                'sourceKey': 'jm',
                'epId': 'ep1',
                'title': 'Chapter',
                'index': 0,
                'timestamp': 2,
              },
            ],
          }),
        );

        final prefs = await SharedPreferences.getInstance();
        final progressRaw = prefs.getString('reading_progress_jm::123');
        final historyRaw = prefs.getString('hazuki_read_history');

        expect(progressRaw, isNotNull);
        expect(jsonDecode(progressRaw!)['sourceKey'], 'jm');
        final history = jsonDecode(historyRaw!) as List<dynamic>;
        expect((history.single as Map<String, dynamic>)['sourceKey'], 'jm');
      },
    );

    test('keeps entry tombstones scoped to the deleted source', () async {
      final deletedAtMs = DateTime.now().millisecondsSinceEpoch;
      final olderSavedAtMs = deletedAtMs - 1000;
      SharedPreferences.setMockInitialValues({
        'local_favorite_folders_v1': jsonEncode([
          {'id': 'jm-folder', 'name': 'JM', 'sourceKey': 'jm'},
        ]),
        'local_favorite_entries_v1': jsonEncode([
          {
            'comicId': '123',
            'sourceKey': 'jm',
            'title': 'JM title',
            'folderIds': ['jm-folder'],
            'folderSavedAtMs': {'jm-folder': olderSavedAtMs},
          },
        ]),
        'local_favorite_entry_tombstones_v1': jsonEncode([
          {'comicId': '123', 'sourceKey': 'jm', 'deletedAtMs': deletedAtMs},
        ]),
      });

      final remoteSettings = jsonEncode({
        'version': 2,
        'data': {
          'local_favorite_folders_v1': jsonEncode([
            {'id': 'other-folder', 'name': 'Other', 'sourceKey': 'other'},
          ]),
          'local_favorite_entries_v1': jsonEncode([
            {
              'comicId': '123',
              'sourceKey': 'other',
              'title': 'Other title',
              'folderIds': ['other-folder'],
              'folderSavedAtMs': {'other-folder': 1500},
            },
          ]),
        },
      });

      await CloudSyncSnapshotCodec(
        configStore: CloudSyncConfigStore(),
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: remoteSettings,
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      final entries =
          jsonDecode(prefs.getString('local_favorite_entries_v1')!)
              as List<dynamic>;
      expect(entries, hasLength(1));
      expect((entries.single as Map<String, dynamic>)['sourceKey'], 'other');

      final tombstones =
          jsonDecode(prefs.getString('local_favorite_entry_tombstones_v1')!)
              as List<dynamic>;
      final tombstone = tombstones.single as Map<String, dynamic>;
      expect(tombstone['comicId'], '123');
      expect(tombstone['sourceKey'], 'jm');
    });

    test('merges comment filter keywords from remote settings', () async {
      SharedPreferences.setMockInitialValues({
        hazukiCommentFilterKeywordsKey: ['local'],
      });

      final remoteSettings = jsonEncode({
        'version': 2,
        'data': {
          hazukiCommentFilterKeywordsKey: ['remote', 'local'],
        },
      });

      await CloudSyncSnapshotCodec(
        configStore: CloudSyncConfigStore(),
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: remoteSettings,
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), [
        'remote',
        'local',
      ]);
    });
  });
}
