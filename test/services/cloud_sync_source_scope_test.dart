import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/search/support/search_history_service.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_models.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_remote_client.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_restore_applier.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_snapshot_codec.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/test_service_locator.dart';

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
  setUp(() async {
    await ensureTestServiceLocator();
  });

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

        final progress = await sl<ReadingProgressService>().load(
          comicId: '123',
          sourceKey: 'jm',
        );
        final history = await sl<ReadHistoryService>().exportJsonList();

        expect(progress, isNotNull);
        expect(progress!['sourceKey'], 'jm');
        expect(history.single['sourceKey'], 'jm');
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

      final entries =
          jsonDecode(
                await sl<LocalFavoritesService>().exportEntriesJsonString(),
              )
              as List<dynamic>;
      expect(entries, hasLength(1));
      expect((entries.single as Map<String, dynamic>)['sourceKey'], 'other');

      final tombstones =
          jsonDecode(
                await sl<LocalFavoritesService>()
                    .exportEntryTombstonesJsonString(),
              )
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

    test('trims merged search history to the shared local limit', () async {
      SharedPreferences.setMockInitialValues({
        'search_history': List.generate(10, (index) => 'local-$index'),
      });

      final remoteSearchHistory = List.generate(
        hazukiSearchHistoryMaxCount + 5,
        (index) => jsonEncode({'keyword': 'remote-$index'}),
      ).join('\n');

      await CloudSyncSnapshotCodec(
        configStore: CloudSyncConfigStore(),
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.searchHistoryFileName: remoteSearchHistory,
        }),
      );

      final history = await sl<SearchHistoryService>().load();
      expect(history, hasLength(hazukiSearchHistoryMaxCount));
      expect(history.take(10), List.generate(10, (index) => 'local-$index'));
      expect(history[10], 'remote-0');
      expect(history.last, 'remote-${hazukiSearchHistoryMaxCount - 11}');
    });

    test('trims restored search history to the shared local limit', () async {
      final backupSearchHistory = List.generate(
        hazukiSearchHistoryMaxCount + 5,
        (index) => jsonEncode({'keyword': 'keyword-$index'}),
      ).join('\n');

      await CloudSyncRestoreApplier().applySearchHistoryJsonl(
        backupSearchHistory,
      );

      final history = await sl<SearchHistoryService>().load();
      expect(history, hasLength(hazukiSearchHistoryMaxCount));
      expect(history.first, 'keyword-0');
      expect(history.last, 'keyword-${hazukiSearchHistoryMaxCount - 1}');
    });

    test('trims backed up search history to the shared local limit', () async {
      SharedPreferences.setMockInitialValues({
        'search_history': List.generate(
          hazukiSearchHistoryMaxCount + 5,
          (index) => 'keyword-$index',
        ),
      });

      final snapshot = await CloudSyncSnapshotCodec(
        configStore: CloudSyncConfigStore(),
      ).buildLocalSnapshotFiles();
      final lines = snapshot.searchHistoryJsonl
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(snapshot.searchCount, hazukiSearchHistoryMaxCount);
      expect(lines, hasLength(hazukiSearchHistoryMaxCount));
      expect(
        jsonDecode(lines.last)['keyword'],
        'keyword-${hazukiSearchHistoryMaxCount - 1}',
      );
    });
  });
}
