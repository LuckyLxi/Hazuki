import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/image/source_image_network_downloader.dart';

void main() {
  test('merges source headers and cookies into the byte request', () async {
    (String, String, String)? resolvedArguments;
    String? requestedUrl;
    Map<String, dynamic>? requestedHeaders;
    final downloader = SourceImageNetworkDownloader(
      resolveLoadConfig: (url, comicId, epId) async {
        resolvedArguments = (url, comicId, epId);
        return {
          'headers': {'referer': 'https://source.test/'},
        };
      },
      resolveCookie: (url) => 'session=cookie',
      requestBytes: (url, headers) async {
        requestedUrl = url;
        requestedHeaders = Map<String, dynamic>.from(headers);
        return const SourceImageBytesResponse(statusCode: 200, data: [1, 2, 3]);
      },
    );

    final bytes = await downloader.download(
      'https://image.test/1.jpg',
      comicId: 'comic',
      epId: 'chapter',
    );

    expect(resolvedArguments, ('https://image.test/1.jpg', 'comic', 'chapter'));
    expect(requestedUrl, 'https://image.test/1.jpg');
    expect(requestedHeaders, {
      'referer': 'https://source.test/',
      'cookie': 'session=cookie',
    });
    expect(bytes, [1, 2, 3]);
  });

  test('preserves an explicit source cookie header', () async {
    Map<String, dynamic>? requestedHeaders;
    final downloader = SourceImageNetworkDownloader(
      resolveLoadConfig: (_, _, _) async => {
        'headers': {'cookie': 'source=cookie'},
      },
      resolveCookie: (_) => 'runtime=cookie',
      requestBytes: (_, headers) async {
        requestedHeaders = Map<String, dynamic>.from(headers);
        return const SourceImageBytesResponse(statusCode: 200, data: [1]);
      },
    );

    await downloader.download('https://image.test/1.jpg');
    expect(requestedHeaders, {'cookie': 'source=cookie'});
  });

  test(
    'ignores source hook failures and still sends runtime cookies',
    () async {
      Map<String, dynamic>? requestedHeaders;
      final downloader = SourceImageNetworkDownloader(
        resolveLoadConfig: (_, _, _) => Future.error(StateError('hook failed')),
        resolveCookie: (_) => 'runtime=cookie',
        requestBytes: (_, headers) async {
          requestedHeaders = Map<String, dynamic>.from(headers);
          return const SourceImageBytesResponse(statusCode: 200, data: [9]);
        },
      );

      expect(await downloader.download('url'), [9]);
      expect(requestedHeaders, {'cookie': 'runtime=cookie'});
    },
  );

  test('rejects unsuccessful and empty byte responses', () async {
    Future<void> expectFailure(SourceImageBytesResponse response, int code) {
      final downloader = SourceImageNetworkDownloader(
        resolveLoadConfig: (_, _, _) async => null,
        resolveCookie: (_) => null,
        requestBytes: (_, _) async => response,
      );
      return expectLater(
        downloader.download('url'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            'Exception: image_download_failed:$code',
          ),
        ),
      );
    }

    await expectFailure(
      const SourceImageBytesResponse(statusCode: 503, data: [1]),
      503,
    );
    await expectFailure(
      const SourceImageBytesResponse(statusCode: null, data: null),
      -1,
    );
    await expectFailure(
      const SourceImageBytesResponse(statusCode: 200, data: []),
      200,
    );
  });

  test('safely encodes source hook arguments', () {
    final script = SourceImageNetworkDownloader.buildImageLoadScript(
      'https://image.test/"quoted".jpg',
      comicId: "comic'\\id",
      epId: 'chapter\nline',
    );

    expect(script, contains(jsonEncode('https://image.test/"quoted".jpg')));
    expect(script, contains(jsonEncode("comic'\\id")));
    expect(script, contains(jsonEncode('chapter\nline')));
    expect(script, contains('onImageLoad'));
  });
}
