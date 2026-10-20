import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/manga_download/manga_chapter_archive_downloader.dart';
import 'package:hazuki/services/source/download/source_chapter_archive.dart';
import 'package:koni_archive/io.dart';

void main() {
  late Directory root;
  late _Gateway gateway;
  const request = SourceChapterArchive(
    url: 'https://example.com/chapter',
    fileName: 'chapter.zip',
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('hazuki-archive-test-');
    gateway = _Gateway();
  });
  tearDown(() => root.delete(recursive: true));

  Future<List<String>> download({bool Function()? shouldCancel}) =>
      MangaChapterArchiveDownloader().download(
        gateway: gateway,
        request: request,
        chapterDir: root,
        sourceKey: 'sample',
        shouldCancel: shouldCancel ?? () => false,
      );

  for (final format in [
    const ZipWriteFormat(),
    const TarWriteFormat(),
    const SevenZWriteFormat(),
  ]) {
    test(
      'extracts ${format.name} by content and sorts nested pages naturally',
      () async {
        final input = File('${root.path}/input');
        final writer = await createArchiveFile(input.path, format: format);
        for (final item in {
          'chapter/10.jpg': 10,
          'chapter/2.png': 2,
          'chapter/1.webp': 1,
          '__MACOSX/._1.jpg': 99,
          '.hidden/0.jpg': 99,
          'README.txt': 99,
        }.entries) {
          await writer.addBytes(
            ArchiveEntrySpec(path: item.key),
            Uint8List.fromList([item.value]),
          );
        }
        await writer.close();
        gateway.bytes = await input.readAsBytes();
        final paths = await download();
        expect(paths.map((path) => path.split(Platform.pathSeparator).last), [
          '0001.webp',
          '0002.png',
          '0003.jpg',
        ]);
        expect(await Future.wait(paths.map((p) => File(p).readAsBytes())), [
          [1],
          [2],
          [10],
        ]);
        expect(
          await File('${root.path}/archives/chapter.zip').exists(),
          isFalse,
        );
        expect(gateway.sourceKey, 'sample');
      },
    );
  }

  test('extracts a RAR4 stored chapter', () async {
    // Self-contained RAR4 store fixture: 1.jpg contains the single byte 42.
    gateway.bytes = base64Decode(
      'UmFyIRoHAM+QcwAADQAAAAAAAAAKjXQAACUAAQAAAAEAAAAAWya5CQAAAAAUMAUAAAAAADEuanBnKgSwewAABwA=',
    );
    final paths = await download();
    expect(await File(paths.single).readAsBytes(), [42]);
  });

  test(
    'checksum failure after an earlier page publishes no partial chapter',
    () async {
      final archive = zip.Archive()
        ..addFile(zip.ArchiveFile.bytes('1.jpg', [1]))
        ..addFile(zip.ArchiveFile.noCompress('2.jpg', 4, [84, 43, 66, 99]));
      final bytes = zip.ZipEncoder().encode(archive);
      final payload = List.generate(bytes.length - 3, (i) => i).firstWhere(
        (i) =>
            bytes[i] == 84 &&
            bytes[i + 1] == 43 &&
            bytes[i + 2] == 66 &&
            bytes[i + 3] == 99,
      );
      expect(bytes.sublist(payload, payload + 4), [84, 43, 66, 99]);
      bytes[payload] ^= 1;
      gateway.bytes = bytes;
      await expectLater(
        download(),
        throwsA(isA<MangaArchiveExtractionFailure>()),
      );
      expect(await File('${root.path}/0001.jpg').exists(), isFalse);
      expect(await File('${root.path}/0002.jpg').exists(), isFalse);
      expect(await File('${root.path}/archives/chapter.zip').exists(), isTrue);
    },
  );

  test(
    'gives archives from extensionless endpoints a useful manual-extraction name',
    () async {
      gateway.bytes = base64Decode(
        'UmFyIRoHAM+QcwAADQAAAAAAAAAKjXQAACUAAQAAAAEAAAAAWya5CQAAAAAUMAUAAAAAADEuanBnKgSwewAABwA=',
      );
      // Change the uncompressed payload so the checksum fails after detection.
      gateway.bytes[gateway.bytes.length - 8] ^= 1;
      await expectLater(
        MangaChapterArchiveDownloader().download(
          gateway: gateway,
          request: const SourceChapterArchive(
            url: 'https://example.com/download',
          ),
          chapterDir: root,
          sourceKey: 'sample',
          shouldCancel: () => false,
        ),
        throwsA(isA<MangaArchiveExtractionFailure>()),
      );
      expect(await File('${root.path}/archives/chapter.rar').exists(), isTrue);
    },
  );

  test('keeps an encrypted ZIP and publishes no pages', () async {
    final input = File('${root.path}/encrypted');
    final writer = await createArchiveFile(
      input.path,
      format: const ZipWriteFormat(),
      options: const ArchiveWriteOptions(password: 'secret'),
    );
    await writer.addBytes(
      ArchiveEntrySpec(path: '1.jpg'),
      Uint8List.fromList([1]),
    );
    await writer.close();
    gateway.bytes = await input.readAsBytes();
    await expectLater(
      download(),
      throwsA(isA<MangaArchiveExtractionFailure>()),
    );
    expect(
      await File('${root.path}/archives/chapter.zip').readAsBytes(),
      gateway.bytes,
    );
    expect(await File('${root.path}/0001.jpg').exists(), isFalse);
    expect(
      root.listSync().whereType<Directory>().map((d) => d.path),
      everyElement(isNot(contains('.extracting-'))),
    );
  });

  test('rejects path traversal without writing archive paths', () async {
    final archive = zip.Archive()
      ..addFile(zip.ArchiveFile.bytes('../escaped.jpg', [1]));
    gateway.bytes = zip.ZipEncoder().encode(archive);
    await expectLater(
      download(),
      throwsA(isA<MangaArchiveExtractionFailure>()),
    );
    expect(await File('${root.path}/0001.jpg').exists(), isFalse);
    expect(await File('${root.path}/archives/chapter.zip').exists(), isTrue);
  });

  test(
    'corrupt and image-free archives remain available for manual extraction',
    () async {
      for (final bytes in [
        <int>[1, 2, 3],
        zip.ZipEncoder().encode(
          zip.Archive()..addFile(zip.ArchiveFile.string('readme.txt', 'text')),
        ),
      ]) {
        gateway.bytes = bytes;
        await expectLater(
          download(),
          throwsA(isA<MangaArchiveExtractionFailure>()),
        );
        expect(
          await File('${root.path}/archives/chapter.zip').readAsBytes(),
          bytes,
        );
        expect(await File('${root.path}/0001.jpg').exists(), isFalse);
      }
    },
  );

  test(
    'download failure removes partial files and preserves its error',
    () async {
      gateway.failure = const SocketException('offline');
      await expectLater(download(), throwsA(isA<SocketException>()));
      expect(await Directory('${root.path}/archives').list().toList(), isEmpty);
    },
  );

  test('pausing after transfer does not publish a chapter', () async {
    var cancelled = false;
    gateway.afterDownload = () => cancelled = true;
    await expectLater(
      download(shouldCancel: () => cancelled),
      throwsA(isA<SourceChapterArchiveCancelled>()),
    );
    expect(await Directory('${root.path}/archives').list().toList(), isEmpty);
  });
}

class _Gateway implements SourceChapterArchiveGateway {
  List<int> bytes = [1, 2, 3];
  Object? failure;
  void Function()? afterDownload;
  String? sourceKey;

  @override
  Future<SourceChapterArchive?> loadChapterArchive({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) async => null;

  @override
  Future<void> downloadChapterArchive(
    SourceChapterArchive archive,
    File destination, {
    required String sourceKey,
    required bool Function() shouldCancel,
  }) async {
    this.sourceKey = sourceKey;
    await destination.writeAsBytes(bytes);
    if (failure != null) throw failure!;
    afterDownload?.call();
  }
}
