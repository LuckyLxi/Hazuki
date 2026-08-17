import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;

  setUp(() {
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'jm.js',
          directUrls: [],
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    host.activeHandle.facade.debug.softwareLogCaptureEnabled = true;
    addTearDown(host.dispose);
  });

  test('application logs retain their stream and classify system events', () {
    for (var index = 0; index < 2; index++) {
      host.activeHandle.debugLog.addApplicationLog(
        level: 'info',
        title: 'Runtime ready',
        source: 'source_runtime',
        content: const {'phase': 'ready'},
      );
    }

    expect(host.activeHandle.debug.recentApplicationLogs, hasLength(1));
    expect(
      host.activeHandle.debug.recentApplicationLogs.single['mergedCount'],
      2,
    );
    expect(host.activeHandle.debug.recentSystemLogs, hasLength(1));
    expect(host.activeHandle.debug.recentSystemLogs.single['mergedCount'], 2);
  });

  test('reader logs classify performance events and retain full content', () {
    final longContent = {'durationMs': 4200, 'detail': 'x' * 500};

    host.activeHandle.debugLog.addReaderLog(
      level: 'warning',
      title: 'Frame duration',
      content: longContent,
    );

    final reader = host.activeHandle.debug.recentReaderLogs.single;
    expect(reader['contentFull'], longContent);
    expect(host.activeHandle.debug.recentPerformanceLogs, hasLength(1));
  });

  test('explicit logs normalize unknown types and warning levels', () {
    host.activeHandle.debugLog.addDebugLog(
      type: 'unknown',
      level: 'warning',
      title: 'Action',
      content: const {'trigger': 'tap'},
    );

    final entry = host.activeHandle.debug.recentActionLogs.single;
    expect(entry['type'], 'action');
    expect(entry['level'], 'warn');
  });

  test('new logs prune entries older than the retention window', () {
    host.activeHandle.debug.recentApplicationLogs.add({
      'time': DateTime.now()
          .subtract(const Duration(days: 8))
          .toIso8601String(),
    });
    host.activeHandle.debug.lastAgeCleanupAt = null;

    host.activeHandle.debugLog.addDebugLog(
      type: 'system',
      level: 'info',
      title: 'Fresh',
    );

    expect(host.activeHandle.debug.recentApplicationLogs, isEmpty);
  });
}
