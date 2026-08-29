import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_event.dart';
import 'package:hazuki/services/logging/app_log_sanitizer.dart';
import 'package:hazuki/services/logging/app_log_text_formatter.dart';

void main() {
  final early = AppLogEvent(
    id: 'early',
    time: DateTime.utc(2026, 8, 28, 1),
    lastSeenAt: DateTime.utc(2026, 8, 28, 1),
    level: AppLogLevel.info,
    area: AppLogArea.application,
    source: 'app',
    event: 'started',
    title: 'Started',
    data: const {'token': 'secret'},
  );
  final late = AppLogEvent(
    id: 'late',
    time: DateTime.utc(2026, 8, 28, 2),
    lastSeenAt: DateTime.utc(2026, 8, 28, 2),
    level: AppLogLevel.error,
    area: AppLogArea.network,
    source: 'http',
    event: 'failed',
    title: 'Failed',
    data: const {'statusCode': 500},
  );

  test('formats chronological human-readable log text', () {
    final text = const AppLogTextFormatter().format(
      events: [late, early],
      generatedAt: DateTime.utc(2026, 8, 28, 3),
      platform: 'windows',
      appVersion: '1.2.3',
      sanitization: AppLogSanitization.hideAllSensitive,
    );

    expect(text, startsWith('Hazuki Diagnostic Log'));
    expect(text.indexOf('Started'), lessThan(text.indexOf('Failed')));
    expect(text, contains('"token": "[hidden]"'));
    expect(text, contains('[ERROR] [NETWORK]'));
  });

  test('keeps original credentials when explicitly selected', () {
    final text = const AppLogTextFormatter().format(
      events: [early],
      generatedAt: DateTime.utc(2026),
      platform: 'android',
      appVersion: '1.0.0',
      sanitization: AppLogSanitization.keepEverything,
    );

    expect(text, contains('"token": "secret"'));
  });

  test('redacts credentials from all exported event metadata', () {
    final sensitive = AppLogEvent(
      id: 'sensitive',
      time: DateTime.utc(2026, 8, 28),
      lastSeenAt: DateTime.utc(2026, 8, 28),
      level: AppLogLevel.error,
      area: AppLogArea.source,
      source: 'authorization=Bearer source-secret',
      event: 'token_title-secret',
      title: 'token=title-secret',
      data: const {'cookie': 'data-secret'},
      tags: const ['session=tag-secret'],
    );

    final text = const AppLogTextFormatter().format(
      events: [sensitive],
      generatedAt: DateTime.utc(2026),
      platform: 'android',
      appVersion: '1.0.0',
      sanitization: AppLogSanitization.hideAllSensitive,
    );

    expect(text, isNot(contains('title-secret')));
    expect(text, isNot(contains('source-secret')));
    expect(text, isNot(contains('data-secret')));
    expect(text, isNot(contains('tag-secret')));
    expect(text, contains('event: [hidden]'));
  });
}
