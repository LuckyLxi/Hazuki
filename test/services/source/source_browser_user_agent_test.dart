import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_session_store.dart';
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
  late MemorySourceSecureSessionStorage storage;
  late SourceRuntimeHandle handle;
  late _Http http;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = MemorySourceSecureSessionStorage();
    handle = SourceRuntimeHandle(
      sourceKey: 'sample',
      secureStorage: storage,
      ensureInitialized: (_) async {},
      notifyRuntimeStateChanged: (_) {},
    );
    http = _Http();
    handle.dio.httpClientAdapter = http;
    handle.httpGateway.configureCookieBridge();
    await handle.session.ensurePrefs();
    await handle.cookieStore.set('https://site.example/', [
      SourceCookie(
        name: 'sid',
        value: 'synthetic',
        domain: 'site.example',
        path: '/',
        secure: true,
        httpOnly: true,
      ),
    ]);
    await handle.session.saveBrowserUserAgents({
      'https://site.example': 'Actual browser UA',
      'https://target.example': 'Target browser UA',
    });
    addTearDown(() async {
      handle.requestDispose();
      await handle.whenDisposed;
    });
  });

  test('pins UA on text, bytes and raw form requests with cookies', () async {
    for (final bytes in [false, true]) {
      await handle.httpGateway.sendJsHttpRequest({
        'http_method': 'POST',
        'url': 'https://site.example/comment',
        'bytes': bytes,
        'headers': {
          'uSeR-aGeNt': 'Stale plugin UA',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://site.example/',
          'Origin': 'https://site.example',
          'X-Requested-With': 'XMLHttpRequest',
        },
        'data':
            'video_id=1&comment=hello%20world&originator=&status=false&invite_verification=1234',
      });
    }
    for (final request in http.requests) {
      expect(request.headers['User-Agent'], 'Actual browser UA');
      expect(
        request.headers.keys.where((k) => k.toLowerCase() == 'user-agent'),
        hasLength(1),
      );
      expect(request.headers['cookie'], 'sid=synthetic');
      expect(request.headers['Referer'], 'https://site.example/');
      expect(request.headers['Origin'], 'https://site.example');
      expect(request.headers['X-Requested-With'], 'XMLHttpRequest');
      expect(request.data, contains('originator=&status=false'));
    }
    expect(http.requests.last.responseType, ResponseType.bytes);
  });

  test(
    'matches exact origins including ports and leaves other UAs alone',
    () async {
      for (final url in [
        'https://sub.site.example/',
        'https://site.example:444/',
        'http://site.example/',
        'https://other.example/',
      ]) {
        await handle.httpGateway.request<String>(
          url,
          options: Options(headers: {'User-Agent': 'Plugin UA'}),
        );
        expect(http.requests.last.headers['User-Agent'], 'Plugin UA');
      }
      final other = SourceSessionStore(
        sourceKey: 'other',
        secureStorage: storage,
      );
      await other.ensurePrefs();
      expect(other.loadBrowserUserAgents(), isEmpty);
    },
  );

  test(
    'recomputes UA and cookies at each redirect without leaking pinned UA',
    () async {
      http.respond = (request) => request.uri.host == 'site.example'
          ? ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://target.example/next'],
              },
            )
          : request.uri.host == 'target.example'
          ? ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['https://other.example/final'],
              },
            )
          : ResponseBody.fromString('done', 200);
      final result = await handle.httpGateway.request<String>(
        'https://site.example/start',
        options: Options(
          headers: {'User-Agent': 'Caller UA', 'Authorization': 'synthetic'},
        ),
      );
      expect(result.data, 'done');
      expect(http.requests.map((r) => r.headers['User-Agent']), [
        'Actual browser UA',
        'Target browser UA',
        'Caller UA',
      ]);
      expect(http.requests[1].headers['cookie'], isNull);
      expect(http.requests[1].headers['Authorization'], isNull);
      expect(http.requests[2].headers['cookie'], isNull);
    },
  );

  test(
    'preserves explicit redirect opt-out and enforces redirect limits',
    () async {
      http.respond = (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://site.example/loop'],
        },
      );
      final result = await handle.httpGateway.request<String>(
        'https://site.example/',
        options: Options(followRedirects: false),
      );
      expect(result.statusCode, 302);
      expect(http.requests, hasLength(1));
      await expectLater(
        handle.httpGateway.request<String>(
          'https://site.example/',
          options: Options(maxRedirects: 1),
        ),
        throwsA(isA<DioException>()),
      );
      expect(http.requests, hasLength(3));
    },
  );

  test(
    'restores profiles after restart and clears them with scoped cookies',
    () async {
      final restored = SourceSessionStore(
        sourceKey: 'sample',
        secureStorage: storage,
      );
      await restored.ensurePrefs();
      expect(
        restored.browserUserAgentFor('https://site.example/account'),
        'Actual browser UA',
      );
      await handle.cookieStore.set('https://target.example/', [
        SourceCookie(
          name: 'other',
          value: 'synthetic',
          domain: 'target.example',
          path: '/',
        ),
      ]);
      await handle.cookieStore.delete('https://site.example/');
      expect(
        handle.session.browserUserAgentFor('https://site.example/'),
        isNull,
      );
      expect(
        handle.session.browserUserAgentFor('https://target.example/'),
        'Target browser UA',
      );
      await handle.session.saveCookieStore([]);
      expect(handle.session.loadBrowserUserAgents(), isEmpty);
      expect(
        storage.values.containsKey(
          SourceSecureSessionStorageKeys.browserUserAgents('sample'),
        ),
        false,
      );
    },
  );
}
