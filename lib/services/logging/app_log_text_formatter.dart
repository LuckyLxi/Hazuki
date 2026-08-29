import 'dart:convert';

import 'app_log_event.dart';
import 'app_log_sanitizer.dart';

class AppLogTextFormatter {
  const AppLogTextFormatter({this.sanitizer = const AppLogSanitizer()});

  final AppLogSanitizer sanitizer;

  String format({
    required Iterable<AppLogEvent> events,
    required DateTime generatedAt,
    required String platform,
    required String appVersion,
    required AppLogSanitization sanitization,
    Object? account,
    Object? source,
  }) {
    final ordered = events.toList()..sort((a, b) => a.time.compareTo(b.time));
    final errors = ordered
        .where((event) => event.level == AppLogLevel.error)
        .length;
    final warnings = ordered
        .where((event) => event.level == AppLogLevel.warning)
        .length;
    final output = StringBuffer()
      ..writeln('Hazuki Diagnostic Log')
      ..writeln('Generated: ${generatedAt.toIso8601String()}')
      ..writeln('App Version: $appVersion')
      ..writeln('Platform: $platform')
      ..writeln(
        'Account: ${sanitizer.sanitize(account, sanitization, key: 'account') ?? '-'}',
      )
      ..writeln('Source: ${sanitizer.sanitize(source, sanitization) ?? '-'}')
      ..writeln('Log Count: ${ordered.length}')
      ..writeln('Errors: $errors')
      ..writeln('Warnings: $warnings')
      ..writeln('=' * 72);

    for (final event in ordered) {
      final safeTitle = sanitizer.sanitize(event.title, sanitization);
      final safeEvent =
          sanitization != AppLogSanitization.keepEverything &&
              sanitizer.containsSensitiveInformation(event.title)
          ? '[hidden]'
          : sanitizer.sanitize(event.event, sanitization);
      final safeSource = sanitizer.sanitize(event.source, sanitization);
      final safeTags = sanitizer.sanitize(event.tags, sanitization) as List;
      output
        ..writeln()
        ..writeln(
          '[${event.time.toIso8601String()}] '
          '[${event.level.wireName.toUpperCase()}] '
          '[${event.area.name.toUpperCase()}]',
        )
        ..writeln(safeTitle)
        ..writeln()
        ..writeln('event: $safeEvent')
        ..writeln('source: $safeSource');
      if (safeTags.isNotEmpty) {
        output.writeln('tags: ${safeTags.join(', ')}');
      }
      if (event.occurrences > 1) {
        output
          ..writeln('occurrences: ${event.occurrences}')
          ..writeln('lastSeenAt: ${event.lastSeenAt.toIso8601String()}');
      }
      final safeData = sanitizer.sanitize(event.data, sanitization);
      if (safeData != null) {
        output.writeln(_formatData(safeData));
      }
      output.writeln('-' * 72);
    }
    return output.toString();
  }

  String _formatData(Object value) {
    if (value is Map || value is Iterable) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }
}
