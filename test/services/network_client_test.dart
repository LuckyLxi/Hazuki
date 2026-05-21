import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/network/hazuki_network.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Hazuki network URL normalization', () {
    test('strips explicit HTTPS ports only for JM known hosts', () {
      expect(
        normalizeHazukiRequestUrl(
          'https://www.cdntwice.org:45176/media/path.jpg?a=1#frag',
          sourceKey: 'jm',
        ),
        'https://www.cdntwice.org/media/path.jpg?a=1#frag',
      );
      expect(
        normalizeHazukiRequestUrl(
          'https://www.cdntwice.org:45176/media/path.jpg',
          sourceKey: 'copy_manga',
        ),
        'https://www.cdntwice.org:45176/media/path.jpg',
      );
      expect(
        normalizeHazukiRequestUrl(
          'https://example.test:45176/media/path.jpg',
          sourceKey: 'jm',
        ),
        'https://example.test:45176/media/path.jpg',
      );
    });
  });

  group('HazukiNetworkClient conservative retry', () {
    test('retries transient GET failures once', () async {
      late _FakeAdapter adapter;
      adapter = _FakeAdapter((options, callCount) {
        if (callCount == 1) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'connection refused',
          );
        }
        return ResponseBody.fromString('ok', 200);
      });
      final dio = Dio(BaseOptions(validateStatus: (status) => true))
        ..httpClientAdapter = adapter;
      final client = HazukiNetworkClient(dio: dio, retryDelay: Duration.zero);

      final response = await client.get<String>(
        'https://example.test/data',
        options: Options(responseType: ResponseType.plain),
      );

      expect(response.data, 'ok');
      expect(adapter.callCount, 2);
    });

    test('does not automatically retry POST failures', () async {
      late _FakeAdapter adapter;
      adapter = _FakeAdapter((options, _) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'connection refused',
        );
      });
      final dio = Dio(BaseOptions(validateStatus: (status) => true))
        ..httpClientAdapter = adapter;
      final client = HazukiNetworkClient(dio: dio, retryDelay: Duration.zero);

      await expectLater(
        client.post<String>('https://example.test/login'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 1);
    });

    test(
      'retries transient GET status codes when validateStatus allows them',
      () async {
        late _FakeAdapter adapter;
        adapter = _FakeAdapter((options, callCount) {
          if (callCount == 1) {
            return ResponseBody.fromString('busy', 503);
          }
          return ResponseBody.fromString('ok', 200);
        });
        final dio = Dio(BaseOptions(validateStatus: (status) => true))
          ..httpClientAdapter = adapter;
        final client = HazukiNetworkClient(dio: dio, retryDelay: Duration.zero);

        final response = await client.get<String>(
          'https://example.test/data',
          options: Options(responseType: ResponseType.plain),
        );

        expect(response.statusCode, 200);
        expect(response.data, 'ok');
        expect(adapter.callCount, 2);
      },
    );

    test('classifies retryable status responses as transient', () {
      final requestOptions = RequestOptions(path: 'https://example.test');
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<void>(
          requestOptions: requestOptions,
          statusCode: 503,
        ),
      );

      expect(isHazukiTransientNetworkFailure(error), isTrue);
      expect(
        shouldRetryHazukiNetworkRequest(
          method: 'POST',
          error: error,
          attempt: 1,
          maxAttempts: 2,
        ),
        isFalse,
      );
    });
  });

  group('SourceHttpGateway', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
    });

    test('keeps JS response shape and source-scoped cookies', () async {
      final service = HazukiSourceService();
      final handle = SourceRuntimeHandle(service: service, sourceKey: 'jm');
      await handle.facade.ensurePrefs();
      handle.facade.httpGateway.configureCookieBridge();

      final adapter = _FakeAdapter((options, callCount) {
        if (callCount == 1) {
          expect(options.uri.toString(), 'https://www.cdntwice.org/path');
          return ResponseBody.fromString(
            'hello',
            200,
            headers: {
              'set-cookie': ['sid=abc; Path=/'],
            },
          );
        }
        expect(options.headers['cookie'], 'sid=abc');
        return ResponseBody.fromString('ok', 200);
      });
      handle.dio.httpClientAdapter = adapter;

      final result = await handle.facade.httpGateway.sendJsHttpRequest({
        'http_method': 'GET',
        'url': 'https://www.cdntwice.org:45176/path',
        'headers': <String, dynamic>{},
      });

      expect(result['status'], 200);
      expect(result['body'], 'hello');
      expect(result['headers'], contains('set-cookie'));

      await handle.facade.httpGateway.request<String>(
        'https://www.cdntwice.org:45176/next',
        options: Options(responseType: ResponseType.plain),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cookie_store_v2_jm'), contains('sid'));
      expect(prefs.getString('cookie_store_v2_copy_manga'), isNull);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options, int callCount)
  _handler;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    return _handler(options, callCount);
  }

  @override
  void close({bool force = false}) {}
}
