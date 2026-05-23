import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SourceSecureSessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SourceSecureSessionStorageKeys {
  const SourceSecureSessionStorageKeys._();

  static String account(String sourceKey) =>
      'hazuki_source_account_v1_${sourceKey.trim()}';

  static String token(String sourceKey) =>
      'hazuki_source_token_v1_${sourceKey.trim()}';

  static String cookies(String sourceKey) =>
      'hazuki_source_cookies_v1_${sourceKey.trim()}';
}

class FlutterSourceSecureSessionStorage implements SourceSecureSessionStorage {
  FlutterSourceSecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage(aOptions: _androidOptions);

  static const _androidOptions = AndroidOptions(
    storageNamespace: 'hazuki_source_session_v1',
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

@visibleForTesting
class MemorySourceSecureSessionStorage implements SourceSecureSessionStorage {
  MemorySourceSecureSessionStorage({Map<String, String>? initialValues})
    : values = Map<String, String>.from(initialValues ?? const {});

  final Map<String, String> values;
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) {
      throw StateError('secure_read_failed');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('secure_write_failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) {
      throw StateError('secure_delete_failed');
    }
    values.remove(key);
  }
}
