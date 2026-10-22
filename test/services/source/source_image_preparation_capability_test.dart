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

  test('parses source-declared image metadata', () {
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
  });

  test('validates plugin-declared image regions', () {
    SourceImageRegionLayout? parse(dynamic raw) =>
        SourceImagePreparationCapability.parseImageRegions(
          raw,
          sourceWidth: 10,
          sourceHeight: 20,
        );
    Map<String, int> region([Map<String, int> overrides = const {}]) => {
      'sx': 0,
      'sy': 0,
      'sw': 10,
      'sh': 10,
      'dx': 0,
      'dy': 10,
      ...overrides,
    };
    final invalid = throwsA(
      isA<StateError>().having(
        (error) => error.message,
        'message',
        'plugin_invalid_image_regions',
      ),
    );

    expect(parse(null), isNull);
    expect(parse({'regions': []}), isNull);
    final layout = parse({
      'regions': [region()],
    })!;
    expect((layout.width, layout.height), (10, 20));
    expect(layout.regions.single, (
      sx: 0,
      sy: 0,
      sw: 10,
      sh: 10,
      dx: 0,
      dy: 10,
    ));
    expect(
      parse({
        'width': 20,
        'height': 10,
        'regions': [
          region({'dx': 10, 'dy': 0}),
        ],
      })!.width,
      20,
    );

    expect(() => parse('regions'), invalid);
    expect(() => parse({'regions': 'x'}), invalid);
    expect(
      () => parse({
        'regions': [
          region({'sx': 1}),
        ],
      }),
      invalid,
    );
    expect(
      () => parse({
        'regions': [
          region({'dy': 11}),
        ],
      }),
      invalid,
    );
    expect(
      () => parse({
        'regions': [
          region({'sx': -1, 'sw': 1}),
        ],
      }),
      invalid,
    );
    expect(
      () => parse({
        'regions': [
          region({'sh': 0}),
        ],
      }),
      invalid,
    );
    expect(
      () => parse({
        'regions': [
          {...region(), 'sw': 1.5},
        ],
      }),
      invalid,
    );
    expect(
      () => parse({
        'width': 100,
        'height': 100,
        'regions': [region()],
      }),
      invalid,
    );
    expect(() => parse({'regions': List.filled(4097, region())}), invalid);
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
            taskOrigin,
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
          taskOrigin,
        }) async => Uint8List(0),
  );
}
