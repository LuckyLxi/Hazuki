import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/content/source_cloud_reading.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Fake
    implements SourceComicDetailGateway, SourceCloudReadingGateway {
  bool cloud = true;
  bool fail = false;
  Map<String, dynamic>? progress;
  @override
  Future<bool> usesCloudReading(String sourceKey) async => cloud;
  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId,
  ) async {
    if (fail) throw StateError('cloud_reading_login_required');
    return progress;
  }

  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey,
  ) async => [];
}

class _Local extends Fake implements LocalFavoritesRepository {}

class _Downloads extends Fake implements MangaDownloadCommands {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'website declaration overrides existing local records even on null or failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = HazukiDatabase.memory();
      addTearDown(db.close);
      final local = ReadingProgressService(database: db);
      await local.save(
        comicId: 'comic',
        sourceKey: 'sample',
        epId: 'old-local',
        title: 'Old',
        chapterIndex: 8,
        pageIndex: 50,
      );
      final original = await local.exportJsonList();
      final source = _Source();
      final repository = ComicDetailFeatureFacade(
        source: source,
        local: _Local(),
        downloader: _Downloads(),
        readingProgress: local,
        readHistory: ReadHistoryService(database: db),
        sourceKey: 'sample',
      );
      expect(await repository.loadReadingProgress('comic'), isNull);
      expect(await repository.watchReadingProgressChanges().toList(), isEmpty);
      source.fail = true;
      await expectLater(
        repository.loadReadingProgress('comic'),
        throwsStateError,
      );
      source.fail = false;
      source.progress = {'cloud': true, 'epId': 'website', 'imagePage': 7};
      expect(
        (await repository.loadReadingProgress('comic'))?['epId'],
        'website',
      );
      expect(await local.exportJsonList(), original);
      source.cloud = false;
      expect(
        (await repository.loadReadingProgress('comic'))?['epId'],
        'old-local',
      );
    },
  );
}
