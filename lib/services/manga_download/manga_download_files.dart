import 'dart:convert';
import 'dart:io';

import '../source/source_capabilities.dart';
import 'manga_download_models.dart';
import 'manga_download_run.dart';
import 'manga_download_recovery_disk_support.dart';
import 'manga_download_storage_support.dart';

/// Handles on-disk download layout and writes independently of queue state.
class MangaDownloadFiles {
  MangaDownloadFiles({
    required SourceReaderGateway? sourceReader,
    required MangaDownloadLogCallback logScan,
    Future<void> Function(File temporary)? beforePublish,
  }) : _sourceReader = sourceReader,
       _beforePublish = beforePublish,
       _disk = MangaDownloadRecoveryDiskSupport(logScan: logScan);

  static const _metadataFileName = 'comic.json';
  static const _legacyMetadataFileName = 'metadata.json';
  final SourceReaderGateway? _sourceReader;
  final Future<void> Function(File)? _beforePublish;
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
    PreparedChapterImageData image, {
    MangaDownloadRun? run,
  }) async {
    final name = '${imageIndex.toString().padLeft(4, '0')}.${image.extension}';
    final file = File('${chapterDir.path}/$name');
    await _publish(
      file,
      (temporary) => temporary.writeAsBytes(image.bytes, flush: true),
      run: run,
    );
    return file.path;
  }

  Directory chapterDirForTarget(
    Directory comicDir,
    MangaChapterDownloadTarget target,
  ) {
    final chapterNumber = ((target.directoryIndex ?? target.index) + 1)
        .toString()
        .padLeft(3, '0');
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
        final name = _entityBaseName(entity);
        if (name.startsWith(prefix) &&
            !name.endsWith('.part') &&
            !name.endsWith('.tmp')) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> downloadCoverIfNeeded({
    required MangaDownloadTask task,
    required Directory comicDir,
    MangaDownloadRun? run,
  }) async {
    run?.checkActive();
    final normalized = task.coverUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final existing = await _disk.findLocalCoverFile(comicDir);
    run?.checkActive();
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
        sourceKey: run?.session?.sourceKey ?? task.sourceKey,
        taskOrigin: run?.origin,
      );
      run?.checkActive();
      Future<void> write() => _publish(
        target,
        (temporary) => temporary.writeAsBytes(bytes, flush: true),
        run: run,
      );
      if (run == null) {
        await write();
      } else {
        await run.commit(write);
      }
      return target.path;
    } catch (error) {
      if (error is SourceTaskCancelled || error is SourceRuntimeFailed) rethrow;
      run?.checkActive();
      return null;
    }
  }

  final Map<String, Future<void>> _metadataWrites = {};

  Future<void> writeMetadataFile(
    Directory comicDir,
    DownloadedMangaComic comic, {
    MangaDownloadRun? run,
  }) {
    final key = comicDir.absolute.path;
    final previous = _metadataWrites[key] ?? Future<void>.value();
    final result = previous.then((_) async {
      run?.checkActive();
      final file = File('${comicDir.path}/$_metadataFileName');
      await _publish(
        file,
        (temporary) =>
            temporary.writeAsString(jsonEncode(comic.toJson()), flush: true),
        run: run,
      );
      run?.checkActive();
      final legacy = File('${comicDir.path}/$_legacyMetadataFileName');
      if (await legacy.exists()) {
        run?.checkActive();
        await legacy.delete();
      }
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _metadataWrites[key] = tail;
    tail.whenComplete(() {
      if (identical(_metadataWrites[key], tail)) _metadataWrites.remove(key);
    });
    return result;
  }

  Future<void> _publish(
    File target,
    Future<File> Function(File) write, {
    MangaDownloadRun? run,
  }) async {
    run?.checkActive();
    final temporary = File(
      '${target.parent.path}/.hazuki-${createSourceTaskId()}.part',
    );
    try {
      await write(temporary);
      await _beforePublish?.call(temporary);
      run?.checkActive();
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
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
