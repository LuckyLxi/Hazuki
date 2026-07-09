import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_config_store.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_models.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_participant_set.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_remote_client.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_restore_applier.dart';
import 'package:hazuki/services/cloud_sync/cloud_sync_snapshot_codec.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

late CloudSyncParticipantSet _participants;
late _CloudSyncFixture _fixture;

class _CloudSyncFixture {
  _CloudSyncFixture._({
    required this.database,
    required this.source,
    required this.readHistory,
    required this.readingProgress,
    required this.localFavorites,
    required this.downloadGroups,
    required this.searchHistory,
    required this.participants,
  });

  factory _CloudSyncFixture.create() {
    final database = HazukiDatabase.memory();
    final source = HazukiSourceService();
    final readHistory = ReadHistoryService(database: database);
    final readingProgress = ReadingProgressService(database: database);
    final localFavorites = LocalFavoritesService(database: database);
    final downloadGroups = DownloadGroupsService(database: database);
    final searchHistory = SearchHistoryService(database: database);
    return _CloudSyncFixture._(
      database: database,
      source: source,
      readHistory: readHistory,
      readingProgress: readingProgress,
      localFavorites: localFavorites,
      downloadGroups: downloadGroups,
      searchHistory: searchHistory,
      participants: createCloudSyncParticipantSet(
        source: HazukiSourceSyncAdapter(source),
        readHistory: readHistory,
        readingProgress: readingProgress,
        localFavorites: localFavorites,
        downloadGroups: downloadGroups,
        searchHistory: searchHistory,
      ),
    );
  }

  final HazukiDatabase database;
  final HazukiSourceService source;
  final ReadHistoryService readHistory;
  final ReadingProgressService readingProgress;
  final LocalFavoritesService localFavorites;
  final DownloadGroupsService downloadGroups;
  final SearchHistoryService searchHistory;
  final CloudSyncParticipantSet participants;

  Future<void> dispose() async {
    downloadGroups.dispose();
    source.dispose();
    await database.close();
  }
}

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
    _fixture = _CloudSyncFixture.create();
    _participants = _fixture.participants;
  });
  tearDown(() => _fixture.dispose());

  group('CloudSyncRestoreApplier source-scoped reading data', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
    });

    test(
      'restores progress with sourceKey in the preference key and payload',
      () async {
        await CloudSyncRestoreApplier(
          participants: _participants,
        ).applyReadingSnapshot(
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

        final progress = await _fixture.readingProgress.load(
          comicId: '123',
          sourceKey: 'jm',
        );
        final history = await _fixture.readHistory.exportJsonList();

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
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: remoteSettings,
        }),
      );

      final entries =
          jsonDecode(await _fixture.localFavorites.exportEntriesJsonString())
              as List<dynamic>;
      expect(entries, hasLength(1));
      expect((entries.single as Map<String, dynamic>)['sourceKey'], 'other');

      final tombstones =
          jsonDecode(
                await _fixture.localFavorites.exportEntryTombstonesJsonString(),
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
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: remoteSettings,
        }),
        applyRemoteSettings: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), [
        'remote',
        'local',
      ]);
    });

    test('does not revive a locally deleted comment filter keyword', () async {
      SharedPreferences.setMockInitialValues({
        hazukiCommentFilterKeywordsKey: ['kept'],
      });

      final remoteSettings = jsonEncode({
        'version': 2,
        'data': {
          hazukiCommentFilterKeywordsKey: ['deleted', 'kept'],
        },
      });

      await CloudSyncSnapshotCodec(
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: remoteSettings,
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), ['kept']);
    });

    test('applies a newer remote comment filter deletion', () async {
      SharedPreferences.setMockInitialValues({
        hazukiCommentFilterKeywordsKey: ['deleted', 'kept'],
        hazukiCommentFilterKeywordsUpdatedAtKey: 100,
      });

      final remoteSettings = jsonEncode({
        'version': 2,
        'data': {
          hazukiCommentFilterKeywordsKey: ['kept'],
          hazukiCommentFilterKeywordsUpdatedAtKey: 200,
        },
      });

      await CloudSyncSnapshotCodec(
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: remoteSettings,
        }),
        applyRemoteSettings: true,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), ['kept']);
      expect(prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey), 200);
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
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.searchHistoryFileName: remoteSearchHistory,
        }),
      );

      final history = await _fixture.searchHistory.load();
      expect(history, hasLength(hazukiSearchHistoryMaxCount));
      expect(
        history,
        List.generate(hazukiSearchHistoryMaxCount, (index) => 'remote-$index'),
      );
    });

    test(
      'keeps migrated legacy search history during the first merge',
      () async {
        SharedPreferences.setMockInitialValues({
          'search_history': ['local-keyword'],
        });

        await CloudSyncSnapshotCodec(
          participants: _participants,
        ).mergeRemoteIntoLocal(
          _FakeCloudSyncRemoteClient({
            CloudSyncConfigStore.searchHistoryFileName: jsonEncode({
              'keyword': 'remote-keyword',
            }),
          }),
        );

        expect(await _fixture.searchHistory.load(), [
          'remote-keyword',
          'local-keyword',
        ]);
      },
    );

    test('notifies listeners after merging remote search history', () async {
      final historyService = _fixture.searchHistory;
      var notificationCount = 0;
      historyService.addListener(() => notificationCount++);

      await CloudSyncSnapshotCodec(
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.searchHistoryFileName: jsonEncode({
            'keyword': 'remote-keyword',
          }),
        }),
      );

      expect(await historyService.load(), ['remote-keyword']);
      expect(notificationCount, 1);
    });

    test(
      'does not revive a deleted search keyword from an old device',
      () async {
        final historyService = _fixture.searchHistory;
        await historyService.add('keep');
        await historyService.add('delete');
        final oldSnapshot = await historyService.exportSyncJsonl();

        await historyService.remove('delete');
        final deletedSnapshot = await historyService.exportSyncJsonl();
        final tombstone = deletedSnapshot
            .split('\n')
            .map((line) => jsonDecode(line) as Map<String, dynamic>)
            .firstWhere((item) => item['type'] == 'tombstone');
        expect(tombstone['deletedKeyword'], 'delete');
        expect(tombstone.containsKey('keyword'), isFalse);
        await CloudSyncSnapshotCodec(
          participants: _participants,
        ).mergeRemoteIntoLocal(
          _FakeCloudSyncRemoteClient({
            CloudSyncConfigStore.searchHistoryFileName: oldSnapshot,
          }),
        );

        expect(await historyService.load(), ['keep']);
      },
    );

    test('does not revive search history after it was cleared', () async {
      final historyService = _fixture.searchHistory;
      await historyService.add('old-keyword');
      final oldSnapshot = await historyService.exportSyncJsonl();

      await historyService.clear();
      await CloudSyncSnapshotCodec(
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.searchHistoryFileName: oldSnapshot,
        }),
      );

      expect(await historyService.load(), isEmpty);
    });

    test(
      'accepts a search keyword created after history was cleared',
      () async {
        final historyService = _fixture.searchHistory;
        await historyService.add('old-keyword');
        await historyService.clear();
        final clearedSnapshot = await historyService.exportSyncJsonl();
        final clearEvent = clearedSnapshot
            .split('\n')
            .map((line) => jsonDecode(line) as Map<String, dynamic>)
            .firstWhere((item) => item['type'] == 'clear');

        await CloudSyncSnapshotCodec(
          participants: _participants,
        ).mergeRemoteIntoLocal(
          _FakeCloudSyncRemoteClient({
            CloudSyncConfigStore.searchHistoryFileName: jsonEncode({
              'type': 'entry',
              'keyword': 'new-keyword',
              'updatedAtMs': (clearEvent['clearedAtMs'] as int) + 1,
            }),
          }),
        );

        expect(await historyService.load(), ['new-keyword']);
      },
    );

    test('syncs a search keyword added again after deletion', () async {
      final historyService = _fixture.searchHistory;
      await historyService.add('keyword');
      await historyService.remove('keyword');
      await historyService.add('keyword');

      final snapshot = await historyService.exportSyncJsonl();
      await historyService.clear();
      await CloudSyncRestoreApplier(
        participants: _participants,
      ).applySearchHistoryJsonl(snapshot);

      expect(await historyService.load(), ['keyword']);
    });

    test('trims restored search history to the shared local limit', () async {
      final backupSearchHistory = List.generate(
        hazukiSearchHistoryMaxCount + 5,
        (index) => jsonEncode({'keyword': 'keyword-$index'}),
      ).join('\n');

      await CloudSyncRestoreApplier(
        participants: _participants,
      ).applySearchHistoryJsonl(backupSearchHistory);

      final history = await _fixture.searchHistory.load();
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
        participants: _participants,
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

    test('backs up local favorites stored in Drift', () async {
      final favorites = _fixture.localFavorites;
      await favorites.addFavoriteFolder('Synced folder', sourceKey: 'jm');
      final folder = (await favorites.loadFavoriteFolders(
        sourceKey: 'jm',
      )).folders.single;
      await favorites.toggleFavorite(
        details: const ComicDetailsData(
          id: 'comic-123',
          sourceKey: 'jm',
          title: 'Synced comic',
          subTitle: '',
          cover: '',
          description: '',
          updateTime: '',
          likesCount: '',
          chapters: {},
          tags: {},
          recommend: [],
          isFavorite: false,
          subId: '',
        ),
        isAdding: true,
        folderId: folder.id,
      );

      final snapshot = await CloudSyncSnapshotCodec(
        participants: _participants,
      ).buildLocalSnapshotFiles();
      final settings = jsonDecode(snapshot.settings) as Map<String, dynamic>;
      final data = settings['data'] as Map<String, dynamic>;
      final folders =
          jsonDecode(
                data[CloudSyncConfigStore.localFavoriteFoldersKey] as String,
              )
              as List<dynamic>;
      final entries =
          jsonDecode(
                data[CloudSyncConfigStore.localFavoriteEntriesKey] as String,
              )
              as List<dynamic>;

      expect((folders.single as Map<String, dynamic>)['name'], 'Synced folder');
      expect((folders.single as Map<String, dynamic>)['sourceKey'], 'jm');
      expect((entries.single as Map<String, dynamic>)['comicId'], 'comic-123');
      expect((entries.single as Map<String, dynamic>)['sourceKey'], 'jm');
    });

    test('restores local favorites into Drift', () async {
      await CloudSyncRestoreApplier(
        participants: _participants,
      ).applySettingsJson(
        jsonEncode({
          'version': 2,
          'data': {
            CloudSyncConfigStore.localFavoriteFoldersKey: jsonEncode([
              {'id': 'folder-1', 'name': 'Restored folder', 'sourceKey': 'jm'},
            ]),
            CloudSyncConfigStore.localFavoriteEntriesKey: jsonEncode([
              {
                'comicId': 'comic-123',
                'sourceKey': 'jm',
                'title': 'Restored comic',
                'folderIds': ['folder-1'],
                'folderSavedAtMs': {'folder-1': 123},
              },
            ]),
          },
        }),
      );

      final favorites = _fixture.localFavorites;
      final folders = await favorites.loadFavoriteFolders(sourceKey: 'jm');
      final comics = await favorites.loadFavoriteComics(
        page: 1,
        folderId: 'folder-1',
        sourceKey: 'jm',
      );

      expect(folders.folders.single.name, 'Restored folder');
      expect(comics.comics.single.id, 'comic-123');
      expect(comics.comics.single.title, 'Restored comic');
    });

    test(
      'does not revive a removed comic-folder link from an old device',
      () async {
        final favorites = _fixture.localFavorites;
        await favorites.addFavoriteFolder('Folder A', sourceKey: 'jm');
        await favorites.addFavoriteFolder('Folder B', sourceKey: 'jm');
        final folders = (await favorites.loadFavoriteFolders(
          sourceKey: 'jm',
        )).folders;
        final folderA = folders.firstWhere(
          (folder) => folder.name == 'Folder A',
        );
        final folderB = folders.firstWhere(
          (folder) => folder.name == 'Folder B',
        );
        const details = ComicDetailsData(
          id: 'comic-123',
          sourceKey: 'jm',
          title: 'Synced comic',
          subTitle: '',
          cover: '',
          description: '',
          updateTime: '',
          likesCount: '',
          chapters: {},
          tags: {},
          recommend: [],
          isFavorite: false,
          subId: '',
        );
        await favorites.toggleFavorite(
          details: details,
          isAdding: true,
          folderId: folderA.id,
        );
        await favorites.toggleFavorite(
          details: details,
          isAdding: true,
          folderId: folderB.id,
        );
        final oldSnapshot = await CloudSyncSnapshotCodec(
          participants: _participants,
        ).buildLocalSnapshotFiles();

        await favorites.toggleFavorite(
          details: details,
          isAdding: false,
          folderId: folderA.id,
        );
        await CloudSyncSnapshotCodec(
          participants: _participants,
        ).mergeRemoteIntoLocal(
          _FakeCloudSyncRemoteClient({
            CloudSyncConfigStore.settingsFileName: oldSnapshot.settings,
          }),
        );

        final inFolderA = await favorites.loadFavoriteComics(
          page: 1,
          folderId: folderA.id,
          sourceKey: 'jm',
        );
        final inFolderB = await favorites.loadFavoriteComics(
          page: 1,
          folderId: folderB.id,
          sourceKey: 'jm',
        );
        expect(inFolderA.comics, isEmpty);
        expect(inFolderB.comics.single.id, 'comic-123');
      },
    );

    test('keeps a comic-folder link re-added after its removal', () async {
      final favorites = _fixture.localFavorites;
      await favorites.addFavoriteFolder('Folder', sourceKey: 'jm');
      final folder = (await favorites.loadFavoriteFolders(
        sourceKey: 'jm',
      )).folders.single;
      const details = ComicDetailsData(
        id: 'comic-123',
        sourceKey: 'jm',
        title: 'Synced comic',
        subTitle: '',
        cover: '',
        description: '',
        updateTime: '',
        likesCount: '',
        chapters: {},
        tags: {},
        recommend: [],
        isFavorite: false,
        subId: '',
      );
      await favorites.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folder.id,
      );
      await favorites.toggleFavorite(
        details: details,
        isAdding: false,
        folderId: folder.id,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await favorites.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folder.id,
      );

      final snapshot = await CloudSyncSnapshotCodec(
        participants: _participants,
      ).buildLocalSnapshotFiles();
      await CloudSyncSnapshotCodec(
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: snapshot.settings,
        }),
      );

      final comics = await favorites.loadFavoriteComics(
        page: 1,
        folderId: folder.id,
        sourceKey: 'jm',
      );
      expect(comics.comics.single.id, 'comic-123');
    });

    test(
      'keeps a deleted comic when it is later added to another folder',
      () async {
        final favorites = _fixture.localFavorites;
        await favorites.addFavoriteFolder('Old folder', sourceKey: 'jm');
        await favorites.addFavoriteFolder('New folder', sourceKey: 'jm');
        final folders = (await favorites.loadFavoriteFolders(
          sourceKey: 'jm',
        )).folders;
        final oldFolder = folders.firstWhere(
          (folder) => folder.name == 'Old folder',
        );
        final newFolder = folders.firstWhere(
          (folder) => folder.name == 'New folder',
        );
        const details = ComicDetailsData(
          id: 'comic-123',
          sourceKey: 'jm',
          title: 'Synced comic',
          subTitle: '',
          cover: '',
          description: '',
          updateTime: '',
          likesCount: '',
          chapters: {},
          tags: {},
          recommend: [],
          isFavorite: false,
          subId: '',
        );
        await favorites.toggleFavorite(
          details: details,
          isAdding: true,
          folderId: oldFolder.id,
        );
        await favorites.toggleFavorite(
          details: details,
          isAdding: false,
          folderId: oldFolder.id,
        );
        await favorites.toggleFavorite(
          details: details,
          isAdding: true,
          folderId: newFolder.id,
        );

        final snapshot = await CloudSyncSnapshotCodec(
          participants: _participants,
        ).buildLocalSnapshotFiles();
        await CloudSyncSnapshotCodec(
          participants: _participants,
        ).mergeRemoteIntoLocal(
          _FakeCloudSyncRemoteClient({
            CloudSyncConfigStore.settingsFileName: snapshot.settings,
          }),
        );

        final comics = await favorites.loadFavoriteComics(
          page: 1,
          folderId: newFolder.id,
          sourceKey: 'jm',
        );
        expect(comics.comics.single.id, 'comic-123');
      },
    );

    test('applies the latest folder rename from another device', () async {
      final favorites = _fixture.localFavorites;
      await favorites.addFavoriteFolder('Old name', sourceKey: 'jm');
      final localFolders =
          jsonDecode(await favorites.exportFoldersJsonString())
              as List<dynamic>;
      final localFolder = Map<String, dynamic>.from(localFolders.single as Map);
      final remoteFolder = Map<String, dynamic>.from(localFolder)
        ..['name'] = 'Remote name'
        ..['updatedAtMs'] = (localFolder['updatedAtMs'] as int) + 1;

      await CloudSyncSnapshotCodec(
        participants: _participants,
      ).mergeRemoteIntoLocal(
        _FakeCloudSyncRemoteClient({
          CloudSyncConfigStore.settingsFileName: jsonEncode({
            'version': 2,
            'data': {
              CloudSyncConfigStore.localFavoriteFoldersKey: jsonEncode([
                remoteFolder,
              ]),
              CloudSyncConfigStore.localFavoriteEntriesKey: '[]',
            },
          }),
        }),
      );

      final folders = await favorites.loadFavoriteFolders(sourceKey: 'jm');
      expect(folders.folders.single.name, 'Remote name');
    });
  });
}
