import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/manga_download_service.dart';

class ComicDetailRepository {
  const ComicDetailRepository();

  HazukiSourceService get _source => HazukiSourceService.instance;
  LocalFavoritesService get _local => LocalFavoritesService.instance;
  MangaDownloadService get _downloader => MangaDownloadService.instance;

  // ── Source capabilities ──────────────────────────────────────────────────

  bool get isLogged => _source.isLogged;
  bool get supportFavoriteFolderLoad => _source.supportFavoriteFolderLoad;
  bool get supportFavoriteFolderAdd => _source.supportFavoriteFolderAdd;
  bool get supportFavoriteFolderDelete => _source.supportFavoriteFolderDelete;
  bool get supportFavoriteToggle => _source.supportFavoriteToggle;
  bool get favoriteSingleFolderForSingleComic =>
      _source.favoriteSingleFolderForSingleComic;

  Future<ComicDetailsData> loadComicDetails(String id) =>
      _source.loadComicDetails(id);

  Future<Uint8List> downloadImageBytes(
    String url, {
    bool keepInMemory = false,
  }) => _source.downloadImageBytes(url, keepInMemory: keepInMemory);

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
  }) => _source.loadChapterImages(comicId: comicId, epId: epId);

  Future<void> prefetchComicImages({
    required String comicId,
    required String epId,
    required List<String> imageUrls,
    required int count,
    required int memoryCount,
  }) => _source.prefetchComicImages(
    comicId: comicId,
    epId: epId,
    imageUrls: imageUrls,
    count: count,
    memoryCount: memoryCount,
  );

  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  }) => _source.loadFavoriteFolders(comicId: comicId);

  Future<void> addCloudFavoriteFolder(String name) =>
      _source.addFavoriteFolder(name);

  Future<void> deleteCloudFavoriteFolder(String id) =>
      _source.deleteFavoriteFolder(id);

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

  Future<bool> isComicLocallyFavorited(String comicId) =>
      _local.isComicFavorited(comicId);

  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
  }) => _local.loadFavoriteFolders(comicId: comicId);

  Future<void> addLocalFavoriteFolder(String name) =>
      _local.addFavoriteFolder(name);

  Future<void> deleteLocalFavoriteFolder(String id) =>
      _local.deleteFavoriteFolder(id);

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

  Future<void> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
  }) => _downloader.enqueueDownload(
    details: details,
    coverUrl: coverUrl,
    description: description,
    chapters: chapters,
  );

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> loadReadingProgress(String comicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('reading_progress_$comicId');
      if (jsonStr == null) return null;
      return jsonDecode(jsonStr) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> loadComicDynamicColorEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('appearance_comic_detail_dynamic_color') ?? false;
  }

  Future<void> recordHistory({
    required ExploreComic comic,
    required ComicDetailsData details,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var history = <Map<String, dynamic>>[];
      final jsonStr = prefs.getString('hazuki_read_history');
      if (jsonStr != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(jsonStr);
          history = jsonList.cast<Map<String, dynamic>>();
        } catch (_) {}
      }

      final comicId = details.id.trim().isNotEmpty ? details.id : comic.id;
      final coverUrl =
          details.cover.trim().isNotEmpty ? details.cover : comic.cover;

      history.removeWhere((e) => e['id'] == comicId);
      history.insert(0, {
        'id': comicId,
        'title': details.title.isNotEmpty ? details.title : comic.title,
        'cover': coverUrl,
        'subTitle': details.subTitle.isNotEmpty
            ? details.subTitle
            : comic.subTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (history.length > 70) {
        history = history.sublist(0, 70);
      }

      await prefs.setString('hazuki_read_history', jsonEncode(history));
    } catch (_) {}
  }
}
