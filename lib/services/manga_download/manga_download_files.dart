import 'dart:convert';
import 'dart:io';

import '../source/source_capabilities.dart';
import 'manga_download_models.dart';
import 'manga_download_recovery_disk_support.dart';
import 'manga_download_storage_support.dart';

/// Handles on-disk download layout and writes independently of queue state.
class MangaDownloadFiles {
  MangaDownloadFiles({
    required SourceReaderGateway? sourceReader,
    required MangaDownloadLogCallback logScan,
  }) : _sourceReader = sourceReader,
       _disk = MangaDownloadRecoveryDiskSupport(logScan: logScan);

  static const _metadataFileName = 'comic.json';
  static const _legacyMetadataFileName = 'metadata.json';
  final SourceReaderGateway? _sourceReader;
  final MangaDownloadRecoveryDiskSupport _disk;

  Future<Directory> ensureComicDirectory(
    Directory root,
    MangaDownloadTask task,
  ) async {
    final directory = Directory('${root.path}/${task.downloadDirName}');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> ensureChapterDirectory(
    Directory comicDir,
    MangaChapterDownloadTarget target,
  ) async {
    final directory = chapterDirForTarget(comicDir, target);
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<String> writeChapterImage(
    Directory chapterDir,
    int imageIndex,
    PreparedChapterImageData image,
  ) async {
    final name = '${imageIndex.toString().padLeft(4, '0')}.${image.extension}';
    final file = File('${chapterDir.path}/$name');
    await file.writeAsBytes(image.bytes, flush: true);
    return file.path;
  }

  Directory chapterDirForTarget(
    Directory comicDir,
    MangaChapterDownloadTarget target,
  ) {
    final chapterNumber = (target.index + 1).toString().padLeft(3, '0');
    return Directory('${comicDir.path}/MangaChapter$chapterNumber');
  }

  Future<String?> findExistingImagePath(
    Directory chapterDir,
    int imageIndex,
  ) async {
    final prefix = '${imageIndex.toString().padLeft(4, '0')}.';
    try {
      await for (final entity in chapterDir.list()) {
        if (entity is! File) {
          continue;
        }
        if (_entityBaseName(entity).startsWith(prefix)) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> downloadCoverIfNeeded({
    required MangaDownloadTask task,
    required Directory comicDir,
  }) async {
    final normalized = task.coverUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final existing = await _disk.findLocalCoverFile(comicDir);
    if (existing != null) {
      return existing.path;
    }
    final target = File('${comicDir.path}/cover.jpg');
    try {
      final sourceReader = _sourceReader;
      if (sourceReader == null) {
        throw StateError('manga_download_source_reader_not_configured');
      }
      final bytes = await sourceReader.downloadImageBytes(
        normalized,
        keepInMemory: false,
        sourceKey: task.sourceKey,
      );
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeMetadataFile(
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

  Future<void> deleteMetadataFiles(Directory comicDir) async {
    for (final name in const [_metadataFileName, _legacyMetadataFileName]) {
      final file = File('${comicDir.path}/$name');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
