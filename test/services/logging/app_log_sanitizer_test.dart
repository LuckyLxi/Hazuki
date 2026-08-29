import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_sanitizer.dart';

void main() {
  const sanitizer = AppLogSanitizer();
  const value = <String, dynamic>{
    'account': 'reader@example.com',
    'Authorization': 'Bearer secret',
    'nested': <String, dynamic>{'Cookie': 'session=secret', 'userId': '42'},
  };

  test('hides account data and credentials', () {
    final result =
        sanitizer.sanitize(value, AppLogSanitization.hideAllSensitive) as Map;

    expect(result['account'], '[hidden]');
    expect(result['Authorization'], '[hidden]');
    expect((result['nested'] as Map)['Cookie'], '[hidden]');
    expect((result['nested'] as Map)['userId'], '[hidden]');
  });

  test('can keep account data while hiding credentials', () {
    final result =
        sanitizer.sanitize(value, AppLogSanitization.keepAccountInfo) as Map;

    expect(result['account'], 'reader@example.com');
    expect(result['Authorization'], '[hidden]');
    expect((result['nested'] as Map)['Cookie'], '[hidden]');
    expect((result['nested'] as Map)['userId'], '42');
  });

  test('can keep the original data when explicitly requested', () {
    expect(sanitizer.sanitize(value, AppLogSanitization.keepEverything), value);
  });

  test('redacts credentials embedded in URLs and JSON text', () {
    final result =
        sanitizer.sanitize({
              'url': 'https://example.test?access_token=secret&chapter=1',
              'responseBody': '{"token":"secret","ok":true}',
            }, AppLogSanitization.keepAccountInfo)
            as Map;

    expect(result['url'], contains('access_token=[hidden]'));
    expect(result['url'], isNot(contains('access_token=secret')));
    expect(result['responseBody'], '{"token":"[hidden]","ok":true}');
  });

  test(
    'redacts authorization schemes without leaving the credential behind',
    () {
      final result = sanitizer.sanitize(
        'Authorization: Bearer original-secret',
        AppLogSanitization.hideAllSensitive,
      );

      expect(result, 'Authorization: [hidden]');
      expect(result, isNot(contains('original-secret')));
    },
  );

  test('recognizes common API key and secret header names', () {
    final result =
        sanitizer.sanitize({
              'X-API-Key': 'api-secret',
              'client_secret': 'client-secret',
              'X-Internal-Secret': 'internal-secret',
              'Proxy-Authorization': 'Basic credentials',
            }, AppLogSanitization.hideAllSensitive)
            as Map;

    expect(result.values, everyElement('[hidden]'));
  });

  test('only detects sensitive information when a value is present', () {
    expect(
      sanitizer.containsSensitiveInformation({
        'statusCode': 500,
        'message': 'Request failed',
        'currentAccount': null,
      }),
      isFalse,
    );
    expect(
      sanitizer.containsSensitiveInformation({
        'Authorization': 'Bearer secret',
      }),
      isTrue,
    );
    expect(
      sanitizer.containsSensitiveInformation({'currentAccount': 'reader'}),
      isTrue,
    );
    expect(
      sanitizer.containsSensitiveInformation(
        'https://example.test?access_token=secret&chapter=1',
      ),
      isTrue,
    );
  });
}
