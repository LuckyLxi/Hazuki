import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_event.dart';
import 'package:hazuki/services/logging/app_log_store.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists raw log details encrypted and restores them', () async {
    final directory = await Directory.systemTemp.createTemp('hazuki-log-test-');
    final secureStorage = MemorySourceSecureSessionStorage();
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final store = AppLogStore(
      secureStorage: secureStorage,
      supportDirectory: () async => directory,
    );
    await store.initialize(captureEnabled: true);
    store.add(
      level: 'error',
      area: AppLogArea.network,
      source: 'test',
      event: 'request_failed',
      title: 'Request failed',
      data: const {'Authorization': 'Bearer original-secret'},
    );
    await store.flush();

    final file = File(
      '${directory.path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}events_v2.enc',
    );
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), isNot(contains('original-secret')));

    final restored = AppLogStore(
      secureStorage: secureStorage,
      supportDirectory: () async => directory,
    );
    await restored.initialize(captureEnabled: true);

    expect(restored.events, hasLength(1));
    expect(
      (restored.events.single.data as Map)['Authorization'],
      'Bearer original-secret',
    );
    store.dispose();
    restored.dispose();
  });

  test('clear removes memory, encrypted logs, and legacy history', () async {
    final directory = await Directory.systemTemp.createTemp('hazuki-log-test-');
    final logsDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}logs',
    );
    await logsDirectory.create(recursive: true);
    final legacy = File(
      '${logsDirectory.path}${Platform.pathSeparator}history_v1.json',
    );
    await legacy.writeAsString('[]');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final store = AppLogStore(
      secureStorage: MemorySourceSecureSessionStorage(),
      supportDirectory: () async => directory,
    );
    await store.initialize(captureEnabled: true);
    store.add(
      level: 'error',
      area: AppLogArea.application,
      source: 'test',
      event: 'error',
      title: 'Error',
    );
    await store.flush();
    await store.clear();

    expect(store.events, isEmpty);
    expect(await legacy.exists(), isFalse);
    expect(
      await File(
        '${logsDirectory.path}${Platform.pathSeparator}events_v2.enc',
      ).exists(),
      isFalse,
    );
    store.dispose();
  });

  test('disabled capture clears and rejects logs at every level', () async {
    final directory = await Directory.systemTemp.createTemp('hazuki-log-test-');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = AppLogStore(
      secureStorage: MemorySourceSecureSessionStorage(),
      supportDirectory: () async => directory,
    );
    await store.initialize(captureEnabled: true);
    for (final level in const ['info', 'warning', 'error']) {
      store.add(
        level: level,
        area: AppLogArea.application,
        source: 'test',
        event: level,
        title: level,
      );
    }

    await store.setCaptureEnabled(false);
    for (final level in const ['info', 'warning', 'error']) {
      store.add(
        level: level,
        area: AppLogArea.application,
        source: 'test',
        event: 'disabled_$level',
        title: level,
      );
    }

    expect(store.events, isEmpty);
    store.dispose();
  });

  test('disabling capture waits for an in-flight write to stop', () async {
    final directory = await Directory.systemTemp.createTemp('hazuki-log-test-');
    final secureStorage = _DelayedSecretStorage();
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = AppLogStore(
      secureStorage: secureStorage,
      supportDirectory: () async => directory,
    );
    await store.initialize(captureEnabled: true);
    store.add(
      level: 'error',
      area: AppLogArea.application,
      source: 'test',
      event: 'error',
      title: 'Error',
    );

    final flushing = store.flush();
    await Future<void>.delayed(Duration.zero);
    final disabling = store.setCaptureEnabled(false);
    secureStorage.allowReads.complete();
    await Future.wait([flushing, disabling]);

    final file = File(
      '${directory.path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}events_v2.enc',
    );
    expect(await file.exists(), isFalse);
    expect(store.events, isEmpty);
    store.dispose();
  });

  test('reenabling capture preserves logs written while disabling', () async {
    final directory = await Directory.systemTemp.createTemp('hazuki-log-test-');
    final secureStorage = _DelayedSecretStorage();
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = AppLogStore(
      secureStorage: secureStorage,
      supportDirectory: () async => directory,
    );
    await store.initialize(captureEnabled: true);
    store.add(
      level: 'error',
      area: AppLogArea.application,
      source: 'test',
      event: 'old_error',
      title: 'Old error',
    );

    final oldFlush = store.flush();
    await Future<void>.delayed(Duration.zero);
    final disabling = store.setCaptureEnabled(false);
    await store.setCaptureEnabled(true);
    store.add(
      level: 'error',
      area: AppLogArea.application,
      source: 'test',
      event: 'new_error',
      title: 'New error',
    );
    final newFlush = store.flush();
    secureStorage.allowReads.complete();
    await Future.wait([oldFlush, disabling, newFlush]);

    final restored = AppLogStore(
      secureStorage: secureStorage,
      supportDirectory: () async => directory,
    );
    await restored.initialize(captureEnabled: true);
    expect(restored.events.map((event) => event.event), ['new_error']);
    store.dispose();
    restored.dispose();
  });

  test('an in-flight background write cannot recreate cleared logs', () async {
    final directory = await Directory.systemTemp.createTemp('hazuki-log-test-');
    final secureStorage = _DelayedSecretStorage();
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = AppLogStore(
      secureStorage: secureStorage,
      supportDirectory: () async => directory,
    );
    await store.initialize(captureEnabled: true);
    store.add(
      level: 'error',
      area: AppLogArea.application,
      source: 'test',
      event: 'error',
      title: 'Error',
    );

    final flushing = store.flush();
    await Future<void>.delayed(Duration.zero);
    await store.clear();
    secureStorage.allowReads.complete();
    await flushing;

    final file = File(
      '${directory.path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}events_v2.enc',
    );
    expect(await file.exists(), isFalse);
    expect(store.events, isEmpty);
    store.dispose();
  });

  test(
    'a write already past encryption cannot recreate cleared logs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hazuki-log-test-',
      );
      final secureStorage = MemorySourceSecureSessionStorage();
      final supportDirectory = _DelayedSupportDirectory(directory);
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final store = AppLogStore(
        secureStorage: secureStorage,
        supportDirectory: supportDirectory.call,
      );
      await store.initialize(captureEnabled: true);
      store.add(
        level: 'error',
        area: AppLogArea.application,
        source: 'test',
        event: 'error',
        title: 'Error',
      );

      supportDirectory.delayNextCall = true;
      final flushing = store.flush();
      await supportDirectory.callStarted.future;
      await store.clear();
      supportDirectory.allowCall.complete();
      await flushing;

      final file = File(
        '${directory.path}${Platform.pathSeparator}logs'
        '${Platform.pathSeparator}events_v2.enc',
      );
      expect(await file.exists(), isFalse);
      store.dispose();
    },
  );

  test(
    'skips an individual event that exceeds the persistence limit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'hazuki-log-test-',
      );
      final secureStorage = MemorySourceSecureSessionStorage();
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final store = AppLogStore(
        secureStorage: secureStorage,
        supportDirectory: () async => directory,
      );
      await store.initialize(captureEnabled: true);
      store.add(
        level: 'error',
        area: AppLogArea.network,
        source: 'test',
        event: 'response',
        title: 'Oversized response',
        data: 'x' * (AppLogStore.maxPersistentBytes + 1),
      );
      await store.flush();

      final file = File(
        '${directory.path}${Platform.pathSeparator}logs'
        '${Platform.pathSeparator}events_v2.enc',
      );
      expect(
        await file.length(),
        lessThanOrEqualTo(AppLogStore.maxPersistentBytes),
      );
      final restored = AppLogStore(
        secureStorage: secureStorage,
        supportDirectory: () async => directory,
      );
      await restored.initialize(captureEnabled: true);
      expect(restored.events, isEmpty);
      store.dispose();
      restored.dispose();
    },
  );
}

class _DelayedSecretStorage implements AppLogSecretStorage {
  final Completer<void> allowReads = Completer<void>();
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    await allowReads.future;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedSupportDirectory {
  _DelayedSupportDirectory(this.directory);

  final Directory directory;
  bool delayNextCall = false;
  final Completer<void> callStarted = Completer<void>();
  final Completer<void> allowCall = Completer<void>();

  Future<Directory> call() async {
    if (delayNextCall) {
      delayNextCall = false;
      callStarted.complete();
      await allowCall.future;
    }
    return directory;
  }
}
