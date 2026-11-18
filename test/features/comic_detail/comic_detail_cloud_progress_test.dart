import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Fake implements SourceComicDetailGateway {}

class _CloudReading extends Fake implements SourceCloudReadingGateway {
  bool cloud = true;
  bool fail = false;
  Map<String, dynamic>? progress;
  @override
  Future<bool> usesCloudReading(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) async => cloud;
  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId, {
    SourceTaskOrigin? taskOrigin,
  }) async {
    if (fail) throw StateError('cloud_reading_login_required');
    return progress;
  }

  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) async => [];
}

class _Local extends Fake implements LocalFavoritesRepository {}

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
      final cloudReading = _CloudReading();
      final repository = ComicDetailFeatureFacade(
        source: _Source(),
        cloudReading: cloudReading,
        local: _Local(),
        readingProgress: local,
        readHistory: ReadHistoryService(database: db),
        sourceKey: 'sample',
      );
      expect(await repository.loadReadingProgress('comic'), isNull);
      expect(await repository.watchReadingProgressChanges().toList(), isEmpty);
      cloudReading.fail = true;
      await expectLater(
        repository.loadReadingProgress('comic'),
        throwsStateError,
      );
      cloudReading.fail = false;
      cloudReading.progress = {
        'cloud': true,
        'epId': 'website',
        'imagePage': 7,
      };
      expect(
        (await repository.loadReadingProgress('comic'))?['epId'],
        'website',
      );
      expect(await local.exportJsonList(), original);
      cloudReading.cloud = false;
      expect(
        (await repository.loadReadingProgress('comic'))?['epId'],
        'old-local',
      );
    },
  );
}
