import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hazuki_models.dart';
import 'hazuki_source_service.dart';

enum MangaDownloadTaskStatus {
  queued,
  downloading,
  paused,
  failed,
}

MangaDownloadTaskStatus _mangaDownloadTaskStatusFromRaw(String? raw) {
  return switch (raw) {
    'downloading' => MangaDownloadTaskStatus.downloading,
    'paused' => MangaDownloadTaskStatus.paused,
    'failed' => MangaDownloadTaskStatus.failed,
    _ => MangaDownloadTaskStatus.queued,
  };
}

class MangaChapterDownloadTarget {
  const MangaChapterDownloadTarget({
    required this.epId,
    required this.title,
    required this.index,
  });

  final String epId;
  final String title;
  final int index;

  Map<String, dynamic> toJson() => {
    'epId': epId,
    'title': title,
    'index': index,
  };

  factory MangaChapterDownloadTarget.fromJson(Map<String, dynamic> map) {
    return MangaChapterDownloadTarget(
      epId: (map['epId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      index: (map['index'] as num?)?.toInt() ?? 0,
    );
  }
}

class MangaDownloadTask {
  const MangaDownloadTask({
    required this.comicId,
    required this.title,
    required this.subTitle,
    required this.description,
    required this.coverUrl,
    required this.targets,
    required this.completedEpIds,
    required this.status,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.currentChapterEpId,
    this.currentChapterTitle,
    this.currentImageIndex = 0,
    this.currentImageTotal = 0,
    this.completedImageFileNames = const <String>[],
    this.errorMessage,
  });

  final String comicId;
  final String title;
  final String subTitle;
  final String description;
  final String coverUrl;
  final List<MangaChapterDownloadTarget> targets;
  final Set<String> completedEpIds;
  final MangaDownloadTaskStatus status;
  final int createdAtMillis;
  final int updatedAtMillis;
  final String? currentChapterEpId;
  final String? currentChapterTitle;
  final int currentImageIndex;
  final int currentImageTotal;
  final List<String> completedImageFileNames;
  final String? errorMessage;

  int get totalCount => targets.length;
  int get completedCount => completedEpIds.length;
  int get resumedImageCount => completedImageFileNames.length;
  double get progressValue {
    if (targets.isEmpty) {
      return 0;
    }
    final effectiveImageIndex = currentImageIndex > resumedImageCount
        ? currentImageIndex
        : resumedImageCount;
    final chapterFraction = currentImageTotal > 0
        ? (effectiveImageIndex / currentImageTotal).clamp(0.0, 1.0)
        : 0.0;
    return ((completedCount + chapterFraction) / totalCount).clamp(0.0, 1.0);
  }

  MangaDownloadTask copyWith({
    List<MangaChapterDownloadTarget>? targets,
    Set<String>? completedEpIds,
    MangaDownloadTaskStatus? status,
    int? updatedAtMillis,
    String? currentChapterEpId,
    String? currentChapterTitle,
    int? currentImageIndex,
    int? currentImageTotal,
    List<String>? completedImageFileNames,
    String? errorMessage,
    bool clearCurrentChapterEpId = false,
    bool clearCurrentChapterTitle = false,
    bool clearCompletedImageFileNames = false,
    bool clearErrorMessage = false,
  }) {
    return MangaDownloadTask(
      comicId: comicId,
      title: title,
      subTitle: subTitle,
      description: description,
      coverUrl: coverUrl,
      targets: targets ?? this.targets,
      completedEpIds: completedEpIds ?? this.completedEpIds,
      status: status ?? this.status,
      createdAtMillis: createdAtMillis,
      updatedAtMillis:
          updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
      currentChapterEpId: clearCurrentChapterEpId
          ? null
          : (currentChapterEpId ?? this.currentChapterEpId),
      currentChapterTitle: clearCurrentChapterTitle
          ? null
          : (currentChapterTitle ?? this.currentChapterTitle),
      currentImageIndex: currentImageIndex ?? this.currentImageIndex,
      currentImageTotal: currentImageTotal ?? this.currentImageTotal,
      completedImageFileNames: clearCompletedImageFileNames
          ? const <String>[]
          : (completedImageFileNames ?? this.completedImageFileNames),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() => {
    'comicId': comicId,
    'title': title,
    'subTitle': subTitle,
    'description': description,
    'coverUrl': coverUrl,
    'targets': targets.map((e) => e.toJson()).toList(),
    'completedEpIds': completedEpIds.toList(),
    'status': status.name,
    'createdAtMillis': createdAtMillis,
    'updatedAtMillis': updatedAtMillis,
    'currentChapterEpId': currentChapterEpId,
    'currentChapterTitle': currentChapterTitle,
    'currentImageIndex': currentImageIndex,
    'currentImageTotal': currentImageTotal,
    'completedImageFileNames': completedImageFileNames,
    'errorMessage': errorMessage,
  };

  factory MangaDownloadTask.fromJson(Map<String, dynamic> map) {
    final targetsRaw = map['targets'];
    final targets = <MangaChapterDownloadTarget>[];
    if (targetsRaw is List) {
      for (final item in targetsRaw) {
        if (item is Map) {
          targets.add(
            MangaChapterDownloadTarget.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final completedRaw = map['completedEpIds'];
    final completedEpIds = <String>{};
    if (completedRaw is List) {
      for (final item in completedRaw) {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          completedEpIds.add(value);
        }
      }
    }
    final completedImageFileNames = <String>[];
    final completedImagesRaw = map['completedImageFileNames'];
    if (completedImagesRaw is List) {
      for (final item in completedImagesRaw) {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          completedImageFileNames.add(value);
        }
      }
    }
    return MangaDownloadTask(
      comicId: (map['comicId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subTitle: (map['subTitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      targets: targets,
      completedEpIds: completedEpIds,
      status: _mangaDownloadTaskStatusFromRaw(map['status']?.toString()),
      createdAtMillis: (map['createdAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAtMillis: (map['updatedAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      currentChapterEpId: map['currentChapterEpId']?.toString(),
      currentChapterTitle: map['currentChapterTitle']?.toString(),
      currentImageIndex: (map['currentImageIndex'] as num?)?.toInt() ?? 0,
      currentImageTotal: (map['currentImageTotal'] as num?)?.toInt() ?? 0,
      completedImageFileNames: completedImageFileNames,
      errorMessage: map['errorMessage']?.toString(),
    );
  }
}

class DownloadedMangaChapter {
  const DownloadedMangaChapter({
    required this.epId,
    required this.title,
    required this.index,
    required this.imagePaths,
  });

  final String epId;
  final String title;
  final int index;
  final List<String> imagePaths;

  Map<String, dynamic> toJson() => {
    'epId': epId,
    'title': title,
    'index': index,
    'imagePaths': imagePaths,
  };

  factory DownloadedMangaChapter.fromJson(Map<String, dynamic> map) {
    final imagePaths = <String>[];
    final rawPaths = map['imagePaths'];
    if (rawPaths is List) {
      for (final item in rawPaths) {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          imagePaths.add(value);
        }
      }
    }
    return DownloadedMangaChapter(
      epId: (map['epId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      index: (map['index'] as num?)?.toInt() ?? 0,
      imagePaths: imagePaths,
    );
  }
}

class DownloadedMangaComic {
  const DownloadedMangaComic({
    required this.comicId,
    required this.title,
    required this.subTitle,
    required this.description,
    required this.coverUrl,
    required this.localCoverPath,
    required this.chapters,
    required this.updatedAtMillis,
  });

  final String comicId;
  final String title;
  final String subTitle;
  final String description;
  final String coverUrl;
  final String? localCoverPath;
  final List<DownloadedMangaChapter> chapters;
  final int updatedAtMillis;

  DownloadedMangaComic copyWith({
    String? localCoverPath,
    List<DownloadedMangaChapter>? chapters,
    int? updatedAtMillis,
  }) {
    return DownloadedMangaComic(
      comicId: comicId,
      title: title,
      subTitle: subTitle,
      description: description,
      coverUrl: coverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      chapters: chapters ?? this.chapters,
      updatedAtMillis:
          updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'comicId': comicId,
    'title': title,
    'subTitle': subTitle,
    'description': description,
    'coverUrl': coverUrl,
    'localCoverPath': localCoverPath,
    'chapters': chapters.map((e) => e.toJson()).toList(),
    'updatedAtMillis': updatedAtMillis,
  };

  factory DownloadedMangaComic.fromJson(Map<String, dynamic> map) {
    final chapters = <DownloadedMangaChapter>[];
    final raw = map['chapters'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          chapters.add(
            DownloadedMangaChapter.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    chapters.sort((a, b) => a.index.compareTo(b.index));
    return DownloadedMangaComic(
      comicId: (map['comicId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subTitle: (map['subTitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      localCoverPath: map['localCoverPath']?.toString(),
      chapters: chapters,
      updatedAtMillis: (map['updatedAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class MangaDownloadService extends ChangeNotifier {
  MangaDownloadService._();

  static final MangaDownloadService instance = MangaDownloadService._();

  static const String _statePrefsKey = 'manga_download_service_state_v1';
  static const String _metadataFileName = 'metadata.json';

  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  bool _processing = false;
  final List<MangaDownloadTask> _tasks = <MangaDownloadTask>[];
  final List<DownloadedMangaComic> _downloaded = <DownloadedMangaComic>[];

  List<MangaDownloadTask> get tasks => List<MangaDownloadTask>.unmodifiable(
    _tasks,
  );
  List<DownloadedMangaComic> get downloadedComics =>
      List<DownloadedMangaComic>.unmodifiable(_downloaded);

  Future<void> ensureInitialized() async {
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _init();
    _initFuture = future;
    await future;
  }

  DownloadedMangaComic? downloadedComicById(String comicId) {
    for (final item in _downloaded) {
      if (item.comicId == comicId) {
        return item;
      }
    }
    return null;
  }

  MangaDownloadTask? taskByComicId(String comicId) {
    for (final item in _tasks) {
      if (item.comicId == comicId) {
        return item;
      }
    }
    return null;
  }

  Future<void> enqueueDownload({
    required ComicDetailsData details,
    required String coverUrl,
    required String description,
    required List<MangaChapterDownloadTarget> chapters,
  }) async {
    if (chapters.isEmpty) {
      return;
    }
    await ensureInitialized();
    final existingDownloaded = downloadedComicById(details.id);
    final downloadedEpIds = existingDownloaded == null
        ? <String>{}
        : existingDownloaded.chapters.map((e) => e.epId).toSet();

    final normalizedTargets = <MangaChapterDownloadTarget>[];
    final seen = <String>{};
    for (final target in chapters) {
      if (target.epId.isEmpty ||
          downloadedEpIds.contains(target.epId) ||
          !seen.add(target.epId)) {
        continue;
      }
      normalizedTargets.add(target);
    }
    if (normalizedTargets.isEmpty) {
      return;
    }

    final existingTaskIndex = _tasks.indexWhere(
      (task) => task.comicId == details.id,
    );
    if (existingTaskIndex >= 0) {
      final task = _tasks[existingTaskIndex];
      final merged = <MangaChapterDownloadTarget>[
        ...task.targets,
        ...normalizedTargets.where(
          (target) => !task.targets.any((item) => item.epId == target.epId),
        ),
      ]..sort((a, b) => a.index.compareTo(b.index));
      _tasks[existingTaskIndex] = task.copyWith(
        targets: merged,
        status: MangaDownloadTaskStatus.queued,
        clearErrorMessage: true,
      );
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      _tasks.add(
        MangaDownloadTask(
          comicId: details.id,
          title: details.title,
          subTitle: details.subTitle,
          description: description,
          coverUrl: coverUrl,
          targets: normalizedTargets..sort((a, b) => a.index.compareTo(b.index)),
          completedEpIds: <String>{},
          status: MangaDownloadTaskStatus.queued,
          createdAtMillis: now,
          updatedAtMillis: now,
        ),
      );
    }
    await _persistState();
    notifyListeners();
    unawaited(_processQueue());
  }

  Future<void> deleteDownloadedComics(Iterable<String> comicIds) async {
    await ensureInitialized();
    final ids = comicIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return;
    }
    final rootDir = await _ensureRootDir();
    for (final comicId in ids) {
      try {
        final dir = Directory('${rootDir.path}/$comicId');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
    _downloaded.removeWhere((item) => ids.contains(item.comicId));
    await _persistState();
    notifyListeners();
  }

  Future<void> pauseTask(String comicId) async {
    await ensureInitialized();
    final latest = _latestTask(comicId);
    if (latest == null || latest.status == MangaDownloadTaskStatus.paused) {
      return;
    }
    if (!_replaceTask(
      comicId,
      latest.copyWith(
        status: MangaDownloadTaskStatus.paused,
      ),
    )) {
      return;
    }
    await _persistState();
    notifyListeners();
  }

  Future<void> resumeTask(String comicId) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.queued,
      clearErrorMessage: true,
    );
    await _persistState();
    notifyListeners();
    unawaited(_processQueue());
  }

  Future<void> deleteTask(String comicId) async {
    await ensureInitialized();
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return;
    }
    final task = _tasks.removeAt(index);
    final rootDir = await _ensureRootDir();
    final comicDir = Directory('${rootDir.path}/${task.comicId}');
    final wasDownloading = task.status == MangaDownloadTaskStatus.downloading;
    if (task.currentChapterEpId?.isNotEmpty == true) {
      try {
        final chapterDir = Directory('${comicDir.path}/${task.currentChapterEpId}');
        if (await chapterDir.exists()) {
          await chapterDir.delete(recursive: true);
        }
      } catch (_) {}
    }
    if (!wasDownloading && downloadedComicById(task.comicId) == null) {
      try {
        if (await comicDir.exists()) {
          await comicDir.delete(recursive: true);
        }
      } catch (_) {}
    }
    await _persistState();
    notifyListeners();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final rootDir = await _ensureRootDir();
    final raw = _prefs?.getString(_statePrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final tasksRaw = map['tasks'];
          if (tasksRaw is List) {
            for (final item in tasksRaw) {
              if (item is Map) {
                var task = MangaDownloadTask.fromJson(Map<String, dynamic>.from(item));
                if (task.status == MangaDownloadTaskStatus.downloading) {
                  task = task.copyWith(status: MangaDownloadTaskStatus.queued);
                }
                _tasks.add(task);
              }
            }
          }
          final downloadedRaw = map['downloaded'];
          if (downloadedRaw is List) {
            for (final item in downloadedRaw) {
              if (item is Map) {
                _downloaded.add(
                  DownloadedMangaComic.fromJson(Map<String, dynamic>.from(item)),
                );
              }
            }
          }
        }
      } catch (_) {}
    }
    await _scanExistingDownloadedComics(rootDir);
    _tasks.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    _downloaded.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    await _persistState();
    if (_tasks.isNotEmpty) {
      unawaited(_processQueue());
    }
  }

  Future<Directory> _ensureRootDir() async {
    final dir = Directory('/storage/emulated/0/Download/Hazuki_Manga');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _persistState() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final payload = {
      'tasks': _tasks.map((e) => e.toJson()).toList(),
      'downloaded': _downloaded.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_statePrefsKey, jsonEncode(payload));
  }

  Future<void> _processQueue() async {
    if (_processing) {
      return;
    }
    _processing = true;
    try {
      while (true) {
        final taskIndex = _tasks.indexWhere(
          (task) => task.status == MangaDownloadTaskStatus.queued,
        );
        if (taskIndex < 0) {
          break;
        }
        await _runTask(taskIndex);
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _runTask(int taskIndex) async {
    if (taskIndex < 0 || taskIndex >= _tasks.length) {
      return;
    }
    var task = _tasks[taskIndex].copyWith(
      status: MangaDownloadTaskStatus.downloading,
      clearErrorMessage: true,
    );
    if (!_replaceTask(task.comicId, task)) {
      return;
    }
    await _persistState();
    notifyListeners();

    try {
      final rootDir = await _ensureRootDir();
      final comicDir = Directory('${rootDir.path}/${task.comicId}');
      if (!await comicDir.exists()) {
        await comicDir.create(recursive: true);
      }

      var downloadedComic = downloadedComicById(task.comicId) ??
          DownloadedMangaComic(
            comicId: task.comicId,
            title: task.title,
            subTitle: task.subTitle,
            description: task.description,
            coverUrl: task.coverUrl,
            localCoverPath: null,
            chapters: const <DownloadedMangaChapter>[],
            updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
          );

      final localCoverPath = await _downloadCoverIfNeeded(
        task: task,
        comicDir: comicDir,
      );
      downloadedComic = downloadedComic.copyWith(localCoverPath: localCoverPath);

      final downloadedChapters = <DownloadedMangaChapter>[
        ...downloadedComic.chapters,
      ];
      final existingChapterIds = downloadedChapters.map((e) => e.epId).toSet();
      final sourceService = HazukiSourceService.instance;

      for (final target in task.targets) {
        if (await _shouldAbortTask(task.comicId)) {
          await _cleanupTaskChapterDir(
            comicDir.path,
            _latestTask(task.comicId)?.currentChapterEpId,
          );
          return;
        }
        if (existingChapterIds.contains(target.epId)) {
          if (!_updateTaskFromLatest(task.comicId, (latest) {
            task = latest.copyWith(
              completedEpIds: {...latest.completedEpIds, target.epId},
            );
            return task;
          })) {
            return;
          }
          continue;
        }

        final imageUrls = await sourceService.loadChapterImages(
          comicId: task.comicId,
          epId: target.epId,
        );
        final chapterDir = Directory('${comicDir.path}/${target.epId}');
        if (!await chapterDir.exists()) {
          await chapterDir.create(recursive: true);
        }

        final existingFileNames = await _listExistingChapterImageFileNames(
          chapterDir,
        );
        final resumableEntries = <MapEntry<String, int>>[];
        for (final fileName in existingFileNames) {
          final imageIndex = _parseDownloadedImageIndex(fileName);
          if (imageIndex == null || imageIndex >= imageUrls.length) {
            continue;
          }
          resumableEntries.add(MapEntry(fileName, imageIndex));
        }
        resumableEntries.sort((a, b) => a.value.compareTo(b.value));
        final resumableFileNames = resumableEntries.map((entry) => entry.key).toList();
        final resumedSavedPaths = resumableFileNames
            .map((name) => '${chapterDir.path}/$name')
            .toList();
        final completedIndexes = resumableEntries
            .map((entry) => entry.value)
            .toSet();
        final savedPaths = <String>[...resumedSavedPaths];
        if (!_updateTaskFromLatest(task.comicId, (latest) {
          task = latest.copyWith(
            currentChapterEpId: target.epId,
            currentChapterTitle: target.title,
            currentImageIndex: resumedSavedPaths.length,
            currentImageTotal: imageUrls.length,
            completedImageFileNames: resumableFileNames,
          );
          return task;
        })) {
          return;
        }
        await _persistState();
        notifyListeners();
        for (var i = 0; i < imageUrls.length; i++) {
          if (completedIndexes.contains(i)) {
            continue;
          }
          if (await _shouldAbortTask(task.comicId)) {
            return;
          }
          final imageUrl = imageUrls[i];
          final prepared = await sourceService.prepareChapterImageData(
            imageUrl,
            comicId: task.comicId,
            epId: target.epId,
          );
          final fileName =
              '${(i + 1).toString().padLeft(4, '0')}.${prepared.extension}';
          final file = File('${chapterDir.path}/$fileName');
          await file.writeAsBytes(prepared.bytes, flush: true);
          savedPaths.add(file.path);
          completedIndexes.add(i);
          final nextCompletedFileNames = [
            ...?(_latestTask(task.comicId)?.completedImageFileNames),
          ];
          if (!nextCompletedFileNames.contains(fileName)) {
            nextCompletedFileNames.add(fileName);
            nextCompletedFileNames.sort();
          }
          if (await _shouldAbortTask(task.comicId)) {
            return;
          }
          if (!_updateTaskFromLatest(task.comicId, (latest) {
            task = latest.copyWith(
              currentChapterEpId: target.epId,
              currentChapterTitle: target.title,
              currentImageIndex: nextCompletedFileNames.length,
              currentImageTotal: imageUrls.length,
              completedImageFileNames: nextCompletedFileNames,
            );
            return task;
          })) {
            return;
          }
          await _persistState();
          notifyListeners();
        }

        savedPaths.sort();
        downloadedChapters.add(
          DownloadedMangaChapter(
            epId: target.epId,
            title: target.title,
            index: target.index,
            imagePaths: savedPaths,
          ),
        );
        downloadedChapters.sort((a, b) => a.index.compareTo(b.index));

        if (!_updateTaskFromLatest(task.comicId, (latest) {
          task = latest.copyWith(
            completedEpIds: {...latest.completedEpIds, target.epId},
            clearCurrentChapterEpId: true,
            clearCurrentChapterTitle: true,
            currentImageIndex: 0,
            currentImageTotal: 0,
            clearCompletedImageFileNames: true,
          );
          return task;
        })) {
          return;
        }

        downloadedComic = downloadedComic.copyWith(
          chapters: downloadedChapters,
          updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
        );
        _upsertDownloadedComic(downloadedComic);
        await _writeMetadataFile(comicDir, downloadedComic);
        await _persistState();
        notifyListeners();
      }

      _removeTaskByComicId(task.comicId);
      _upsertDownloadedComic(downloadedComic);
      await _writeMetadataFile(comicDir, downloadedComic);
      await _persistState();
      notifyListeners();
    } catch (e) {
      final latest = _latestTask(task.comicId);
      if (latest == null) {
        return;
      }
      _replaceTask(
        task.comicId,
        latest.copyWith(
          status: MangaDownloadTaskStatus.failed,
          errorMessage: e.toString(),
        ),
      );
      await _persistState();
      notifyListeners();
    }
  }

  bool _updateTaskFromLatest(
    String comicId,
    MangaDownloadTask Function(MangaDownloadTask latest) transform,
  ) {
    final latest = _latestTask(comicId);
    if (latest == null || latest.status == MangaDownloadTaskStatus.paused) {
      return false;
    }
    return _replaceTask(comicId, transform(latest));
  }

  bool _replaceTask(String comicId, MangaDownloadTask next) {
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return false;
    }
    _tasks[index] = next;
    return true;
  }

  bool _removeTaskByComicId(String comicId) {
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return false;
    }
    _tasks.removeAt(index);
    return true;
  }

  MangaDownloadTask? _latestTask(String comicId) {
    for (final item in _tasks) {
      if (item.comicId == comicId) {
        return item;
      }
    }
    return null;
  }

  Future<bool> _shouldAbortTask(String comicId) async {
    final latest = _latestTask(comicId);
    if (latest == null) {
      return true;
    }
    return latest.status == MangaDownloadTaskStatus.paused;
  }

  Future<void> _cleanupTaskChapterDir(
    String comicDirPath,
    String? chapterEpId,
  ) async {
    final normalized = chapterEpId?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    try {
      final chapterDir = Directory('$comicDirPath/$normalized');
      if (await chapterDir.exists()) {
        await chapterDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<List<String>> _listExistingChapterImageFileNames(Directory chapterDir) async {
    if (!await chapterDir.exists()) {
      return const <String>[];
    }
    final names = <String>[];
    await for (final entity in chapterDir.list()) {
      if (entity is! File) {
        continue;
      }
      final segments = entity.path.split(RegExp(r'[\\/]'));
      if (segments.isEmpty) {
        continue;
      }
      final name = segments.last.trim();
      if (RegExp(r'^\d{4}\.[A-Za-z0-9]+$').hasMatch(name)) {
        names.add(name);
      }
    }
    names.sort();
    return names;
  }

  int? _parseDownloadedImageIndex(String fileName) {
    final match = RegExp(r'^(\d{4})\.[A-Za-z0-9]+$').firstMatch(fileName.trim());
    if (match == null) {
      return null;
    }
    final sequence = int.tryParse(match.group(1) ?? '');
    if (sequence == null || sequence <= 0) {
      return null;
    }
    return sequence - 1;
  }

  Future<String?> _downloadCoverIfNeeded({
    required MangaDownloadTask task,
    required Directory comicDir,
  }) async {
    final normalized = task.coverUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final existing = File('${comicDir.path}/cover.jpg');
    if (await existing.exists()) {
      return existing.path;
    }
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalized,
        keepInMemory: false,
      );
      await existing.writeAsBytes(bytes, flush: true);
      return existing.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _scanExistingDownloadedComics(Directory rootDir) async {
    if (!await rootDir.exists()) {
      return;
    }
    await for (final entity in rootDir.list()) {
      if (entity is! Directory) {
        continue;
      }
      final comic = await _loadDownloadedComicFromDirectory(entity);
      if (comic == null) {
        continue;
      }
      _upsertDownloadedComic(comic);
    }
  }

  Future<DownloadedMangaComic?> _loadDownloadedComicFromDirectory(
    Directory comicDir,
  ) async {
    final metadataFile = File('${comicDir.path}/$_metadataFileName');
    if (await metadataFile.exists()) {
      try {
        final raw = await metadataFile.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final comic = DownloadedMangaComic.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          return comic.copyWith(
            localCoverPath: await _resolveLocalCoverPath(comicDir),
            updatedAtMillis: await _resolveDirectoryUpdatedAtMillis(comicDir),
          );
        }
      } catch (_) {}
    }

    final chapters = await _scanDownloadedChapters(comicDir);
    final localCoverPath = await _resolveLocalCoverPath(comicDir);
    if (chapters.isEmpty && localCoverPath == null) {
      return null;
    }

    return DownloadedMangaComic(
      comicId: _lastPathSegment(comicDir.path),
      title: _lastPathSegment(comicDir.path),
      subTitle: '',
      description: '',
      coverUrl: '',
      localCoverPath: localCoverPath,
      chapters: chapters,
      updatedAtMillis: await _resolveDirectoryUpdatedAtMillis(comicDir),
    );
  }

  Future<List<DownloadedMangaChapter>> _scanDownloadedChapters(
    Directory comicDir,
  ) async {
    final chapters = <DownloadedMangaChapter>[];
    await for (final entity in comicDir.list()) {
      if (entity is! Directory) {
        continue;
      }
      final epId = _lastPathSegment(entity.path);
      if (epId.isEmpty) {
        continue;
      }
      final fileNames = await _listExistingChapterImageFileNames(entity);
      if (fileNames.isEmpty) {
        continue;
      }
      final imagePaths = fileNames.map((name) => '${entity.path}/$name').toList();
      final chapterIndex = int.tryParse(epId) ?? chapters.length;
      chapters.add(
        DownloadedMangaChapter(
          epId: epId,
          title: epId,
          index: chapterIndex,
          imagePaths: imagePaths,
        ),
      );
    }
    chapters.sort((a, b) {
      final byIndex = a.index.compareTo(b.index);
      if (byIndex != 0) {
        return byIndex;
      }
      return a.epId.compareTo(b.epId);
    });
    return chapters;
  }

  Future<String?> _resolveLocalCoverPath(Directory comicDir) async {
    const candidateNames = <String>[
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'cover.webp',
      'cover.avif',
    ];
    for (final name in candidateNames) {
      final file = File('${comicDir.path}/$name');
      if (await file.exists()) {
        return file.path;
      }
    }
    return null;
  }

  Future<int> _resolveDirectoryUpdatedAtMillis(Directory dir) async {
    try {
      return (await dir.stat()).modified.millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  String _lastPathSegment(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final segments = normalized.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? '' : segments.last.trim();
  }

  void _upsertDownloadedComic(DownloadedMangaComic comic) {
    final index = _downloaded.indexWhere((item) => item.comicId == comic.comicId);
    if (index >= 0) {
      _downloaded[index] = comic;
    } else {
      _downloaded.add(comic);
    }
    _downloaded.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
  }

  Future<void> _writeMetadataFile(
    Directory comicDir,
    DownloadedMangaComic comic,
  ) async {
    final file = File('${comicDir.path}/$_metadataFileName');
    await file.writeAsString(jsonEncode(comic.toJson()), flush: true);
  }
}
