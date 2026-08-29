import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_event.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;

  setUp(() async {
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
    await host.logStore.setCaptureEnabled(true);
    addTearDown(host.dispose);
  });

  test('stores and merges one application event instead of typed copies', () {
    for (var index = 0; index < 2; index++) {
      host.activeHandle.debugLog.addApplicationLog(
        level: 'info',
        title: 'Runtime ready',
        source: 'source_runtime',
        content: const {'phase': 'ready'},
      );
    }

    expect(host.logStore.events, hasLength(1));
    expect(host.logStore.events.single.occurrences, 2);
    expect(host.logStore.events.single.area, AppLogArea.source);
  });

  test('reader logs retain complete content', () {
    final longContent = {'durationMs': 4200, 'detail': 'x' * 500};

    host.activeHandle.debugLog.addReaderLog(
      level: 'warning',
      title: 'Frame duration',
      content: longContent,
      source: 'reader_position',
    );

    final event = host.logStore.events.single;
    expect(event.data, longContent);
    expect(event.area, AppLogArea.reader);
    expect(event.tags, contains('performance'));
    expect(event.level, AppLogLevel.warning);
  });

  test('explicit error logs use a real level instead of keyword guessing', () {
    host.activeHandle.debugLog.addDebugLog(
      type: 'error',
      level: 'info',
      title: 'Request failed',
      content: const {'reason': 'test'},
    );

    expect(host.logStore.events.single.level, AppLogLevel.error);
  });

  test('runtime recreation keeps using the same application log store', () {
    host.activeHandle.debugLog.addApplicationLog(
      level: 'info',
      title: 'Before recreation',
    );

    final replacement = host.recreateSourceRuntime('jm');
    replacement.debugLog.addApplicationLog(
      level: 'info',
      title: 'After recreation',
    );

    expect(host.logStore.events.map((event) => event.title), [
      'Before recreation',
      'After recreation',
    ]);
  });
}
