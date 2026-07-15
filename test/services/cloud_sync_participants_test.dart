import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_comment_filter_participant.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_favorites_participant.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_participant.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_reading_participant.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_settings_participant.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reading participant preserves scope and newest timestamps', () async {
    SharedPreferences.setMockInitialValues(const {});
    final database = HazukiDatabase.memory();
    addTearDown(database.close);
    final history = ReadHistoryService(database: database);
    final progress = ReadingProgressService(database: database);
    final participant = CloudSyncReadingParticipant(
      readHistory: history,
      readingProgress: progress,
      activeSourceKey: () => 'jm',
    );

    await history.importJsonList([
      {'id': 'same', 'sourceKey': 'jm', 'title': 'local', 'timestamp': 20},
    ], replace: true);
    await progress.mergeJsonList([
      {'comicId': 'same', 'sourceKey': 'jm', 'epId': 'local', 'timestamp': 20},
    ]);
    final local = await participant.captureMergeSnapshot();

    await participant.mergeRemote(
      jsonEncode({
        'version': 1,
        'history': [
          {'id': 'same', 'title': 'remote-old', 'timestamp': 10},
          {'id': 'legacy', 'title': 'remote-new', 'timestamp': 30},
        ],
        'progress': [
          {'comicId': 'same', 'epId': 'remote-old', 'timestamp': 10},
          {'comicId': 'legacy', 'epId': 'remote-new', 'timestamp': 30},
        ],
      }),
      local,
    );

    final mergedHistory = await history.exportJsonList();
    expect(
      mergedHistory.firstWhere((entry) => entry['id'] == 'same')['title'],
      'local',
    );
    expect(
      mergedHistory.firstWhere((entry) => entry['id'] == 'legacy')['sourceKey'],
      'jm',
    );
    expect(
      (await progress.load(comicId: 'same', sourceKey: 'jm'))?['epId'],
      'local',
    );
    expect(
      (await progress.load(comicId: 'legacy', sourceKey: 'jm'))?['epId'],
      'remote-new',
    );
  });

  test(
    'reading participant keeps the v1 wire format and history cap',
    () async {
      SharedPreferences.setMockInitialValues(const {});
      final database = HazukiDatabase.memory();
      addTearDown(database.close);
      final history = ReadHistoryService(database: database);
      final participant = CloudSyncReadingParticipant(
        readHistory: history,
        readingProgress: ReadingProgressService(database: database),
        activeSourceKey: () => 'jm',
      );
      final local = await participant.captureMergeSnapshot();
      await participant.mergeRemote(
        jsonEncode({
          'history': [
            for (var index = 0; index < hazukiReadHistoryMaxCount + 5; index++)
              {'id': '$index', 'timestamp': index},
          ],
          'progress': const [],
        }),
        local,
      );

      final exported = await participant.exportSnapshot();
      final decoded = jsonDecode(exported.json) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect(exported.historyCount, hazukiReadHistoryMaxCount);
      expect(
        (decoded['history'] as List),
        hasLength(hazukiReadHistoryMaxCount),
      );
      expect(decoded, containsPair('progress', isA<List<dynamic>>()));
    },
  );

  test(
    'settings participant strips credentials and filters platforms',
    () async {
      SharedPreferences.setMockInitialValues({
        'source_data_jm': jsonEncode({
          'account': ['name', 'password'],
          'token': 'secret',
          'safe': 'value',
        }),
      });
      final database = HazukiDatabase.memory();
      addTearDown(database.close);
      final groups = DownloadGroupsService(database: database);
      addTearDown(groups.dispose);
      final participant = CloudSyncSettingsParticipant(
        localFavorites: LocalFavoritesSyncParticipant(
          LocalFavoritesService(database: database),
        ),
        downloadGroups: DownloadGroupsSyncParticipant(groups),
        commentFilter: const CommentFilterSyncParticipant(),
      );

      final exported = jsonDecode(await participant.exportSnapshot()) as Map;
      expect(exported['version'], 2);
      final exportedSource =
          jsonDecode((exported['data'] as Map)['source_data_jm'] as String)
              as Map;
      expect(exportedSource, isNot(contains('account')));
      expect(exportedSource, isNot(contains('token')));
      expect(exportedSource['safe'], 'value');

      final platformOnlyKey = Platform.isAndroid
          ? hazukiUseSystemTitleBarPreferenceKey
          : 'appearance_display_mode';
      final result = await participant.restoreSnapshot(
        jsonEncode({
          'version': 2,
          'data': {
            'source_data_jm': jsonEncode({
              'account': ['remote', 'password'],
              'token': 'remote-secret',
              'safe': 'remote-value',
            }),
            platformOnlyKey: 'platform-value',
          },
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      final restoredSource =
          jsonDecode(prefs.getString('source_data_jm')!) as Map;
      expect(restoredSource, isNot(contains('account')));
      expect(restoredSource, isNot(contains('token')));
      expect(restoredSource['safe'], 'remote-value');
      expect(result.skippedKeys, contains(platformOnlyKey));
      expect(prefs.containsKey(platformOnlyKey), isFalse);
    },
  );

  test(
    'settings participant syncs recommendation toggle but skips cache',
    () async {
      SharedPreferences.setMockInitialValues({
        hazukiDiscoverDailyRecommendationEnabledPreferenceKey: true,
        hazukiDiscoverDailyRecommendationCachePreferenceKey: 'global-cache',
        '${hazukiDiscoverDailyRecommendationCachePreferenceKey}_jm':
            'scoped-cache',
      });
      final database = HazukiDatabase.memory();
      addTearDown(database.close);
      final groups = DownloadGroupsService(database: database);
      addTearDown(groups.dispose);
      final participant = CloudSyncSettingsParticipant(
        localFavorites: LocalFavoritesSyncParticipant(
          LocalFavoritesService(database: database),
        ),
        downloadGroups: DownloadGroupsSyncParticipant(groups),
        commentFilter: const CommentFilterSyncParticipant(),
      );

      final exported = jsonDecode(await participant.exportSnapshot()) as Map;
      final data = exported['data'] as Map;

      expect(
        data[hazukiDiscoverDailyRecommendationEnabledPreferenceKey],
        isTrue,
      );
      expect(
        data,
        isNot(contains(hazukiDiscoverDailyRecommendationCachePreferenceKey)),
      );
      expect(
        data,
        isNot(
          contains('${hazukiDiscoverDailyRecommendationCachePreferenceKey}_jm'),
        ),
      );
    },
  );

  test('settings participant syncs image storage cleanup mode only', () async {
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.cacheMaxBytes: 1024 * 1024 * 1024,
      SourcePrefsKeys.cacheAutoCleanMode: 'seven_days',
      SourcePrefsKeys.cacheLastAutoCleanAt: 123456789,
    });
    final database = HazukiDatabase.memory();
    addTearDown(database.close);
    final groups = DownloadGroupsService(database: database);
    addTearDown(groups.dispose);
    final participant = CloudSyncSettingsParticipant(
      localFavorites: LocalFavoritesSyncParticipant(
        LocalFavoritesService(database: database),
      ),
      downloadGroups: DownloadGroupsSyncParticipant(groups),
      commentFilter: const CommentFilterSyncParticipant(),
    );

    final exported = jsonDecode(await participant.exportSnapshot()) as Map;
    final data = exported['data'] as Map;

    expect(data, isNot(contains(SourcePrefsKeys.cacheMaxBytes)));
    expect(data[SourcePrefsKeys.cacheAutoCleanMode], 'seven_days');
    expect(data, isNot(contains(SourcePrefsKeys.cacheLastAutoCleanAt)));
  });
}
