import 'package:flutter/foundation.dart';

import 'manga_download_models.dart';

export 'manga_download_models.dart';

/// Existing downloads and their management operations, without enqueue,
/// storage configuration or application lifecycle responsibilities.
abstract interface class MangaDownloadLibrary implements Listenable {
  List<MangaDownloadTask> get tasks;
  List<DownloadedMangaComic> get downloadedComics;

  Future<void> ensureInitialized();
  Future<Set<String>> checkDownloadedIntegrity();
  Future<MangaDownloadedScanResult> scanDownloadedComics();
  Future<void> deleteDownloadedComics(Iterable<String> comicIds);
  Future<void> pauseTask(String storageKey);
  Future<void> resumeTask(String storageKey);
  Future<void> pauseAllTasks();
  Future<void> resumeAllTasks();
  Future<void> deleteTask(String storageKey);
}
