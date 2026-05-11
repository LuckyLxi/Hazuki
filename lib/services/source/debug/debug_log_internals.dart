import 'dart:convert';

class DebugLogConstants {
  const DebugLogConstants._();

  static const Duration maxAge = Duration(days: 7);
  static const int maxApplicationLogsKept = 180;
  static const int maxReaderLogsKept = 180;
  static const int maxNetworkLogsKept = 120;
  static const int maxTypedLogsKept = 220;
  static const int networkPreviewKeep = 240;
  static const int networkFullBodyKeep = 960;
  static const int readerStringKeep = 180;
  static const int applicationStringKeep = 320;
  static const int networkHeadersKeep = 12;
}

const String debugLogTypeError = 'error';
const String debugLogTypeAction = 'action';
const String debugLogTypeSystem = 'system';
const String debugLogTypePerformance = 'performance';

const List<String> debugLogTypes = <String>[
  debugLogTypeError,
  debugLogTypeAction,
  debugLogTypeSystem,
  debugLogTypePerformance,
];

Future<dynamic> awaitJsResult(dynamic result) async {
  if (result is Future) {
    return await result;
  }
  return result;
}

dynamic jsonSafe(dynamic value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  try {
    return jsonDecode(jsonEncode(value));
  } catch (_) {
    return value.toString();
  }
}

String? toBodyFull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List<int>) {
    return '[bytes length=${value.length}]';
  }
  return value.toString();
}

String? toBodyPreview(String? fullBody, {int keep = 800}) {
  if (fullBody == null) {
    return null;
  }
  if (fullBody.length <= keep) {
    return fullBody;
  }
  final omitted = fullBody.length - keep;
  return '${fullBody.substring(0, keep)}... [omitted $omitted chars]';
}

int estimatePayloadBytes(Object? value) {
  if (value == null) {
    return 0;
  }
  try {
    return utf8.encode(jsonEncode(value)).length;
  } catch (_) {
    return utf8.encode(value.toString()).length;
  }
}

List<Map<String, dynamic>> copyLogsWithoutDedupKey(
  List<Map<String, dynamic>> logs,
) {
  return logs
      .map((entry) {
        final copy = Map<String, dynamic>.from(entry);
        copy.remove('dedupKey');
        return copy;
      })
      .toList(growable: false);
}
