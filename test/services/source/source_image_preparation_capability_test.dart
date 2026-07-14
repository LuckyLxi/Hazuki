import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/image/source_image_preparation_capability.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  test('identifies and normalizes local image paths', () {
    final capability = _createCapability();

    expect(capability.isLocalImagePath('/tmp/chapter/1.jpg'), isTrue);
    expect(capability.isLocalImagePath('file:///tmp/chapter/1.jpg'), isTrue);
    expect(capability.isLocalImagePath(r'C:\chapter\1.jpg'), isTrue);
    expect(capability.isLocalImagePath('https://example.test/1.jpg'), isFalse);
    expect(
      capability.normalizeLocalImagePath(' file:///tmp/chapter/1.jpg '),
      Uri.file('/tmp/chapter/1.jpg').toFilePath(),
    );
  });

  test('parses source image metadata and JM fallback segments', () {
    expect(
      SourceImagePreparationCapability.parseDeclaredImageSegments({
        'segments': '4',
      }),
      4,
    );
    expect(
      SourceImagePreparationCapability.parseDeclaredImageSegments({
        'modifyImage': 'num = 6;',
      }),
      6,
    );
    expect(
      SourceImagePreparationCapability.parseDeclaredImageSegments({
        'segments': -1,
      }),
      -1,
    );
    expect(
      SourceImagePreparationCapability.parseDeclaredImageSegments({}),
      isNull,
    );
    expect(
      SourceImagePreparationCapability.imageExtensionFromUrl(
        'https://example.test/image.WEBP?size=2',
      ),
      'webp',
    );
    expect(
      SourceImagePreparationCapability.extractJmPictureName(
        'https://example.test/path/001.jpg?token=1',
      ),
      '001',
    );
    expect(
      SourceImagePreparationCapability.calculateJmImageSegmentsForSource(
        '220979',
        'https://example.test/001.jpg',
        sourceKey: 'jm',
      ),
      0,
    );
    expect(
      SourceImagePreparationCapability.calculateJmImageSegmentsForSource(
        '220980',
        'https://example.test/001.jpg',
        sourceKey: 'jm',
      ),
      10,
    );
    expect(
      SourceImagePreparationCapability.calculateJmImageSegmentsForSource(
        '500000',
        'https://example.test/001.jpg',
        sourceKey: 'copy_manga',
      ),
      0,
    );
  });

  test('keeps download arguments and skips GIF preprocessing', () async {
    Map<String, Object?>? arguments;
    final capability = _createCapability(
      downloadImageBytes:
          (
            url, {
            comicId,
            epId,
            keepInMemory = false,
            useDiskCache = true,
            priority = false,
            sourceKey = '',
          }) async {
            arguments = {
              'url': url,
              'comicId': comicId,
              'epId': epId,
              'keepInMemory': keepInMemory,
              'useDiskCache': useDiskCache,
              'priority': priority,
              'sourceKey': sourceKey,
            };
            return Uint8List.fromList([71, 73, 70]);
          },
    );

    final result = await capability.prepareChapterImageData(
      'https://example.test/001.gif',
      comicId: 'comic',
      epId: '220980',
      useDiskCache: false,
      priority: true,
      sourceKey: 'jm',
    );

    expect(arguments, {
      'url': 'https://example.test/001.gif',
      'comicId': 'comic',
      'epId': '220980',
      'keepInMemory': false,
      'useDiskCache': false,
      'priority': true,
      'sourceKey': 'jm',
    });
    expect(result.bytes, Uint8List.fromList([71, 73, 70]));
    expect(result.extension, 'gif');
    expect(result.wasProcessed, isFalse);
  });
}

SourceImagePreparationCapability _createCapability({
  SourceImageBytesDownloader? downloadImageBytes,
}) {
  return SourceImagePreparationCapability(
    runtimeHost: SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    ),
    downloadImageBytes:
        downloadImageBytes ??
        (
          _, {
          comicId,
          epId,
          keepInMemory = false,
          useDiskCache = true,
          priority = false,
          sourceKey = '',
        }) async => Uint8List(0),
  );
}
