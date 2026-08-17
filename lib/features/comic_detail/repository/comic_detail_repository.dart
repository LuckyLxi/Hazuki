import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/shared/favorites/favorite_folders_repository.dart';

class ComicDetailFeatureFacade implements FavoriteFoldersRepository {
  ComicDetailFeatureFacade({
    required SourceComicDetailGateway source,
    required LocalFavoritesRepository local,
    required MangaDownloadService downloader,
    required ReadingProgressService readingProgress,
    required ReadHistoryService readHistory,
    String sourceKey = '',
  }) : _source = source,
       _local = local,
       _downloader = downloader,
       _readingProgress = readingProgress,
       _readHistory = readHistory,
       _sourceKey = sourceKey.trim().isEmpty
           ? source.activeSourceKey
           : sourceKey.trim();

  final SourceComicDetailGateway _source;
  final LocalFavoritesRepository _local;
  final MangaDownloadService _downloader;
  final ReadingProgressService _readingProgress;
  final ReadHistoryService _readHistory;
  final String _sourceKey;

  // ── Source capabilities ──────────────────────────────────────────────────

  @override
  bool get isLogged => _source.isLoggedForSource(_sourceKey);
  @override
  bool get supportFavoriteFolderLoad =>
      _source.supportFavoriteFolderLoadForSource(_sourceKey);
  @override
  bool get supportFavoriteFolderAdd =>
      _source.supportFavoriteFolderAddForSource(_sourceKey);
  @override
  bool get supportFavoriteFolderDelete =>
      _source.supportFavoriteFolderDeleteForSource(_sourceKey);
  @override
  bool get supportFavoriteToggle =>
      _source.supportFavoriteToggleForSource(_sourceKey);
  bool get supportComicLike => _source.supportComicLikeForSource(_sourceKey);
  @override
  bool get favoriteSingleFolderForSingleComic =>
      _source.favoriteSingleFolderForSingleComicForSource(_sourceKey);

  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) => _source.loadComicDetails(
    id,
    sourceKey: sourceKey.trim().isEmpty ? _sourceKey : sourceKey,
    forceRefresh: forceRefresh,
  );

  Future<List<CategoryTagGroup>> loadCategoryTagGroups() {
    return _source.loadCategoryTagGroups(sourceKey: _sourceKey);
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

  @override
  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  }) => _source.loadFavoriteFolders(comicId: comicId, sourceKey: _sourceKey);

  @override
  Future<void> addCloudFavoriteFolder(String name) =>
      _source.addFavoriteFolder(name, sourceKey: _sourceKey);

  @override
  Future<void> deleteCloudFavoriteFolder(String id) =>
      _source.deleteFavoriteFolder(id, sourceKey: _sourceKey);

  @override
  Future<void> toggleCloudFavorite({
    required String comicId,
    required bool isAdding,
    required String folderId,
  }) => _source.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    sourceKey: _sourceKey,
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

  @override
  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  }) => _local.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);

  @override
  Future<void> addLocalFavoriteFolder(String name, {String sourceKey = ''}) =>
      _local.addFavoriteFolder(name, sourceKey: sourceKey);

  @override
  Future<void> deleteLocalFavoriteFolder(String id, {String sourceKey = ''}) =>
      _local.deleteFavoriteFolder(id, sourceKey: sourceKey);

  @override
  Future<void> toggleLocalFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  }) => _local.toggleFavorite(
    details: details,
    isAdding: isAdding,
    folderId: folderId,
  );

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

  Future<Map<String, dynamic>?> loadReadingProgress(String comicId) async {
    return _readingProgress.load(comicId: comicId, sourceKey: _sourceKey);
  }

  Future<bool> loadComicDynamicColorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('appearance_comic_detail_dynamic_color') ?? false;
  }

  Future<void> recordHistory({
    required ExploreComic comic,
    required ComicDetailsData details,
  }) => _readHistory.recordHistory(comic: comic, details: details);
}
