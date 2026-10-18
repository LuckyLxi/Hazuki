import '../runtime/source_secure_session_storage.dart';

/// Read-through overlay. No write reaches the user's secrets before commit.
class SourceLoginStorageTransaction implements SourceSecureSessionStorage {
  SourceLoginStorageTransaction(this.storage);
  final SourceSecureSessionStorage storage;
  final Map<String, String?> _pending = {};
  final Map<String, String?> _before = {};
  bool _sealed = false;

  @override
  Future<String?> read(String key) async =>
      _pending.containsKey(key) ? _pending[key] : storage.read(key);
  @override
  Future<void> write(String key, String value) async {
    if (_sealed) throw StateError('login_transaction_closed');
    _pending[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (_sealed) throw StateError('login_transaction_closed');
    _pending[key] = null;
  }

  void discard() {
    _sealed = true;
  }

  Future<void> commit(void Function() check) async {
    _sealed = true;
    try {
      for (final entry in _pending.entries) {
        check();
        _before[entry.key] = await storage.read(entry.key);
        final value = entry.value;
        if (value == null) {
          await storage.delete(entry.key);
        } else {
          await storage.write(entry.key, value);
        }
      }
      check();
    } catch (_) {
      await rollback();
      rethrow;
    }
  }

  Future<void> rollback() async {
    Object? failure;
    for (final entry in _before.entries.toList().reversed) {
      try {
        final value = entry.value;
        if (value == null) {
          await storage.delete(entry.key);
        } else {
          await storage.write(entry.key, value);
        }
      } catch (error) {
        failure = error;
      }
    }
    if (failure != null) throw StateError('login_storage_rollback_failed');
  }
}
