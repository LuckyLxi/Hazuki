import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/favorite/favorite.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';

class ComicDetailRepository implements FavoriteFoldersRepository {
  const ComicDetailRepository({
    required HazukiSourceService source,
    required LocalFavoritesService local,
    required MangaDownloadService downloader,
  }) : _source = source,
       _local = local,
       _downloader = downloader;

  final HazukiSourceService _source;
  final LocalFavoritesService _local;
  final MangaDownloadService _downloader;

  // ── Source capabilities ──────────────────────────────────────────────────

  @override
  bool get isLogged => _source.isLogged;
  @override
  bool get supportFavoriteFolderLoad => _source.supportFavoriteFolderLoad;
  @override
  bool get supportFavoriteFolderAdd => _source.supportFavoriteFolderAdd;
  @override
  bool get supportFavoriteFolderDelete => _source.supportFavoriteFolderDelete;
  @override
  bool get supportFavoriteToggle => _source.supportFavoriteToggle;
  bool get supportComicLike => _source.supportComicLike;
  @override
  bool get favoriteSingleFolderForSingleComic =>
      _source.favoriteSingleFolderForSingleComic;

  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
  }) => _source.loadComicDetails(id, sourceKey: sourceKey);

  Future<List<CategoryTagGroup>> loadCategoryTagGroups() {
    return _source.loadCategoryTagGroups();
  }

  Future<Uint8List> downloadImageBytes(
    String url, {
    bool keepInMemory = false,
    String sourceKey = '',
  }) => _source.downloadImageBytes(
    url,
    keepInMemory: keepInMemory,
    sourceKey: sourceKey,
  );

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) => _source.loadChapterImages(
    comicId: comicId,
    epId: epId,
    sourceKey: sourceKey,
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
    sourceKey: sourceKey,
  );

  @override
  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  }) => _source.loadFavoriteFolders(comicId: comicId);

  @override
  Future<void> addCloudFavoriteFolder(String name) =>
      _source.addFavoriteFolder(name);

  @override
  Future<void> deleteCloudFavoriteFolder(String id) =>
      _source.deleteFavoriteFolder(id);

  @override
  Future<void> toggleCloudFavorite({
    required String comicId,
    required bool isAdding,
    required String folderId,
  }) => _source.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
  );

  // ── Local favorites ──────────────────────────────────────────────────────

  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) => _source.toggleComicLike(
    comicId: comicId,
    isLike: isLike,
    sourceKey: sourceKey,
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
    return sl<ReadingProgressService>().load(
      comicId: comicId,
      sourceKey: _source.activeSourceKey,
    );
  }

  Future<bool> loadComicDynamicColorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('appearance_comic_detail_dynamic_color') ?? false;
  }

  Future<void> recordHistory({
    required ExploreComic comic,
    required ComicDetailsData details,
  }) => sl<ReadHistoryService>().recordHistory(comic: comic, details: details);
}
