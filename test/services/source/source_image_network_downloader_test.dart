import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/services/source/image/source_image_network_downloader.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/models/source_task.dart';
import 'package:hazuki/services/source/runtime/source_host_call_context.dart';

SourceScriptStopped _scriptStopped(String reason) => SourceScriptStopped(
  execution: const SourceScriptExecution(
    taskId: 'image-task',
    pluginId: 'source',
    method: 'image.load',
  ),
  runtimeId: 'runtime',
  nativeToken: 1,
  reason: reason,
);

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
        'headers': {'Cookie': 'source=cookie'},
      },
      resolveCookie: (_) => 'runtime=cookie',
      requestBytes: (_, headers) async {
        requestedHeaders = Map<String, dynamic>.from(headers);
        return const SourceImageBytesResponse(statusCode: 200, data: [1]);
      },
    );

    await downloader.download('https://image.test/1.jpg');
    expect(requestedHeaders, {'Cookie': 'source=cookie'});
  });

  test('uses the plugin image URL and resolves cookies for its host', () async {
    const original = 'https://image.test/1.jpg';
    const rewritten = 'https://cdn.test/1.jpg?token=signed';
    String? cookieUrl;
    String? requestedUrl;
    Map<String, dynamic>? requestedHeaders;
    final downloader = SourceImageNetworkDownloader(
      resolveLoadConfig: (url, _, _) async {
        expect(url, original);
        return {
          'url': rewritten,
          'headers': {'referer': 'https://source.test/'},
        };
      },
      resolveCookie: (url) {
        cookieUrl = url;
        return url == rewritten ? 'cdn=session' : 'original=session';
      },
      requestBytes: (url, headers) async {
        requestedUrl = url;
        requestedHeaders = Map<String, dynamic>.from(headers);
        return const SourceImageBytesResponse(statusCode: 200, data: [1]);
      },
    );

    expect(await downloader.download(original), [1]);
    expect(requestedUrl, rewritten);
    expect(cookieUrl, rewritten);
    expect(requestedHeaders, {
      'referer': 'https://source.test/',
      'cookie': 'cdn=session',
    });
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

  for (final entry in <String, Object>{
    'task cancellation': const SourceTaskCancelled(
      'image-task',
      SourceTaskStopReason.user,
    ),
    'UI cancellation': const SourceUiCancelled('ownerGone'),
    'login cancellation': const SourceLoginCancelled(),
    'script stop': _scriptStopped('cancelled'),
  }.entries) {
    test('propagates ${entry.key} without sending a byte request', () async {
      var requests = 0;
      final downloader = SourceImageNetworkDownloader(
        resolveLoadConfig: (_, _, _) => Future.error(entry.value),
        resolveCookie: (_) => null,
        requestBytes: (_, _) async {
          requests++;
          return const SourceImageBytesResponse(statusCode: 200, data: [1]);
        },
      );

      await expectLater(
        downloader.download('https://image.test/1.jpg'),
        throwsA(same(entry.value)),
      );
      expect(requests, 0);
    });
  }

  test(
    'falls back to the original request when a hook dependency stops',
    () async {
      var requests = 0;
      final downloader = SourceImageNetworkDownloader(
        resolveLoadConfig: (_, _, _) =>
            Future.error(_scriptStopped('dependencyStopped')),
        resolveCookie: (_) => 'runtime=cookie',
        requestBytes: (url, headers) async {
          requests++;
          expect(url, 'https://image.test/1.jpg');
          expect(headers, {'cookie': 'runtime=cookie'});
          return const SourceImageBytesResponse(statusCode: 200, data: [9]);
        },
      );

      expect(await downloader.download('https://image.test/1.jpg'), [9]);
      expect(requests, 1);
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
