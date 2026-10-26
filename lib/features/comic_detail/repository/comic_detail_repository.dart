import 'dart:typed_data';
import 'package:hazuki/services/source/content/source_cloud_reading.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/manga_download/manga_download_commands.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/shared/favorites/favorite_folders_repository.dart';
import 'package:hazuki/shared/favorites/source_favorite_folders_repository.dart';
import 'package:hazuki/shared/preferences/hazuki_general_preferences_store.dart';

class ComicDetailFeatureFacade {
  ComicDetailFeatureFacade({
    required SourceComicDetailGateway source,
    required LocalFavoritesRepository local,
    required MangaDownloadCommands downloader,
    required ReadingProgressService readingProgress,
    required ReadHistoryService readHistory,
    String sourceKey = '',
    HazukiGeneralPreferencesStore preferences =
        const HazukiGeneralPreferencesStore(),
  }) : _source = source,
       _local = local,
       _downloader = downloader,
       _readingProgress = readingProgress,
       _readHistory = readHistory,
       _preferences = preferences,
       _sourceKey = sourceKey.trim().isEmpty
           ? (source.activeSourceKey ?? '')
           : sourceKey.trim();

  final SourceComicDetailGateway _source;
  final LocalFavoritesRepository _local;
  final MangaDownloadCommands _downloader;
  final ReadingProgressService _readingProgress;
  final ReadHistoryService _readHistory;
  final HazukiGeneralPreferencesStore _preferences;
  final String _sourceKey;

  /// 云端与本地收藏夹编辑，与详情页绑定同一个来源。
  late final FavoriteFoldersRepository favoriteFolders =
      SourceFavoriteFoldersRepository(
        source: _source,
        local: _local,
        sourceKey: _sourceKey,
      );

  // ── Source capabilities ──────────────────────────────────────────────────

  bool get supportComicLike => _source.supportComicLikeForSource(_sourceKey);

  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) => _source.loadComicDetails(
    id,
    sourceKey: sourceKey.trim().isEmpty ? _sourceKey : sourceKey,
    forceRefresh: forceRefresh,
  );

  Future<List<SourceDetailTabBlock>> loadDetailTab({
    required String comicId,
    required String tabId,
  }) => _source.loadDetailTab(
    comicId: comicId,
    tabId: tabId,
    sourceKey: _sourceKey,
  );

  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    SourceTaskOrigin? taskOrigin,
  }) {
    return _source.loadCategoryTagGroups(
      sourceKey: _sourceKey,
      taskOrigin: taskOrigin,
    );
  }

  Future<Uint8List> downloadImageBytes(
    String url, {
    bool keepInMemory = false,
    String sourceKey = '',
  }) => _source.downloadImageBytes(
    url,
    keepInMemory: keepInMemory,
    sourceKey: sourceKey.trim().isEmpty ? _sourceKey : sourceKey,
  );

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _source.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey.trim().isEmpty ? _sourceKey : sourceKey,
  );

  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
    String sourceKey = '',
  }) => _source.prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
    sourceKey: sourceKey.trim().isEmpty ? _sourceKey : sourceKey,
  );

  // ── Local favorites ──────────────────────────────────────────────────────

  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) => _source.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey.trim().isEmpty ? _sourceKey : sourceKey,
  );

  Future<bool> isComicLocallyFavorited(
    String comicId, {
    String sourceKey = '',
  }) => _local.isComicFavorited(comicId, sourceKey: sourceKey);

  // ── Downloads ────────────────────────────────────────────────────────────

  Future<MangaDownloadEnqueueResult> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
    bool redownloadExisting = false,
  }) => _downloader.enqueueDownload(
    details: details,
    coverUrl: coverUrl,
    description: description,
    chapters: chapters,
    redownloadExisting: redownloadExisting,
  );

  Future<MangaDownloadConflict> checkDownloadConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) => _downloader.checkDownloadConflict(details: details, chapters: chapters);

  Future<MangaDownloadConflict> checkDownloadTaskConflict({
    required ComicDetailsData details,
    required List<MangaChapterDownloadTarget> chapters,
  }) => _downloader.checkDownloadTaskConflict(
    details: details,
    chapters: chapters,
  );

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> loadReadingProgress(
    String comicId, {
    SourceTaskOrigin? taskOrigin,
  }) async {
    final source = _source;
    if (source is SourceCloudReadingGateway &&
        await (source as SourceCloudReadingGateway).usesCloudReading(
          _sourceKey,
          taskOrigin: taskOrigin,
        )) {
      return (source as SourceCloudReadingGateway).loadCloudReadingProgress(
        _sourceKey,
        comicId,
        taskOrigin: taskOrigin,
      );
    }
    return _readingProgress.load(comicId: comicId, sourceKey: _sourceKey);
  }

  Future<bool> usesWebsiteReadingProgress({
    SourceTaskOrigin? taskOrigin,
  }) async {
    final source = _source;
    return source is SourceCloudReadingGateway &&
        await (source as SourceCloudReadingGateway).usesCloudReading(
          _sourceKey,
          taskOrigin: taskOrigin,
        );
  }

  Stream<void> watchReadingProgressChanges({
    SourceTaskOrigin? taskOrigin,
  }) async* {
    if (await usesWebsiteReadingProgress(taskOrigin: taskOrigin)) return;
    yield* _readingProgress.changes;
  }

  Future<bool> loadComicDynamicColorEnabled() =>
      _preferences.loadComicDetailDynamicColorEnabled();

  Future<void> recordHistory({
    required ExploreComic comic,
    required ComicDetailsData details,
  }) => _readHistory.recordHistory(comic: comic, details: details);
}
