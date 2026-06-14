import '../../models/hazuki_models.dart';

enum MangaDownloadTaskStatus { queued, downloading, paused, failed }

enum MangaDownloadEnqueueResult { queued, alreadyQueued, nothingToQueue }

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

class MangaDownloadConflict {
  const MangaDownloadConflict({
    required this.comicTitle,
    required this.existingChapters,
  });

  final String comicTitle;
  final List<MangaChapterDownloadTarget> existingChapters;

  bool get hasConflict => existingChapters.isNotEmpty;
}

class MangaDownloadTask {
  const MangaDownloadTask({
    required this.comicId,
    this.sourceKey = '',
    required this.title,
    required this.subTitle,
    required this.description,
    required this.coverUrl,
    this.tags = const <String, List<String>>{},
    this.uploader = '',
    this.updateTime = '',
    this.pageCount = '',
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
    this.retryCount = 0,
  });

  final String comicId;
  final String sourceKey;
  final String title;
  final String subTitle;
  final String description;
  final String coverUrl;
  final Map<String, List<String>> tags;
  final String uploader;
  final String updateTime;
  final String pageCount;
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
  final int retryCount;

  String get storageKey =>
      SourceScopedComicId(sourceKey: sourceKey, comicId: comicId).storageKey;

  String get downloadDirName => SourceScopedComicId(
    sourceKey: sourceKey,
    comicId: comicId,
  ).downloadDirName;

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
    String? title,
    String? subTitle,
    String? description,
    String? coverUrl,
    Map<String, List<String>>? tags,
    String? uploader,
    String? updateTime,
    String? pageCount,
    List<MangaChapterDownloadTarget>? targets,
    Set<String>? completedEpIds,
    MangaDownloadTaskStatus? status,
    int? updatedAtMillis,
    String? currentChapterEpId,
    String? currentChapterTitle,
    int? currentImageIndex,
    int? currentImageTotal,
    String? errorMessage,
    int? retryCount,
    bool clearCurrentChapterEpId = false,
    bool clearCurrentChapterTitle = false,
    bool clearErrorMessage = false,
  }) {
    return MangaDownloadTask(
      comicId: comicId,
      sourceKey: sourceKey,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tags: sanitizeMangaDownloadTags(tags ?? this.tags),
      uploader: uploader ?? this.uploader,
      updateTime: updateTime ?? this.updateTime,
      pageCount: pageCount ?? this.pageCount,
      targets: targets ?? this.targets,
      completedEpIds: completedEpIds ?? this.completedEpIds,
      status: status ?? this.status,
      createdAtMillis: createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
      currentChapterEpId: clearCurrentChapterEpId
          ? null
          : (currentChapterEpId ?? this.currentChapterEpId),
      currentChapterTitle: clearCurrentChapterTitle
          ? null
          : (currentChapterTitle ?? this.currentChapterTitle),
      currentImageIndex: currentImageIndex ?? this.currentImageIndex,
      currentImageTotal: currentImageTotal ?? this.currentImageTotal,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'comicId': comicId,
    if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
    'title': title,
    'subTitle': subTitle,
    'description': description,
    'coverUrl': coverUrl,
    'tags': sanitizeMangaDownloadTags(tags),
    'uploader': uploader,
    'updateTime': updateTime,
    'pageCount': pageCount,
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
    'retryCount': retryCount,
  };

  factory MangaDownloadTask.fromJson(Map<String, dynamic> map) {
    final targetsRaw = map['targets'];
    final targets = <MangaChapterDownloadTarget>[];
    if (targetsRaw is List) {
      for (final item in targetsRaw) {
        if (item is Map) {
          targets.add(
            MangaChapterDownloadTarget.fromJson(
              Map<String, dynamic>.from(item),
            ),
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
      sourceKey: (map['sourceKey'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subTitle: (map['subTitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      tags: sanitizeMangaDownloadTags(_stringListMapFromJson(map['tags'])),
      uploader: (map['uploader'] ?? '').toString(),
      updateTime: (map['updateTime'] ?? '').toString(),
      pageCount: (map['pageCount'] ?? '').toString(),
      targets: targets,
      completedEpIds: completedEpIds,
      status: _mangaDownloadTaskStatusFromRaw(map['status']?.toString()),
      createdAtMillis:
          (map['createdAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAtMillis:
          (map['updatedAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      currentChapterEpId: map['currentChapterEpId']?.toString(),
      currentChapterTitle: map['currentChapterTitle']?.toString(),
      currentImageIndex: (map['currentImageIndex'] as num?)?.toInt() ?? 0,
      currentImageTotal: (map['currentImageTotal'] as num?)?.toInt() ?? 0,
      errorMessage: map['errorMessage']?.toString(),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
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
    this.sourceKey = '',
    required this.title,
    required this.subTitle,
    required this.description,
    required this.coverUrl,
    this.tags = const <String, List<String>>{},
    this.uploader = '',
    this.updateTime = '',
    this.pageCount = '',
    required this.localCoverPath,
    required this.chapters,
    required this.updatedAtMillis,
  });

  final String comicId;
  final String sourceKey;
  final String title;
  final String subTitle;
  final String description;
  final String coverUrl;
  final Map<String, List<String>> tags;
  final String uploader;
  final String updateTime;
  final String pageCount;
  final String? localCoverPath;
  final List<DownloadedMangaChapter> chapters;
  final int updatedAtMillis;

  String get storageKey =>
      SourceScopedComicId(sourceKey: sourceKey, comicId: comicId).storageKey;

  String get downloadDirName => SourceScopedComicId(
    sourceKey: sourceKey,
    comicId: comicId,
  ).downloadDirName;

  DownloadedMangaComic copyWith({
    String? sourceKey,
    String? title,
    String? subTitle,
    String? description,
    String? coverUrl,
    Map<String, List<String>>? tags,
    String? uploader,
    String? updateTime,
    String? pageCount,
    String? localCoverPath,
    List<DownloadedMangaChapter>? chapters,
    int? updatedAtMillis,
  }) {
    return DownloadedMangaComic(
      comicId: comicId,
      sourceKey: sourceKey ?? this.sourceKey,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tags: sanitizeMangaDownloadTags(tags ?? this.tags),
      uploader: uploader ?? this.uploader,
      updateTime: updateTime ?? this.updateTime,
      pageCount: pageCount ?? this.pageCount,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      chapters: chapters ?? this.chapters,
      updatedAtMillis: updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  DownloadedMangaComic mergeTaskMetadata(MangaDownloadTask task) {
    String preferTaskValue(String taskValue, String existingValue) =>
        taskValue.trim().isNotEmpty ? taskValue : existingValue;
    final sanitizedTaskTags = sanitizeMangaDownloadTags(task.tags);

    return copyWith(
      title: preferTaskValue(task.title, title),
      subTitle: preferTaskValue(task.subTitle, subTitle),
      description: preferTaskValue(task.description, description),
      coverUrl: preferTaskValue(task.coverUrl, coverUrl),
      tags: sanitizedTaskTags.isNotEmpty ? sanitizedTaskTags : tags,
      uploader: preferTaskValue(task.uploader, uploader),
      updateTime: preferTaskValue(task.updateTime, updateTime),
      pageCount: preferTaskValue(task.pageCount, pageCount),
    );
  }

  Map<String, dynamic> toJson() => {
    'comicId': comicId,
    if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
    'title': title,
    'subTitle': subTitle,
    'description': description,
    'coverUrl': coverUrl,
    'tags': sanitizeMangaDownloadTags(tags),
    'uploader': uploader,
    'updateTime': updateTime,
    'pageCount': pageCount,
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
      sourceKey: (map['sourceKey'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      subTitle: (map['subTitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      tags: sanitizeMangaDownloadTags(_stringListMapFromJson(map['tags'])),
      uploader: (map['uploader'] ?? '').toString(),
      updateTime: (map['updateTime'] ?? '').toString(),
      pageCount: (map['pageCount'] ?? '').toString(),
      localCoverPath: map['localCoverPath']?.toString(),
      chapters: chapters,
      updatedAtMillis:
          (map['updatedAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

Map<String, List<String>> _stringListMapFromJson(Object? raw) {
  if (raw is! Map) {
    return const <String, List<String>>{};
  }
  final result = <String, List<String>>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().trim();
    final value = entry.value;
    if (key.isEmpty || value is! List) {
      continue;
    }
    final values = value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (values.isNotEmpty) {
      result[key] = values;
    }
  }
  return result;
}

Map<String, List<String>> sanitizeMangaDownloadTags(
  Map<String, List<String>> tags,
) {
  final result = <String, List<String>>{};
  for (final entry in tags.entries) {
    final normalizedKey = entry.key.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    if (_mangaDownloadStatisticTagKeys.contains(normalizedKey)) {
      continue;
    }
    result[entry.key] = entry.value;
  }
  return result;
}

const _mangaDownloadStatisticTagKeys = <String>{
  'view',
  'views',
  'viewcount',
  '浏览',
  '浏览量',
  '觀看',
  '觀看量',
  '观看',
  '观看量',
  'like',
  'likes',
  'likecount',
  '点赞',
  '点赞量',
  '點讚',
  '點讚量',
};

class MangaDownloadedScanResult {
  const MangaDownloadedScanResult({
    required this.permissionGranted,
    required this.scannedDirectories,
    required this.recoveredComics,
  });

  final bool permissionGranted;
  final int scannedDirectories;
  final int recoveredComics;
}
