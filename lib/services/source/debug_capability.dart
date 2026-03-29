part of '../hazuki_source_service.dart';

const int _debugMaxApplicationLogsKept = 180;
const int _debugMaxReaderLogsKept = 180;
const int _debugMaxNetworkLogsKept = 120;
const int _debugNetworkPreviewKeep = 320;
const int _debugNetworkFullBodyKeep = 1600;
const int _debugReaderStringKeep = 220;
const int _debugApplicationStringKeep = 320;
const int _debugNetworkHeadersKeep = 12;

Future<dynamic> _awaitJsResult(dynamic result) async {
  if (result is Future) {
    return await result;
  }
  return result;
}

dynamic _jsonSafe(dynamic value) {
  try {
    return jsonDecode(jsonEncode(value));
  } catch (_) {
    return value?.toString();
  }
}

String? _toBodyFull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List<int>) {
    return '[bytes length=${value.length}]';
  }
  return value.toString();
}

String? _toBodyPreview(String? fullBody, {int keep = 800}) {
  if (fullBody == null) {
    return null;
  }
  if (fullBody.length <= keep) {
    return fullBody;
  }
  final omitted = fullBody.length - keep;
  return '${fullBody.substring(0, keep)}... [omitted $omitted chars]';
}

String? _truncateBody(String? fullBody, {required int keep}) {
  if (fullBody == null) {
    return null;
  }
  if (fullBody.length <= keep) {
    return fullBody;
  }
  final omitted = fullBody.length - keep;
  return '${fullBody.substring(0, keep)}... [omitted $omitted chars]';
}

int _estimatePayloadBytes(Object? value) {
  if (value == null) {
    return 0;
  }
  try {
    return utf8.encode(jsonEncode(value)).length;
  } catch (_) {
    return utf8.encode(value.toString()).length;
  }
}

List<Map<String, dynamic>> _copyLogsWithoutDedupKey(
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
