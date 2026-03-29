import 'dart:convert';
import 'dart:io';

import 'manga_download_models.dart';
import 'manga_download_recovery_disk_support.dart';
import 'manga_download_recovery_rules_support.dart';
import 'manga_download_storage_support.dart';

typedef MangaDownloadTaskLookup = MangaDownloadTask? Function(String comicId);
typedef MangaChapterDirBuilder =
    Directory Function(Directory comicDir, MangaChapterDownloadTarget target);
typedef MangaDownloadedMetadataWriter =
    Future<void> Function(Directory comicDir, DownloadedMangaComic comic);

class MangaDownloadRecoveryScanner {
  MangaDownloadRecoveryScanner({
    required MangaDownloadLogCallback logScan,
    required MangaDownloadTaskLookup taskByComicId,
    required MangaChapterDirBuilder chapterDirForTarget,
    required MangaDownloadedMetadataWriter writeMetadataFile,
  }) : _logScan = logScan,
       _chapterDirForTarget = chapterDirForTarget,
       _writeMetadataFile = writeMetadataFile,
       _rules = MangaDownloadRecoveryRules(
         taskByComicId: taskByComicId,
         chapterDirForTarget: chapterDirForTarget,
       ),
       _diskSupport = MangaDownloadRecoveryDiskSupport(logScan: logScan);

  final MangaDownloadLogCallback _logScan;
  final MangaChapterDirBuilder _chapterDirForTarget;
  final MangaDownloadedMetadataWriter _writeMetadataFile;
  final MangaDownloadRecoveryRules _rules;
  final MangaDownloadRecoveryDiskSupport _diskSupport;

  Future<
    ({
      List<DownloadedMangaComic> comics,
      int scannedDirectories,
      int recoveredComics,
    })
  >
  scanDownloadedFromDisk(Directory rootDir) async {
    var scannedDirectories = 0;
    var recoveredComics = 0;
    final comics = <DownloadedMangaComic>[];
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
          content: {'path': entity.path, 'name': _entityBaseName(entity)},
        );
        final comic = await _readComicFromDirectory(entity);
        if (comic != null) {
          recoveredComics++;
          comics.add(comic);
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
            content: {'path': entity.path, 'reason': 'no_completed_chapters'},
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
    return (
      comics: comics,
      scannedDirectories: scannedDirectories,
      recoveredComics: recoveredComics,
    );
  }

  DownloadedMangaComic? sanitizeDownloadedComicState(
    DownloadedMangaComic comic,
  ) => _rules.sanitizeDownloadedComicState(comic);

  Future<Directory?> resolveChapterDirForEpId({
    required Directory comicDir,
    required String epId,
    required List<MangaChapterDownloadTarget> targets,
    DownloadedMangaComic? downloadedComic,
  }) async {
    for (final chapter
        in downloadedComic?.chapters ?? const <DownloadedMangaChapter>[]) {
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
      final legacyDir = await findChapterDirectoryByIndex(
        target.index,
        comicDir,
      );
      if (legacyDir != null) {
        return legacyDir;
      }
    }
    return null;
  }

  Future<Directory?> findChapterDirectoryByIndex(
    int chapterIndex,
    Directory comicDir,
  ) => _diskSupport.findChapterDirectoryByIndex(chapterIndex, comicDir);

  Future<File?> findLocalCoverFile(Directory comicDir) =>
      _diskSupport.findLocalCoverFile(comicDir);

  Future<DownloadedMangaComic?> _readComicFromDirectory(
    Directory comicDir,
  ) async {
    final metadataFile = await _diskSupport.findMetadataFile(comicDir);
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
      final normalizedCoverPath = await _diskSupport.normalizeCoverPath(
        comicDir,
        comic.localCoverPath,
      );
      final normalizedChapters = await _diskSupport.normalizeChapterPaths(
        comicDir: comicDir,
        chapters: comic.chapters,
      );
      final scannedChapters = await _scanRecoveredChapters(comicDir);
      final normalized = _rules.sanitizeRecoveredComic(
        comicId: _baseNameFromPath(comicDir.path),
        comic: comic,
        localCoverPath: normalizedCoverPath,
        chapters: _rules.mergeRecoveredChapters(
          normalizedChapters: normalizedChapters,
          scannedChapters: scannedChapters,
        ),
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      final sanitized = sanitizeDownloadedComicState(normalized);
      if (sanitized == null) {
        _logScan(
          'Metadata-based recovery skipped because no completed chapters were found',
          level: 'warning',
          content: {
            'comicDir': comicDir.path,
            'metadataFile': metadataFile.path,
            'comicId': normalized.comicId,
          },
        );
        return null;
      }
      await _restoreDownloadedComicMetadata(comicDir, sanitized);
      _logScan(
        'Metadata-based recovery succeeded',
        content: {
          'comicDir': comicDir.path,
          'metadataFile': metadataFile.path,
          'comicId': sanitized.comicId,
          'normalizedChapterCount': normalizedChapters.length,
          'scannedChapterCount': scannedChapters.length,
          'mergedChapterCount': sanitized.chapters.length,
          'hasCover': sanitized.localCoverPath != null,
        },
      );
      return sanitized;
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

    final chapters = await _scanRecoveredChapters(comicDir);
    final localCover = await findLocalCoverFile(comicDir);
    if (chapters.isEmpty) {
      _logScan(
        'Fallback scan found no completed chapters',
        level: 'warning',
        content: {
          'comicDir': comicDir.path,
          'comicId': comicId,
          'hasCover': localCover != null,
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
      updatedAtMillis: await _diskSupport.readUpdatedAtMillis(comicDir),
    );
    final sanitized = sanitizeDownloadedComicState(rebuilt);
    if (sanitized == null) {
      _logScan(
        'Fallback recovery skipped because only incomplete chapters were found',
        level: 'warning',
        content: {'comicDir': comicDir.path, 'comicId': comicId},
      );
      return null;
    }
    await _restoreDownloadedComicMetadata(comicDir, sanitized);
    _logScan(
      'Fallback recovery succeeded',
      content: {
        'comicDir': comicDir.path,
        'comicId': comicId,
        'chapterCount': sanitized.chapters.length,
        'hasCover': sanitized.localCoverPath != null,
      },
    );
    return sanitized;
  }

  Future<void> _restoreDownloadedComicMetadata(
    Directory comicDir,
    DownloadedMangaComic comic,
  ) async {
    try {
      await _writeMetadataFile(comicDir, comic);
    } catch (_) {}
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

  Future<List<DownloadedMangaChapter>> _scanRecoveredChapters(
    Directory comicDir,
  ) {
    return _diskSupport.scanChapterDirectoriesFromDisk(
      comicDir,
      blockedDirectoryPaths: _rules.blockedChapterDirectoryPathsForTask(
        comicDir,
      ),
    );
  }
}
