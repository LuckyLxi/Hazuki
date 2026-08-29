import 'dart:convert';

const String debugLogTypeError = 'error';
const String debugLogTypeAction = 'action';
const String debugLogTypeSystem = 'system';
const String debugLogTypePerformance = 'performance';

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
