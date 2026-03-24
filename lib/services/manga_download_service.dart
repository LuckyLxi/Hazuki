import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final String? errorMessage;

  int get totalCount => targets.length;
  int get completedCount => completedEpIds.length;
  double get progressValue {
    if (targets.isEmpty) {
      return 0;
    }
    final chapterFraction = currentImageTotal > 0
        ? (currentImageIndex / currentImageTotal).clamp(0.0, 1.0)
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
    String? errorMessage,
    bool clearCurrentChapterEpId = false,
    bool clearCurrentChapterTitle = false,
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

  static const String _statePrefsKey = 'manga_download_service_state_v2';
  static const String _metadataFileName = 'comic.json';
  static const String _legacyMetadataFileName = 'metadata.json';
  static const int _maxNestedComicScanDepth = 3;
  static const MethodChannel _mediaChannel = MethodChannel('hazuki.comics/media');

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

  void _logScan(
    String title, {
    Object? content,
    String level = 'info',
  }) {
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
      content: content,
      source: 'download_scan',
    );
  }

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
    final index = _tasks.indexWhere((item) => item.comicId == comicId);
    if (index < 0) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: MangaDownloadTaskStatus.paused,
    );
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
    final downloadedComic = downloadedComicById(task.comicId);
    if (task.currentChapterEpId?.isNotEmpty == true) {
      try {
        final chapterDir = await _resolveChapterDirForEpId(
          comicDir: comicDir,
          epId: task.currentChapterEpId!,
          targets: task.targets,
          downloadedComic: downloadedComic,
        );
        if (chapterDir != null && await chapterDir.exists()) {
          await chapterDir.delete(recursive: true);
        }
      } catch (_) {}
    }
    if (downloadedComic == null) {
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
    await _ensureAndroidDownloadsAccess();
    final rootDir = await _ensureRootDir();
    final raw = _prefs?.getString(_statePrefsKey);
    _logScan(
      'Downloads scan bootstrap',
      content: {
        'rootDir': rootDir.path,
        'hasPersistedState': raw != null && raw.isNotEmpty,
      },
    );
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final tasksRaw = map['tasks'];
          if (tasksRaw is List) {
            for (final item in tasksRaw) {
              if (item is Map) {
                var task = MangaDownloadTask.fromJson(
                  Map<String, dynamic>.from(item),
                );
                if (task.status == MangaDownloadTaskStatus.downloading) {
                  task = task.copyWith(
                    status: MangaDownloadTaskStatus.queued,
                    clearErrorMessage: true,
                  );
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
          _logScan(
            'Restored persisted download state',
            content: {
              'taskCount': _tasks.length,
              'downloadedCount': _downloaded.length,
            },
          );
        }
      } catch (e) {
        _logScan(
          'Failed to parse persisted download state',
          level: 'warning',
          content: {
            'rootDir': rootDir.path,
            'error': e.toString(),
          },
        );
      }
    }
    await _scanDownloadedFromDisk(rootDir);
    _tasks.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    _downloaded.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    _logScan(
      'Downloads scan finished',
      content: {
        'rootDir': rootDir.path,
        'taskCount': _tasks.length,
        'downloadedCount': _downloaded.length,
      },
    );
    await _persistState();
    if (_tasks.isNotEmpty) {
      unawaited(_processQueue());
    }
  }

  Future<void> _ensureAndroidDownloadsAccess() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final hasAccess =
          await _mediaChannel.invokeMethod<bool>('hasStorageAccess') ?? false;
      if (hasAccess) {
        return;
      }

      _logScan(
        'Requesting Android downloads access',
        level: 'warning',
        content: {
          'path': '/storage/emulated/0/Download/Hazuki_Manga',
        },
      );

      final granted =
          await _mediaChannel.invokeMethod<bool>('requestStorageAccess') ?? false;
      _logScan(
        granted
            ? 'Granted Android downloads access'
            : 'Android downloads access not granted',
        level: granted ? 'info' : 'warning',
        content: {
          'path': '/storage/emulated/0/Download/Hazuki_Manga',
          'granted': granted,
        },
      );
    } on MissingPluginException catch (e) {
      _logScan(
        'Android downloads access channel unavailable',
        level: 'warning',
        content: {'error': e.toString()},
      );
    } catch (e) {
      _logScan(
        'Android downloads access request failed',
        level: 'warning',
        content: {'error': e.toString()},
      );
    }
  }

  Future<Directory> _ensureRootDir() async {
    final dir = Directory('/storage/emulated/0/Download/Hazuki_Manga');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _logScan(
        'Created downloads root directory',
        content: {'path': dir.path},
      );
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
          return;
        }
        if (existingChapterIds.contains(target.epId)) {
          task = task.copyWith(
            completedEpIds: {...task.completedEpIds, target.epId},
          );
          if (!_replaceTask(task.comicId, task)) {
            return;
          }
          continue;
        }

        final imageUrls = await sourceService.loadChapterImages(
          comicId: task.comicId,
          epId: target.epId,
        );
        if (await _shouldAbortTask(task.comicId)) {
          return;
        }
        final chapterDir = _chapterDirForTarget(comicDir, target);
        if (!await chapterDir.exists()) {
          await chapterDir.create(recursive: true);
        }

        final savedPaths = <String>[];
        for (var i = 0; i < imageUrls.length; i++) {
          final existingPath = await _findExistingImagePath(chapterDir, i + 1);
          if (existingPath != null) {
            savedPaths.add(existingPath);
          }
        }
        task = task.copyWith(
          currentChapterEpId: target.epId,
          currentChapterTitle: target.title,
          currentImageIndex: savedPaths.length,
          currentImageTotal: imageUrls.length,
        );
        if (!_replaceTask(task.comicId, task)) {
          return;
        }
        await _persistState();
        notifyListeners();
        for (var i = savedPaths.length; i < imageUrls.length; i++) {
          if (await _shouldAbortTask(task.comicId)) {
            return;
          }
          final imageUrl = imageUrls[i];
          final prepared = await sourceService.prepareChapterImageData(
            imageUrl,
            comicId: task.comicId,
            epId: target.epId,
          );
          if (await _shouldAbortTask(task.comicId)) {
            return;
          }
          final fileName =
              '${(i + 1).toString().padLeft(4, '0')}.${prepared.extension}';
          final file = File('${chapterDir.path}/$fileName');
          await file.writeAsBytes(prepared.bytes, flush: true);
          savedPaths.add(file.path);
          task = task.copyWith(
            currentChapterEpId: target.epId,
            currentChapterTitle: target.title,
            currentImageIndex: i + 1,
            currentImageTotal: imageUrls.length,
          );
          if (!_replaceTask(task.comicId, task)) {
            return;
          }
          await _persistState();
          notifyListeners();
        }

        downloadedChapters.add(
          DownloadedMangaChapter(
            epId: target.epId,
            title: target.title,
            index: target.index,
            imagePaths: savedPaths,
          ),
        );
        downloadedChapters.sort((a, b) => a.index.compareTo(b.index));

        task = task.copyWith(
          completedEpIds: {...task.completedEpIds, target.epId},
          clearCurrentChapterEpId: true,
          clearCurrentChapterTitle: true,
          currentImageIndex: 0,
          currentImageTotal: 0,
        );
        if (!_replaceTask(task.comicId, task)) {
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
          clearCurrentChapterEpId: true,
          clearCurrentChapterTitle: true,
          currentImageIndex: 0,
          currentImageTotal: 0,
          errorMessage: e.toString(),
        ),
      );
      await _persistState();
      notifyListeners();
    }
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

  Directory _chapterDirForTarget(
    Directory comicDir,
    MangaChapterDownloadTarget target,
  ) {
    final chapterNumber = (target.index + 1).toString().padLeft(3, '0');
    final dirName = 'Manga第$chapterNumber话';
    return Directory('${comicDir.path}/$dirName');
  }

  Future<Directory?> _resolveChapterDirForEpId({
    required Directory comicDir,
    required String epId,
    required List<MangaChapterDownloadTarget> targets,
    DownloadedMangaComic? downloadedComic,
  }) async {
    for (final chapter in downloadedComic?.chapters ?? const <DownloadedMangaChapter>[]) {
      if (chapter.epId != epId || chapter.imagePaths.isEmpty) {
        continue;
      }
      final file = File(chapter.imagePaths.first);
      return file.parent;
    }
    for (final target in targets) {
      if (target.epId != epId) {
        continue;
      }
      final dir = _chapterDirForTarget(comicDir, target);
      if (await dir.exists()) {
        return dir;
      }
      final legacyDir = await _findChapterDirectoryByIndex(
        target.index,
        comicDir,
      );
      if (legacyDir != null) {
        return legacyDir;
      }
    }
    return null;
  }

  Future<Directory?> _findChapterDirectoryByIndex(
    int chapterIndex,
    Directory comicDir,
  ) async {
    final targetChapterNumber = chapterIndex + 1;
    final directories = await _collectChapterDirectoriesFromDisk(comicDir);
    for (final item in directories) {
      if (item.chapterNumber == targetChapterNumber) {
        return item.directory;
      }
    }
    if (chapterIndex >= 0 && chapterIndex < directories.length) {
      return directories[chapterIndex].directory;
    }
    return null;
  }

  Future<String?> _findExistingImagePath(Directory chapterDir, int imageIndex) async {
    final prefix = '${imageIndex.toString().padLeft(4, '0')}.';
    try {
      await for (final entity in chapterDir.list()) {
        if (entity is! File) {
          continue;
        }
        final name = _entityBaseName(entity);
        if (name.startsWith(prefix)) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _downloadCoverIfNeeded({
    required MangaDownloadTask task,
    required Directory comicDir,
  }) async {
    final normalized = task.coverUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final existing = await _findLocalCoverFile(comicDir);
    if (existing != null) {
      return existing.path;
    }
    final target = File('${comicDir.path}/漫画封面.jpg');
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalized,
        keepInMemory: false,
      );
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
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
    final legacy = File('${comicDir.path}/$_legacyMetadataFileName');
    if (await legacy.exists()) {
      try {
        await legacy.delete();
      } catch (_) {}
    }
  }

  Future<void> _scanDownloadedFromDisk(Directory rootDir) async {
    var scannedDirectories = 0;
    var recoveredComics = 0;
    _logScan(
      'Scanning downloads root directory',
      content: {'path': rootDir.path},
    );
    try {
      await for (final entity in rootDir.list()) {
        if (entity is! Directory) {
          continue;
        }
        scannedDirectories++;
        _logScan(
          'Scanning comic directory',
          content: {
            'path': entity.path,
            'name': _entityBaseName(entity),
          },
        );
        final comic = await _readComicFromDirectory(entity);
        if (comic != null) {
          recoveredComics++;
          _upsertDownloadedComic(comic);
          _logScan(
            'Recovered downloaded comic',
            content: {
              'path': entity.path,
              'comicId': comic.comicId,
              'title': comic.title,
              'chapterCount': comic.chapters.length,
              'hasCover': comic.localCoverPath != null,
            },
          );
        } else {
          _logScan(
            'Skipped comic directory',
            level: 'warning',
            content: {
              'path': entity.path,
              'reason': 'no_metadata_and_no_images',
            },
          );
        }
      }
      _logScan(
        'Completed downloads root directory scan',
        content: {
          'path': rootDir.path,
          'scannedDirectories': scannedDirectories,
          'recoveredComics': recoveredComics,
        },
      );
    } catch (e) {
      _logScan(
        'Downloads root directory scan failed',
        level: 'error',
        content: {
          'path': rootDir.path,
          'scannedDirectories': scannedDirectories,
          'recoveredComics': recoveredComics,
          'error': e.toString(),
        },
      );
    }
  }

  Future<DownloadedMangaComic?> _readComicFromDirectory(Directory comicDir) async {
    final metadataFile = await _findMetadataFile(comicDir);
    if (metadataFile == null) {
      _logScan(
        'Metadata file not found, using fallback scan',
        level: 'warning',
        content: {'comicDir': comicDir.path},
      );
      return _fallbackDownloadedComicFromDirectory(comicDir);
    }
    try {
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map) {
        _logScan(
          'Metadata file format invalid, using fallback scan',
          level: 'warning',
          content: {
            'comicDir': comicDir.path,
            'metadataFile': metadataFile.path,
          },
        );
        return _fallbackDownloadedComicFromDirectory(comicDir);
      }
      final comic = DownloadedMangaComic.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final normalizedCoverPath = await _normalizeCoverPath(
        comicDir,
        comic.localCoverPath,
      );
      final normalizedChapters = await _normalizeChapterPaths(
        comicDir: comicDir,
        chapters: comic.chapters,
      );
      final scannedChapters = await _scanChapterDirectoriesFromDisk(comicDir);
      final normalized = _sanitizeRecoveredComic(
        comicId: _baseNameFromPath(comicDir.path),
        comic: comic,
        localCoverPath: normalizedCoverPath,
        chapters: _mergeRecoveredChapters(
          normalizedChapters: normalizedChapters,
          scannedChapters: scannedChapters,
        ),
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _restoreDownloadedComicMetadata(comicDir, normalized);
      _logScan(
        'Metadata-based recovery succeeded',
        content: {
          'comicDir': comicDir.path,
          'metadataFile': metadataFile.path,
          'comicId': normalized.comicId,
          'normalizedChapterCount': normalizedChapters.length,
          'scannedChapterCount': scannedChapters.length,
          'mergedChapterCount': normalized.chapters.length,
          'hasCover': normalized.localCoverPath != null,
        },
      );
      return normalized;
    } catch (e) {
      _logScan(
        'Metadata read failed, using fallback scan',
        level: 'warning',
        content: {
          'comicDir': comicDir.path,
          'metadataFile': metadataFile.path,
          'error': e.toString(),
        },
      );
      return _fallbackDownloadedComicFromDirectory(comicDir);
    }
  }

  Future<DownloadedMangaComic?> _fallbackDownloadedComicFromDirectory(
    Directory comicDir,
  ) async {
    final comicId = _baseNameFromPath(comicDir.path);
    if (comicId.isEmpty) {
      _logScan(
        'Fallback scan skipped because comic directory name is empty',
        level: 'warning',
        content: {'comicDir': comicDir.path},
      );
      return null;
    }

    final chapters = await _scanChapterDirectoriesFromDisk(comicDir);
    final localCover = await _findLocalCoverFile(comicDir);
    if (chapters.isEmpty && localCover == null) {
      _logScan(
        'Fallback scan found no chapters or cover',
        level: 'warning',
        content: {
          'comicDir': comicDir.path,
          'comicId': comicId,
        },
      );
      return null;
    }

    final rebuilt = DownloadedMangaComic(
      comicId: comicId,
      title: comicId,
      subTitle: '',
      description: '',
      coverUrl: '',
      localCoverPath: localCover?.path,
      chapters: chapters,
      updatedAtMillis: await _readUpdatedAtMillis(comicDir),
    );
    await _restoreDownloadedComicMetadata(comicDir, rebuilt);
    _logScan(
      'Fallback recovery succeeded',
      content: {
        'comicDir': comicDir.path,
        'comicId': comicId,
        'chapterCount': chapters.length,
        'hasCover': localCover != null,
      },
    );
    return rebuilt;
  }

  Future<void> _restoreDownloadedComicMetadata(
    Directory comicDir,
    DownloadedMangaComic comic,
  ) async {
    try {
      await _writeMetadataFile(comicDir, comic);
    } catch (_) {}
  }

  List<DownloadedMangaChapter> _mergeRecoveredChapters({
    required List<DownloadedMangaChapter> normalizedChapters,
    required List<DownloadedMangaChapter> scannedChapters,
  }) {
    if (normalizedChapters.isEmpty && scannedChapters.isEmpty) {
      return const <DownloadedMangaChapter>[];
    }

    final scannedByIndex = <int, DownloadedMangaChapter>{
      for (final chapter in scannedChapters) chapter.index: chapter,
    };
    final merged = <DownloadedMangaChapter>[];
    final usedIndexes = <int>{};

    for (final chapter in normalizedChapters) {
      merged.add(
        _sanitizeRecoveredChapter(
          chapter,
          fallback: scannedByIndex[chapter.index],
        ),
      );
      usedIndexes.add(chapter.index);
    }
    for (final chapter in scannedChapters) {
      if (!usedIndexes.add(chapter.index)) {
        continue;
      }
      merged.add(_sanitizeRecoveredChapter(chapter));
    }

    merged.sort((a, b) => a.index.compareTo(b.index));
    return merged;
  }

  DownloadedMangaComic _sanitizeRecoveredComic({
    required String comicId,
    required DownloadedMangaComic comic,
    required String? localCoverPath,
    required List<DownloadedMangaChapter> chapters,
    required int updatedAtMillis,
  }) {
    final normalizedComicId =
        comic.comicId.trim().isNotEmpty ? comic.comicId.trim() : comicId;
    return DownloadedMangaComic(
      comicId: normalizedComicId,
      title: _normalizeRecoveredComicTitle(comic.title, normalizedComicId),
      subTitle: comic.subTitle.trim(),
      description: comic.description.trim(),
      coverUrl: comic.coverUrl.trim(),
      localCoverPath: localCoverPath,
      chapters: chapters,
      updatedAtMillis: updatedAtMillis,
    );
  }

  String _normalizeRecoveredComicTitle(String rawTitle, String comicId) {
    final normalized = rawTitle.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return comicId;
  }

  DownloadedMangaChapter _sanitizeRecoveredChapter(
    DownloadedMangaChapter chapter, {
    DownloadedMangaChapter? fallback,
  }) {
    final normalizedIndex = chapter.index < 0 ? 0 : chapter.index;
    final chapterNumber = normalizedIndex + 1;
    final fallbackEpId = fallback?.epId.trim() ?? '';
    final normalizedEpId = chapter.epId.trim().isNotEmpty
        ? chapter.epId.trim()
        : (fallbackEpId.isNotEmpty ? fallbackEpId : 'local_$chapterNumber');
    return DownloadedMangaChapter(
      epId: normalizedEpId,
      title: _normalizeRecoveredChapterTitle(
        chapter.title,
        chapterNumber: chapterNumber,
        fallbackTitle: fallback?.title,
      ),
      index: normalizedIndex,
      imagePaths: chapter.imagePaths.isNotEmpty
          ? chapter.imagePaths
          : (fallback?.imagePaths ?? const <String>[]),
    );
  }

  String _normalizeRecoveredChapterTitle(
    String rawTitle, {
    required int chapterNumber,
    String? fallbackTitle,
  }) {
    final normalized = rawTitle.trim();
    if (!_isInvalidRecoveredChapterTitle(normalized)) {
      return normalized;
    }
    final normalizedFallback = fallbackTitle?.trim() ?? '';
    if (!_isInvalidRecoveredChapterTitle(normalizedFallback)) {
      return normalizedFallback;
    }
    return '第$chapterNumber话';
  }

  bool _isInvalidRecoveredChapterTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      return true;
    }
    return <RegExp>[
      RegExp(r'^第\s*0+\s*[话話章卷回]$'),
      RegExp(r'^Manga第0+话$', caseSensitive: false),
    ].any((pattern) => pattern.hasMatch(normalized));
  }

  Future<File?> _findMetadataFile(Directory comicDir) async {
    File? current;
    File? legacy;
    try {
      await for (final entity in comicDir.list()) {
        if (entity is! File) {
          continue;
        }
        final fileName = _entityBaseName(entity).toLowerCase();
        if (fileName == _metadataFileName) {
          current ??= entity;
        } else if (fileName == _legacyMetadataFileName) {
          legacy ??= entity;
        }
      }
    } catch (e) {
      _logScan(
        'Metadata file scan failed',
        level: 'warning',
        content: {
          'comicDir': comicDir.path,
          'error': e.toString(),
        },
      );
    }
    return current ?? legacy;
  }

  Future<List<({Directory directory, List<File> files, int? chapterNumber})>>
  _collectChapterDirectoriesFromDisk(Directory comicDir) async {
    final directories = <({Directory directory, List<File> files, int? chapterNumber})>[];
    final seenPaths = <String>{};

    Future<void> visit(Directory parent, int depth) async {
      if (depth > _maxNestedComicScanDepth) {
        return;
      }
      try {
        await for (final entity in parent.list()) {
          if (entity is! Directory) {
            continue;
          }
          final name = _entityBaseName(entity);
          if (name.startsWith('.')) {
            continue;
          }
          final files = await _listImageFiles(
            entity,
            excludeCoverFiles: true,
          );
          if (files.isNotEmpty) {
            if (seenPaths.add(entity.path)) {
              directories.add((
                directory: entity,
                files: files,
                chapterNumber: _extractChapterNumberFromDirectoryName(name),
              ));
            }
            continue;
          }
          await visit(entity, depth + 1);
        }
      } catch (e) {
        _logScan(
          'Chapter directory scan failed',
          level: 'warning',
          content: {
            'parentDir': parent.path,
            'depth': depth,
            'error': e.toString(),
          },
        );
      }
    }

    await visit(comicDir, 1);

    directories.sort((a, b) {
      final aNumber = a.chapterNumber;
      final bNumber = b.chapterNumber;
      if (aNumber != null && bNumber != null) {
        final diff = aNumber.compareTo(bNumber);
        if (diff != 0) {
          return diff;
        }
      } else if (aNumber != null) {
        return -1;
      } else if (bNumber != null) {
        return 1;
      }
      return _entityBaseName(a.directory).compareTo(_entityBaseName(b.directory));
    });

    return directories;
  }

  String _entityBaseName(FileSystemEntity entity) {
    return _baseNameFromPath(entity.path);
  }

  String _baseNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  Future<List<DownloadedMangaChapter>> _scanChapterDirectoriesFromDisk(
    Directory comicDir,
  ) async {
    final directories = await _collectChapterDirectoriesFromDisk(comicDir);

    final chapters = <DownloadedMangaChapter>[];
    final usedChapterNumbers = <int>{};
    var nextFallbackChapterNumber = 1;
    var usedRootFiles = false;
    for (final item in directories) {
      var chapterNumber = item.chapterNumber;
      if (chapterNumber == null ||
          chapterNumber <= 0 ||
          usedChapterNumbers.contains(chapterNumber)) {
        while (usedChapterNumbers.contains(nextFallbackChapterNumber)) {
          nextFallbackChapterNumber++;
        }
        chapterNumber = nextFallbackChapterNumber;
      }
      usedChapterNumbers.add(chapterNumber);
      final name = _entityBaseName(item.directory);
      chapters.add(
        DownloadedMangaChapter(
          epId: 'local_$chapterNumber',
          title: _fallbackChapterTitle(name, chapterNumber),
          index: chapterNumber - 1,
          imagePaths: item.files.map((file) => file.path).toList(),
        ),
      );
    }

    if (chapters.isEmpty) {
      final rootFiles = await _listImageFiles(comicDir, excludeCoverFiles: true);
      if (rootFiles.isNotEmpty) {
        usedRootFiles = true;
        chapters.add(
          DownloadedMangaChapter(
            epId: 'local_1',
            title: '第1话',
            index: 0,
            imagePaths: rootFiles.map((file) => file.path).toList(),
          ),
        );
      }
    }

    chapters.sort((a, b) => a.index.compareTo(b.index));
    _logScan(
      'Scanned chapter directories',
      content: {
        'comicDir': comicDir.path,
        'candidateDirectoryCount': directories.length,
        'chapterCount': chapters.length,
        'usedRootFiles': usedRootFiles,
        'directories': directories
            .map((item) => _entityBaseName(item.directory))
            .take(20)
            .toList(),
      },
    );
    return chapters;
  }

  String _fallbackChapterTitle(String directoryName, int chapterNumber) {
    final normalized = directoryName.trim();
    final separatorIndex = normalized.indexOf('_');
    if (separatorIndex >= 0 && separatorIndex < normalized.length - 1) {
      final legacyTitle = normalized.substring(separatorIndex + 1).trim();
      if (legacyTitle.isNotEmpty) {
        return legacyTitle;
      }
    }
    if (normalized.isNotEmpty) {
      final chapterText = chapterNumber.toString();
      final genericPatterns = <RegExp>[
        RegExp('^Manga第0*$chapterText话\$', caseSensitive: false),
        RegExp('^第0*$chapterText[话話章卷回]\$', caseSensitive: false),
        RegExp('^0*$chapterText\$'),
      ];
      final isGenericDirectoryName = genericPatterns.any(
        (pattern) => pattern.hasMatch(normalized),
      );
      if (!isGenericDirectoryName) {
        return normalized;
      }
    }
    return '第$chapterNumber话';
  }

  Future<int> _readUpdatedAtMillis(Directory directory) async {
    try {
      return (await directory.stat()).modified.millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<String?> _normalizeCoverPath(Directory comicDir, String? currentPath) async {
    final normalized = currentPath?.trim() ?? '';
    if (normalized.isNotEmpty && await File(normalized).exists()) {
      return normalized;
    }
    final file = await _findLocalCoverFile(comicDir);
    return file?.path;
  }

  Future<File?> _findLocalCoverFile(Directory comicDir) async {
    Future<File?> visit(Directory directory, int depth) async {
      if (depth > 2) {
        return null;
      }
      try {
        await for (final entity in directory.list()) {
          if (entity is! File) {
            continue;
          }
          if (_isLocalCoverFileName(_entityBaseName(entity))) {
            return entity;
          }
        }
        await for (final entity in directory.list()) {
          if (entity is! Directory) {
            continue;
          }
          final name = _entityBaseName(entity);
          if (name.startsWith('.')) {
            continue;
          }
          final found = await visit(entity, depth + 1);
          if (found != null) {
            return found;
          }
        }
      } catch (e) {
        _logScan(
          'Cover file scan failed',
          level: 'warning',
          content: {
            'directory': directory.path,
            'depth': depth,
            'error': e.toString(),
          },
        );
      }
      return null;
    }

    return visit(comicDir, 0);
  }

  int? _extractChapterNumberFromDirectoryName(String directoryName) {
    final normalized = directoryName.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final pattern in <RegExp>[
      RegExp(r'^Manga第0*(\d+)话(?:_.+)?$', caseSensitive: false),
      RegExp(r'^第\s*0*(\d+)\s*[话話章卷回](?:_.+)?$', caseSensitive: false),
      RegExp(r'^0*(\d+)(?:$|[_\-\s\.])'),
      RegExp(r'(?<!\d)0*(\d+)(?!\d)'),
    ]) {
      final match = pattern.firstMatch(normalized);
      final value = int.tryParse(match?.group(1) ?? '');
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }

  Future<List<File>> _listImageFiles(
    Directory directory, {
    bool excludeCoverFiles = false,
  }) async {
    final files = <File>[];
    try {
      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }
        final name = _entityBaseName(entity);
        if (!_isImageFileName(name)) {
          continue;
        }
        if (excludeCoverFiles && _isLocalCoverFileName(name)) {
          continue;
        }
        files.add(entity);
      }
    } catch (_) {}
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  bool _isImageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.avif');
  }

  bool _isLocalCoverFileName(String fileName) {
    final normalized = fileName.trim();
    final lower = normalized.toLowerCase();
    return normalized.contains('封面') ||
        lower == '漫画封面.jpg' ||
        lower == '漫画封面.jpeg' ||
        lower == '漫画封面.png' ||
        lower == '漫画封面.webp' ||
        lower == 'cover.jpg' ||
        lower == 'cover.jpeg' ||
        lower == 'cover.png' ||
        lower == 'cover.webp' ||
        lower.startsWith('cover.') ||
        lower.startsWith('comic_cover.') ||
        lower.startsWith('manga_cover.');
  }

  Future<List<DownloadedMangaChapter>> _normalizeChapterPaths({
    required Directory comicDir,
    required List<DownloadedMangaChapter> chapters,
  }) async {
    final normalized = <DownloadedMangaChapter>[];
    for (final chapter in chapters) {
      final collected = <String>[];
      for (final path in chapter.imagePaths) {
        final trimmed = path.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final file = File(trimmed);
        if (await file.exists()) {
          collected.add(file.path);
        }
      }
      if (collected.isEmpty) {
        final chapterDir = await _findChapterDirectoryByChapter(chapter, comicDir);
        if (chapterDir != null) {
          final files = await _listImageFiles(chapterDir);
          collected.addAll(files.map((file) => file.path));
        }
      }
      if (collected.isEmpty) {
        continue;
      }
      normalized.add(
        DownloadedMangaChapter(
          epId: chapter.epId,
          title: chapter.title,
          index: chapter.index,
          imagePaths: collected,
        ),
      );
    }
    normalized.sort((a, b) => a.index.compareTo(b.index));
    return normalized;
  }

  Future<Directory?> _findChapterDirectoryByChapter(
    DownloadedMangaChapter chapter,
    Directory comicDir,
  ) {
    return _findChapterDirectoryByIndex(chapter.index, comicDir);
  }
}
