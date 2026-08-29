import 'dart:convert';

enum AppLogLevel {
  debug,
  info,
  warning,
  error;

  static AppLogLevel parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'debug' => AppLogLevel.debug,
      'warn' || 'warning' => AppLogLevel.warning,
      'error' => AppLogLevel.error,
      _ => AppLogLevel.info,
    };
  }

  String get wireName => switch (this) {
    AppLogLevel.debug => 'debug',
    AppLogLevel.info => 'info',
    AppLogLevel.warning => 'warning',
    AppLogLevel.error => 'error',
  };
}

enum AppLogArea {
  application,
  source,
  network,
  reader,
  download,
  update;

  static AppLogArea parse(String value) {
    return AppLogArea.values.firstWhere(
      (area) => area.name == value,
      orElse: () => AppLogArea.application,
    );
  }
}

class AppLogEvent {
  const AppLogEvent({
    required this.id,
    required this.time,
    required this.lastSeenAt,
    required this.level,
    required this.area,
    required this.source,
    required this.event,
    required this.title,
    required this.data,
    this.tags = const <String>[],
    this.occurrences = 1,
  });

  final String id;
  final DateTime time;
  final DateTime lastSeenAt;
  final AppLogLevel level;
  final AppLogArea area;
  final String source;
  final String event;
  final String title;
  final Object? data;
  final List<String> tags;
  final int occurrences;

  String get deduplicationKey => jsonEncode(<Object?>[
    level.wireName,
    area.name,
    source,
    event,
    title,
    tags,
    _deduplicationValue(data),
  ]);

  AppLogEvent seenAgain(AppLogEvent newer) {
    return AppLogEvent(
      id: id,
      time: time,
      lastSeenAt: newer.time,
      level: newer.level,
      area: newer.area,
      source: newer.source,
      event: newer.event,
      title: newer.title,
      data: newer.data,
      tags: newer.tags,
      occurrences: occurrences + 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'time': time.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'level': level.wireName,
    'area': area.name,
    'source': source,
    'event': event,
    'title': title,
    'data': data,
    'tags': tags,
    'occurrences': occurrences,
  };

  static AppLogEvent? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final id = json['id']?.toString();
    final time = DateTime.tryParse(json['time']?.toString() ?? '');
    final lastSeenAt = DateTime.tryParse(json['lastSeenAt']?.toString() ?? '');
    if (id == null || time == null || lastSeenAt == null) return null;
    return AppLogEvent(
      id: id,
      time: time,
      lastSeenAt: lastSeenAt,
      level: AppLogLevel.parse(json['level']?.toString() ?? 'info'),
      area: AppLogArea.parse(json['area']?.toString() ?? 'application'),
      source: json['source']?.toString() ?? 'app',
      event: json['event']?.toString() ?? 'log',
      title: json['title']?.toString() ?? 'Log',
      data: json['data'],
      tags:
          (json['tags'] as List?)
              ?.map((tag) => tag.toString())
              .toList(growable: false) ??
          const <String>[],
      occurrences: (json['occurrences'] as num?)?.toInt() ?? 1,
    );
  }
}

Object? _deduplicationValue(Object? value) {
  if (value is String && value.length > 256) {
    return <String, int>{
      'textLength': value.length,
      'textHash': value.hashCode,
    };
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key != 'durationMs' && entry.key != 'timestamp')
          entry.key.toString(): _deduplicationValue(entry.value),
    };
  }
  if (value is Iterable && value is! String) {
    return value.map(_deduplicationValue).toList(growable: false);
  }
  return value;
}

Object? normalizeLogValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): normalizeLogValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(normalizeLogValue).toList(growable: false);
  }
  try {
    return jsonDecode(jsonEncode(value));
  } catch (_) {
    return value.toString();
  }
}

AppLogArea inferLogArea({required String source, String? category}) {
  final value = '${category ?? ''} $source'.toLowerCase();
  if (value.contains('network') ||
      value.contains('http') ||
      value.contains('dio')) {
    return AppLogArea.network;
  }
  if (value.contains('reader')) return AppLogArea.reader;
  if (value.contains('download')) return AppLogArea.download;
  if (value.contains('update') || value.contains('version')) {
    return AppLogArea.update;
  }
  if (value.contains('source') || value.contains('js_')) {
    return AppLogArea.source;
  }
  return AppLogArea.application;
}
