import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_participant_set.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_snapshot_codec.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('webdav settings snapshot includes download group metadata', () async {
    final database = HazukiDatabase.memory();
    final source = HazukiSourceService();
    final groups = DownloadGroupsService(database: database);
    try {
      await groups.initialize(const ['comic-a']);
      final group = await groups.createGroup('Synced group');
      await groups.moveComicToGroup('comic-a', group.id);

      final participants = createCloudSyncParticipantSet(
        source: source,
        readHistory: ReadHistoryService(database: database),
        readingProgress: ReadingProgressService(database: database),
        localFavorites: LocalFavoritesService(database: database),
        downloadGroups: groups,
        searchHistory: SearchHistoryService(database: database),
      );
      final snapshot = await CloudSyncSnapshotCodec(
        participants: participants,
      ).buildLocalSnapshotFiles();
      final settings = jsonDecode(snapshot.settings) as Map<String, dynamic>;
      final data = settings['data'] as Map<String, dynamic>;
      final groupSnapshot =
          jsonDecode(data[CloudSyncConfigStore.downloadGroupsKey] as String)
              as Map<String, dynamic>;

      expect(
        (groupSnapshot['groups'] as List).where(
          (item) => (item as Map)['name'] == 'Synced group',
        ),
        isNotEmpty,
      );
      expect(
        (groupSnapshot['memberships'] as List).where(
          (item) =>
              (item as Map)['groupId'] == group.id &&
              item['comicStorageKey'] == 'comic-a',
        ),
        isNotEmpty,
      );
    } finally {
      groups.dispose();
      source.dispose();
      await database.close();
    }
  });
}
