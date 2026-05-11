import 'dart:convert';
import 'dart:typed_data';

bool jsAsBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value == 'true' || value == '1';
  }
  return false;
}

int? jsAsInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

Uint8List jsToBytes(dynamic value) {
  if (value is Uint8List) {
    return value;
  }
  if (value is List<int>) {
    return Uint8List.fromList(value);
  }
  if (value is List) {
    return Uint8List.fromList(value.map((e) => (e as num).toInt()).toList());
  }
  if (value is String) {
    return Uint8List.fromList(utf8.encode(value));
  }
  return Uint8List(0);
}
