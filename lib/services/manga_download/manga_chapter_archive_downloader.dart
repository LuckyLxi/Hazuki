import 'dart:io';
import 'dart:isolate';

import 'package:koni_archive/io.dart';
import 'package:path/path.dart' as p;

import '../source/download/source_chapter_archive.dart';
import 'manga_download_models.dart';

class MangaArchiveExtractionFailure implements Exception {
  const MangaArchiveExtractionFailure(this.path);
  final String path;

  @override
  String toString() => '$mangaArchiveExtractionErrorPrefix$path';
}

class MangaChapterArchiveDownloader {
  Future<List<String>> download({
    required SourceChapterArchiveGateway gateway,
    required SourceChapterArchive request,
    required Directory chapterDir,
    required String sourceKey,
    required bool Function() shouldCancel,
  }) async {
    // Keep the original archive in an ordinary, discoverable directory on
    // extraction failure. Archive entry paths never become filesystem paths.
    final archives = Directory(p.join(chapterDir.path, 'archives'));
    await archives.create(recursive: true);
    var archive = File(p.join(archives.path, request.fileName));
    final partial = File('${archive.path}.part');
    try {
      await gateway.downloadChapterArchive(
        request,
        partial,
        sourceKey: sourceKey,
        shouldCancel: shouldCancel,
      );
      if (shouldCancel()) throw const SourceChapterArchiveCancelled();
      archive = File(
        p.join(
          archives.path,
          await _archiveFileName(request.fileName, partial),
        ),
      );
      await partial.rename(archive.path);
    } finally {
      if (await partial.exists()) await partial.delete();
    }

    final staging = await chapterDir.createTemp('.extracting-');
    try {
      final archivePath = archive.path;
      final stagingPath = staging.path;
      List<String> names;
      try {
        names = await Isolate.run(() => _extract(archivePath, stagingPath));
      } catch (_) {
        if (shouldCancel()) throw const SourceChapterArchiveCancelled();
        throw MangaArchiveExtractionFailure(archive.path);
      }
      if (shouldCancel()) throw const SourceChapterArchiveCancelled();
      final paths = <String>[];
      // All entries have passed checksum verification before publishing pages.
      for (final name in names) {
        final destination = p.join(chapterDir.path, name);
        File(p.join(staging.path, name)).renameSync(destination);
        paths.add(destination);
      }
      await archive.delete();
      return paths;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}

Future<String> _archiveFileName(String suppliedName, File file) async {
  if (const {
        '.zip',
        '.cbz',
        '.rar',
        '.cbr',
        '.7z',
        '.cb7',
        '.tar',
        '.cbt',
        '.gz',
        '.tgz',
      }.contains(p.extension(suppliedName).toLowerCase()) &&
      !suppliedName.startsWith('.')) {
    return suppliedName;
  }
  final input = await file.open();
  late List<int> bytes;
  try {
    bytes = await input.read(512);
  } finally {
    await input.close();
  }
  for (final (signature, extension) in [
    ([0x50, 0x4b], 'zip'),
    ([0x52, 0x61, 0x72, 0x21], 'rar'),
    ([0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c], '7z'),
    ([0x1f, 0x8b], 'gz'),
  ]) {
    if (bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((v) => v)) {
      return 'chapter.$extension';
    }
  }
  if (bytes.length >= 262 &&
      String.fromCharCodes(bytes.sublist(257, 262)) == 'ustar') {
    return 'chapter.tar';
  }
  return 'chapter.archive';
}

Future<List<String>> _extract(String archivePath, String stagingPath) async {
  final source = await FileByteSource.open(archivePath);
  ArchiveReader? archive;
  try {
    // The reader surfaces pre-stream errors synchronously; the facade's
    // onListen wrapper can turn these into uncaught isolate errors.
    archive = await builtInFormats.openReader(
      source,
      options: const ArchiveReadOptions(
        maxEntryCount: 20000,
        maxEntrySize: 128 << 20,
        maxContainerDecodeSize: 512 << 20,
      ),
    );
    if (archive.entries.any((entry) => entry.pathEscapedRoot)) {
      throw const FormatException('chapter_archive_unsafe_path');
    }
    final uniqueEntries = {
      for (final entry in archive.entries) entry.path: entry,
    };
    final pages = uniqueEntries.values.where((entry) {
      final parts = entry.path.split('/');
      return entry.isFile &&
          !parts.any((part) => part.startsWith('.') || part == '__MACOSX') &&
          const {
            '.jpg',
            '.jpeg',
            '.png',
            '.webp',
            '.gif',
            '.bmp',
            '.avif',
          }.contains(p.posix.extension(entry.path).toLowerCase());
    }).toList()..sort((a, b) => _naturalCompare(a.path, b.path));
    if (pages.isEmpty) throw const FormatException('chapter_archive_no_images');
    final names = <String>[];
    var totalSize = 0;
    for (var i = 0; i < pages.length; i++) {
      final entry = pages[i];
      totalSize += entry.uncompressedSize;
      if (totalSize > 2 << 30) {
        throw const FormatException('chapter_archive_too_large');
      }
      final extension = p.posix.extension(entry.path).toLowerCase();
      final name = '${(i + 1).toString().padLeft(4, '0')}$extension';
      // Some decoders throw before returning a stream (e.g. missing password).
      // Ask for it before opening a file, and explicitly await handle closure.
      final content = archive.openRead(entry);
      final output = await File(
        p.join(stagingPath, name),
      ).open(mode: FileMode.write);
      try {
        await for (final chunk in content) {
          await output.writeFrom(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      names.add(name);
    }
    return names;
  } finally {
    try {
      await archive?.close();
    } finally {
      await source.close();
    }
  }
}

int _naturalCompare(String a, String b) {
  final pattern = RegExp(r'\d+|\D+');
  final left = pattern.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final right = pattern.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final leftNumber = BigInt.tryParse(left[i]);
    final rightNumber = BigInt.tryParse(right[i]);
    final compared = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : left[i].compareTo(right[i]);
    if (compared != 0) return compared;
  }
  final compared = left.length.compareTo(right.length);
  return compared == 0 ? a.compareTo(b) : compared;
}
