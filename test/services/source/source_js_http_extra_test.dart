import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Http implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  ResponseBody Function(RequestOptions)? respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond?.call(options) ?? ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHandle handle;
  late _Http http;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    handle = SourceRuntimeHandle(
      sourceKey: 'sample',
      secureStorage: MemorySourceSecureSessionStorage(),
      ensureInitialized: (_) async {},
      notifyRuntimeStateChanged: (_) {},
    );
    http = _Http();
    handle.dio.httpClientAdapter = http;
    handle.httpGateway.configureCookieBridge();
    await handle.session.ensurePrefs();
    addTearDown(() async {
      handle.requestDispose();
      await handle.whenDisposed;
    });
  });

  ResponseBody redirect(String location) => ResponseBody.fromString(
    '',
    302,
    headers: {
      'location': [location],
    },
  );

  test('applies whitelisted extra options to the request', () async {
    http.respond = (_) => redirect('https://site.example/next');
    final result = await handle.httpGateway.sendJsHttpRequest({
      'url': 'https://site.example/start',
      'extra': {'timeoutMs': 5000, 'followRedirects': false, 'maxRedirects': 3},
    });

    final options = http.requests.single;
    expect(options.followRedirects, isFalse);
    expect(options.maxRedirects, 3);
    expect(options.receiveTimeout, const Duration(seconds: 5));
    expect(options.sendTimeout, const Duration(seconds: 5));
    expect(result['status'], 302);
    expect(result['headers']['location'], 'https://site.example/next');
    expect(result['url'], 'https://site.example/start');
  });

  test('reports the final url after host-managed redirects', () async {
    await handle.session.saveBrowserUserAgents({
      'https://site.example': 'Actual browser UA',
    });
    http.respond = (options) => options.uri.path == '/start'
        ? redirect('/final')
        : ResponseBody.fromString('done', 200);

    final result = await handle.httpGateway.sendJsHttpRequest({
      'url': 'https://site.example/start',
    });

    expect(http.requests.map((options) => options.uri.path), [
      '/start',
      '/final',
    ]);
    expect(result['url'], 'https://site.example/final');
    expect(result['body'], 'done');
  });

  test('rejects unknown keys and out-of-range values', () async {
    for (final extra in [
      {'proxy': 'http://127.0.0.1'},
      {'timeoutMs': 10},
      {'timeoutMs': 1500.5},
      {'followRedirects': 'no'},
      {'maxRedirects': 99},
      'invalid',
    ]) {
      await expectLater(
        handle.httpGateway.sendJsHttpRequest({
          'url': 'https://site.example/',
          'extra': extra,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'plugin_invalid_http_extra',
          ),
        ),
      );
    }
    expect(http.requests, isEmpty);
  });
}
