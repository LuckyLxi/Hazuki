import 'dart:io';

import 'manga_download_models.dart';
import 'manga_download_storage_support.dart';

class MangaDownloadRecoveryDiskSupport {
  MangaDownloadRecoveryDiskSupport({required MangaDownloadLogCallback logScan})
    : _logScan = logScan;

  static const String _metadataFileName = 'comic.json';
  static const String _legacyMetadataFileName = 'metadata.json';
  static const int _maxNestedComicScanDepth = 3;

  final MangaDownloadLogCallback _logScan;

  Future<File?> findMetadataFile(Directory comicDir) async {
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
        content: {'comicDir': comicDir.path, 'error': e.toString()},
      );
    }
    return current ?? legacy;
  }

  Future<Directory?> findChapterDirectoryByIndex(
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

  Future<File?> findLocalCoverFile(Directory comicDir) async {
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

  Future<List<DownloadedMangaChapter>> scanChapterDirectoriesFromDisk(
    Directory comicDir, {
    Set<String> blockedDirectoryPaths = const <String>{},
  }) async {
    final directories = await _collectChapterDirectoriesFromDisk(comicDir);

    final chapters = <DownloadedMangaChapter>[];
    final usedChapterNumbers = <int>{};
    var nextFallbackChapterNumber = 1;
    var usedRootFiles = false;
    var skippedIncompleteDirectories = 0;
    for (final item in directories) {
      if (blockedDirectoryPaths.contains(item.directory.path)) {
        skippedIncompleteDirectories++;
        continue;
      }
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
      final rootFiles = await _listImageFiles(
        comicDir,
        excludeCoverFiles: true,
      );
      if (rootFiles.isNotEmpty) {
        usedRootFiles = true;
        chapters.add(
          DownloadedMangaChapter(
            epId: 'local_1',
            title: 'Chapter 1',
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
        'skippedIncompleteDirectories': skippedIncompleteDirectories,
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

  Future<int> readUpdatedAtMillis(Directory directory) async {
    try {
      return (await directory.stat()).modified.millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<String?> normalizeCoverPath(
    Directory comicDir,
    String? currentPath,
  ) async {
    final normalized = currentPath?.trim() ?? '';
    if (normalized.isNotEmpty && await File(normalized).exists()) {
      return normalized;
    }
    final file = await findLocalCoverFile(comicDir);
    return file?.path;
  }

  Future<List<DownloadedMangaChapter>> normalizeChapterPaths({
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
        final chapterDir = await findChapterDirectoryByIndex(
          chapter.index,
          comicDir,
        );
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

  Future<List<({Directory directory, List<File> files, int? chapterNumber})>>
  _collectChapterDirectoriesFromDisk(Directory comicDir) async {
    final directories =
        <({Directory directory, List<File> files, int? chapterNumber})>[];
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
          final files = await _listImageFiles(entity, excludeCoverFiles: true);
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
      return _entityBaseName(
        a.directory,
      ).compareTo(_entityBaseName(b.directory));
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
        RegExp('^manga\\D*0*$chapterText\$', caseSensitive: false),
        RegExp('^chapter\\D*0*$chapterText\$', caseSensitive: false),
        RegExp('^0*$chapterText\$'),
      ];
      final isGenericDirectoryName = genericPatterns.any(
        (pattern) => pattern.hasMatch(normalized),
      );
      if (!isGenericDirectoryName) {
        return normalized;
      }
    }
    return 'Chapter $chapterNumber';
  }

  int? _extractChapterNumberFromDirectoryName(String directoryName) {
    final normalized = directoryName.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final pattern in <RegExp>[
      RegExp(r'^manga\D*0*(\d+)(?:\D.*)?$', caseSensitive: false),
      RegExp(r'^chapter\D*0*(\d+)(?:\D.*)?$', caseSensitive: false),
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
    final lower = fileName.trim().toLowerCase();
    return lower == 'cover.jpg' ||
        lower == 'cover.jpeg' ||
        lower == 'cover.png' ||
        lower == 'cover.webp' ||
        lower.startsWith('cover.') ||
        lower.startsWith('comic_cover.') ||
        lower.startsWith('manga_cover.');
  }
}
