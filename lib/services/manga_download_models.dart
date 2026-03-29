enum MangaDownloadTaskStatus { queued, downloading, paused, failed }

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
      title: (map['title'] ?? '').toString(),
      subTitle: (map['subTitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
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
      updatedAtMillis: updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
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
      updatedAtMillis:
          (map['updatedAtMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

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
