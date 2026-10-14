import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_participant.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_participant_set.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_remote_client.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_restore_applier.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_settings_participant.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_snapshot_codec.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _config = CloudSyncConfig(
  enabled: true,
  url: 'https://example.test',
  username: 'user',
  password: 'pass',
);

class _Source extends Mock implements SourceSyncGateway {}

class _Remote extends CloudSyncRemoteClient {
  _Remote(this.files) : super(_config, configStore: CloudSyncConfigStore());

  final Map<String, String> files;
  String? failRead;
  bool lockHeld = false;

  @override
  Future<void> ensureRootDir() async {}
  @override
  Future<void> ensureBackupDirs() async {}
  @override
  Future<bool> tryAcquireSyncLock(String token) async => lockHeld = true;
  @override
  Future<void> releaseSyncLock(String token) async => lockHeld = false;
  @override
  Future<String?> tryGetBackupFile(String fileName) async {
    if (fileName == failRead) throw StateError('Download failed');
    return files[fileName];
  }

  @override
  Future<String> getBackupFile(String fileName) async => files[fileName]!;
  @override
  Future<String> loadReadingSnapshotText() async =>
      files[CloudSyncConfigStore.readingFileName]!;
  @override
  Future<void> putBackupFile(String fileName, String content) async {
    files[fileName] = content;
  }
}

class _FailingGroupsParticipant extends DownloadGroupsSyncParticipant {
  const _FailingGroupsParticipant(super.service);

  @override
  Future<void> mergeSnapshot(String? snapshot) async =>
      throw StateError('Group import failed');
}

class _Fixture {
  _Fixture._(
    this.database,
    this.favorites,
    this.groups,
    this.filter,
    this.history,
    this.participants,
  );

  final HazukiDatabase database;
  final LocalFavoritesService favorites;
  final DownloadGroupsService groups;
  final CommentFilterService filter;
  final ReadHistoryService history;
  final CloudSyncParticipantSet participants;

  static Future<_Fixture> create({bool failGroupImport = false}) async {
    final database = HazukiDatabase.memory();
    final favorites = LocalFavoritesService(database: database);
    final groups = DownloadGroupsService(database: database);
    final filter = CommentFilterService();
    final history = ReadHistoryService(database: database);
    final source = _Source();
    when(() => source.activeSourceKey).thenReturn('jm');
    await groups.initialize(const []);
    await favorites.exportFoldersJsonString();
    await filter.load();
    var participants = createCloudSyncParticipantSet(
      source: source,
      readHistory: history,
      readingProgress: ReadingProgressService(database: database),
      localFavorites: favorites,
      downloadGroups: groups,
      searchHistory: SearchHistoryService(database: database),
      commentFilter: filter,
    );
    if (failGroupImport) {
      final failingGroups = _FailingGroupsParticipant(groups);
      participants = CloudSyncParticipantSet(
        reading: participants.reading,
        settings: CloudSyncSettingsParticipant(
          localFavorites: participants.favorites,
          downloadGroups: failingGroups,
          commentFilter: participants.commentFilter,
        ),
        searchHistory: participants.searchHistory,
        commentFilter: participants.commentFilter,
        favorites: participants.favorites,
        downloadGroups: failingGroups,
      );
    }
    final fixture = _Fixture._(
      database,
      favorites,
      groups,
      filter,
      history,
      participants,
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  CloudSyncService service(_Remote remote) => CloudSyncService(
    participants: participants,
    remoteClientFactory: (_, _) => remote,
  );

  Future<void> dispose() async {
    favorites.dispose();
    groups.dispose();
    filter.dispose();
    history.dispose();
    await database.close();
  }
}

Map<String, String> _remoteFiles(Map<String, Object?> settings) => {
  CloudSyncConfigStore.manifestFileName: jsonEncode({
    'version': 2,
    'updatedAtMs': 200,
  }),
  CloudSyncConfigStore.settingsFileName: jsonEncode({
    'version': 2,
    'data': settings,
  }),
  CloudSyncConfigStore.readingFileName: jsonEncode({
    'history': [],
    'progress': [],
  }),
  CloudSyncConfigStore.searchHistoryFileName: '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      hazukiCommentFilterKeywordsKey: ['local'],
      hazukiCommentFilterKeywordsUpdatedAtKey: 100,
      hazukiCommentFilterModeKey: 'collapse',
    });
  });

  test(
    'upload merge refreshes data owners without duplicate notifications',
    () async {
      final fixture = await _Fixture.create();
      final remote = _Remote(
        _remoteFiles({
          hazukiCommentFilterKeywordsKey: ['remote'],
          hazukiCommentFilterKeywordsUpdatedAtKey: 200,
          hazukiCommentFilterModeKey: 'hide',
          CloudSyncConfigStore.downloadGroupsKey: await fixture.groups
              .exportJsonString(),
        }),
      );
      var favoritesNotifications = 0;
      var groupNotifications = 0;
      final filterSnapshots = <(List<String>, CommentFilterMode, int)>[];
      fixture.favorites.addListener(() => favoritesNotifications++);
      fixture.groups.addListener(() => groupNotifications++);
      fixture.filter.addListener(
        () => filterSnapshots.add((
          fixture.filter.userKeywords,
          fixture.filter.mode,
          groupNotifications,
        )),
      );

      await fixture.service(remote).uploadBackup(configOverride: _config);

      expect(favoritesNotifications, 1);
      // Each of the local and remote group snapshots is applied by the owner.
      expect(groupNotifications, 2);
      expect(filterSnapshots, hasLength(1));
      expect(filterSnapshots.single.$1, ['remote']);
      expect(filterSnapshots.single.$2, CommentFilterMode.hide);
      expect(filterSnapshots.single.$3, 2);
      expect(remote.lockHeld, isFalse);
    },
  );

  test(
    'missing settings retains the completion reload without business refreshes',
    () async {
      final fixture = await _Fixture.create();
      final remote = _Remote({
        CloudSyncConfigStore.manifestFileName: jsonEncode({'updatedAtMs': 200}),
      });
      var favoritesNotifications = 0;
      var groupNotifications = 0;
      var filterNotifications = 0;
      fixture.favorites.addListener(() => favoritesNotifications++);
      fixture.groups.addListener(() => groupNotifications++);
      fixture.filter.addListener(() => filterNotifications++);

      await fixture.service(remote).uploadBackup(configOverride: _config);

      expect(favoritesNotifications, 0);
      expect(groupNotifications, 0);
      expect(filterNotifications, 1);
      expect(fixture.filter.userKeywords, ['local']);
    },
  );

  test(
    'download failure propagates without refresh and releases the lock',
    () async {
      final fixture = await _Fixture.create();
      final remote = _Remote(_remoteFiles({}))
        ..failRead = CloudSyncConfigStore.settingsFileName;
      var notifications = 0;
      fixture.filter.addListener(() => notifications++);
      fixture.favorites.addListener(() => notifications++);
      fixture.groups.addListener(() => notifications++);

      await expectLater(
        fixture.service(remote).uploadBackup(configOverride: _config),
        throwsStateError,
      );
      expect(notifications, 0);
      expect(remote.lockHeld, isFalse);
    },
  );

  test(
    'late apply failure preserves writes but does not reload partial filter settings',
    () async {
      final fixture = await _Fixture.create(failGroupImport: true);
      var filterNotifications = 0;
      fixture.filter.addListener(() => filterNotifications++);
      final remote = _Remote(
        _remoteFiles({
          hazukiCommentFilterKeywordsKey: ['remote'],
          hazukiCommentFilterKeywordsUpdatedAtKey: 200,
          hazukiCommentFilterModeKey: 'hide',
        }),
      );

      await expectLater(
        fixture.service(remote).uploadBackup(configOverride: _config),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), ['remote']);
      expect(prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey), 200);
      expect(filterNotifications, 0);
      expect(fixture.filter.userKeywords, ['local']);
      expect(fixture.filter.mode, CommentFilterMode.collapse);
      expect(remote.lockHeld, isFalse);
    },
  );

  test(
    'manual restore reloads the filter before restoring reading data',
    () async {
      final fixture = await _Fixture.create();
      final remote = _Remote(
        _remoteFiles({
          hazukiCommentFilterKeywordsKey: ['restored'],
          hazukiCommentFilterKeywordsUpdatedAtKey: 50,
          hazukiCommentFilterModeKey: 'hide',
        }),
      );
      final events = <String>[];
      fixture.filter.addListener(() {
        expect(fixture.filter.userKeywords, ['restored']);
        expect(fixture.filter.mode, CommentFilterMode.hide);
        events.add('filter');
      });
      fixture.history.addListener(() {
        expect(fixture.filter.userKeywords, ['restored']);
        events.add('reading');
      });

      await fixture
          .service(remote)
          .restoreLatestBackup(configOverride: _config);

      expect(events, ['filter', 'reading']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey), 50);
    },
  );

  for (final data in <Map<String, Object?>>[
    {},
    {
      hazukiCommentFilterKeywordsKey: null,
      hazukiCommentFilterKeywordsUpdatedAtKey: null,
      hazukiCommentFilterModeKey: null,
    },
  ]) {
    test(
      'manual restore preserves missing or null filter settings: $data',
      () async {
        final fixture = await _Fixture.create();
        var notifications = 0;
        fixture.filter.addListener(() => notifications++);
        await CloudSyncRestoreApplier(
          participants: fixture.participants,
        ).applySettingsJson(jsonEncode({'version': 2, 'data': data}));
        expect(fixture.filter.userKeywords, ['local']);
        expect(fixture.filter.mode, CommentFilterMode.collapse);
        expect((await fixture.filter.captureMergeSnapshot()).updatedAtMs, 100);
        expect(notifications, 1);
      },
    );
  }

  test('newer automatic settings remove a missing filter mode', () async {
    SharedPreferences.setMockInitialValues({
      hazukiCommentFilterKeywordsKey: ['local'],
      hazukiCommentFilterKeywordsUpdatedAtKey: 100,
      hazukiCommentFilterModeKey: 'hide',
    });
    final fixture = await _Fixture.create();
    await CloudSyncSnapshotCodec(
      participants: fixture.participants,
    ).mergeRemoteIntoLocal(
      _Remote(_remoteFiles({})),
      applyRemoteSettings: true,
    );
    expect(fixture.filter.userKeywords, ['local']);
    expect(fixture.filter.mode, CommentFilterMode.collapse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(hazukiCommentFilterModeKey), isFalse);
    expect(prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey), 100);
  });

  test(
    'invalid restored settings do not publish a completion refresh',
    () async {
      final fixture = await _Fixture.create();
      var notifications = 0;
      fixture.filter.addListener(() => notifications++);
      await expectLater(
        CloudSyncRestoreApplier(
          participants: fixture.participants,
        ).applySettingsJson('{'),
        throwsException,
      );
      expect(notifications, 0);
      expect(fixture.filter.userKeywords, ['local']);
    },
  );
}
