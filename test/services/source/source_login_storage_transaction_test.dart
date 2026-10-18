import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/services/source/account/source_login_storage_transaction.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

class _FailOnce extends MemorySourceSecureSessionStorage {
  _FailOnce() : super(initialValues: {'a': 'old'});
  bool failed = false;
  @override
  Future<void> write(String key, String value) async {
    if (key == 'b' && !failed) {
      failed = true;
      throw StateError('write failed');
    }
    await super.write(key, value);
  }
}

void main() {
  test(
    'overlay reads pending values and commits only when requested',
    () async {
      final storage = MemorySourceSecureSessionStorage(
        initialValues: {'a': 'old'},
      );
      final transaction = SourceLoginStorageTransaction(storage);
      await transaction.write('a', 'new');
      await transaction.write('b', 'pending');
      expect(await transaction.read('a'), 'new');
      expect(storage.values, {'a': 'old'});
      await transaction.commit(() {});
      expect(storage.values, {'a': 'new', 'b': 'pending'});
      await expectLater(transaction.write('c', 'late'), throwsStateError);
    },
  );
  test('a later write failure restores earlier committed secrets', () async {
    final storage = _FailOnce();
    final transaction = SourceLoginStorageTransaction(storage);
    await transaction.write('a', 'new');
    await transaction.write('b', 'pending');
    await expectLater(transaction.commit(() {}), throwsStateError);
    expect(storage.values, {'a': 'old'});
  });
  test('cancellation during commit restores earlier writes', () async {
    final storage = MemorySourceSecureSessionStorage(
      initialValues: {'a': 'old'},
    );
    final transaction = SourceLoginStorageTransaction(storage);
    await transaction.write('a', 'new');
    await transaction.write('b', 'pending');
    var checks = 0;
    await expectLater(
      transaction.commit(() {
        if (checks++ == 1) throw const SourceLoginCancelled();
      }),
      throwsA(isA<SourceLoginCancelled>()),
    );
    expect(storage.values, {'a': 'old'});
  });
}
