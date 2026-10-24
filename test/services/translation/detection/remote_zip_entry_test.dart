import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/network/hazuki_network_factory.dart';
import 'package:hazuki/services/translation/detection/remote_zip_entry.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  late Dio dio;
  final requests = <(String, String?)>[];
  var honourRange = true;

  final random = math.Random(3);
  // 可压缩但不全相同的数据，保证 deflate 条目的压缩大小远小于原始大小。
  final library = Uint8List.fromList(
    List.generate(300000, (index) => (index ~/ 7 + random.nextInt(3)) % 256),
  );
  final padding = Uint8List.fromList(
    List.generate(200000, (_) => random.nextInt(256)),
  );
  final stored = Uint8List.fromList(List.generate(5000, (index) => index % 13));
  final zip = Uint8List.fromList(
    ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.bytes('pkg/README.md', [1, 2, 3]))
        ..addFile(ArchiveFile.bytes('pkg/lib/runtime.dll', library))
        ..addFile(ArchiveFile.bytes('pkg/lib/runtime.pdb', padding))
        ..addFile(
          ArchiveFile.bytes('pkg/stored.bin', stored)
            ..compression = CompressionType.none,
        ),
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hazuki_zip_entry_');
    requests.clear();
    honourRange = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      requests.add((request.uri.path, range));
      final response = request.response;
      if (request.uri.path == '/redirect') {
        response.statusCode = HttpStatus.found;
        response.headers.set(HttpHeaders.locationHeader, '/archive.zip');
        await response.close();
        return;
      }
      if (request.uri.path != '/archive.zip') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final match = RegExp(r'^bytes=(\d+)-(\d+)$').firstMatch(range ?? '');
      if (!honourRange || match == null) {
        response.contentLength = zip.length;
        response.add(zip);
        await response.close();
        return;
      }
      final start = int.parse(match[1]!), end = int.parse(match[2]!);
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${zip.length}',
      );
      response.contentLength = end - start + 1;
      response.add(zip.sublist(start, end + 1));
      await response.close();
    });
    dio = createHazukiDio(
      baseOptions: BaseOptions(
        followRedirects: true,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  String url(String path) =>
      'http://${server.address.host}:${server.port}$path';

  Future<File> download(String entry, {String path = '/archive.zip'}) async {
    final output = File('${directory.path}/out.bin');
    await downloadZipEntry(
      dio: dio,
      url: url(path),
      archiveBytes: zip.length,
      entry: entry,
      output: output,
      scratch: File('${directory.path}/archive.download'),
    );
    return output;
  }

  test(
    'fetches only the directory and one deflated entry through redirects',
    () async {
      var progress = 0, total = 0;
      final output = File('${directory.path}/out.bin');
      await downloadZipEntry(
        dio: dio,
        url: url('/redirect'),
        archiveBytes: zip.length,
        entry: 'pkg/lib/runtime.dll',
        output: output,
        scratch: File('${directory.path}/archive.download'),
        onProgress: (received, expected) {
          progress = received;
          total = expected;
        },
      );
      expect(await output.readAsBytes(), library);
      // 每一跳都携带 Range 头，且从未请求整个文件。
      expect(requests.every((request) => request.$2 != null), isTrue);
      expect(
        requests.where((request) => request.$1 == '/redirect').length,
        greaterThanOrEqualTo(3),
      );
      expect(progress, total);
      expect(total, lessThan(library.length));
      expect(File('${directory.path}/archive.download').existsSync(), isFalse);
    },
  );

  test('copies stored entries without inflating them', () async {
    expect(await (await download('pkg/stored.bin')).readAsBytes(), stored);
  });

  test('falls back to a full download when ranges are ignored', () async {
    honourRange = false;
    final output = await download('pkg/lib/runtime.dll');
    expect(await output.readAsBytes(), library);
    expect(File('${directory.path}/archive.download').existsSync(), isFalse);
  });

  test('reports a missing entry as a format error', () async {
    await expectLater(download('pkg/missing.dll'), throwsFormatException);
  });

  test('surfaces network failures to the caller', () async {
    await expectLater(
      download('pkg/lib/runtime.dll', path: '/missing.zip'),
      throwsA(isA<DioException>()),
    );
  });
}
