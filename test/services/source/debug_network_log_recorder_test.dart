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
        SourceCatalogEntry(key: 'jm', name: 'JMComic', fileName: 'jm.js'),
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

  test('samples successful image downloads out of captured logs', () {
    host.activeHandle.debugLog.appendNetworkLogEntry(
      method: 'GET',
      url: 'https://images.example/page.jpg',
      statusCode: 200,
      error: null,
      startedAt: DateTime.now(),
      category: 'image_download',
      responseBody: 'bytes',
    );

    expect(host.logStore.events, isEmpty);
  });

  test('retains failed request details in one network event', () {
    host.activeHandle.debugLog.appendNetworkLogEntry(
      method: 'POST',
      url: 'https://api.example/favorite',
      statusCode: 500,
      error: 'server error',
      startedAt: DateTime.now(),
      requestHeaders: const {'Authorization': 'Bearer secret'},
      responseHeaders: const {'Set-Cookie': 'session=secret'},
      responseBody: '{"error":"failed"}',
    );

    final event = host.logStore.events.single;
    expect(event.area, AppLogArea.network);
    expect(event.level, AppLogLevel.error);
    expect((event.data as Map)['responseBody'], '{"error":"failed"}');
    expect(
      ((event.data as Map)['requestHeaders'] as Map)['Authorization'],
      'Bearer secret',
    );
  });

  test('keeps only a summary for successful requests', () {
    host.activeHandle.debugLog.appendNetworkLogEntry(
      method: 'GET',
      url: 'https://api.example/comics',
      statusCode: 200,
      error: null,
      startedAt: DateTime.now(),
      requestHeaders: const {'Cookie': 'session=secret'},
      responseHeaders: const {'Content-Type': 'application/json'},
      responseBody: 'z' * 1000,
    );

    final event = host.logStore.events.single;
    final data = event.data as Map;
    expect(event.level, AppLogLevel.info);
    expect(data.containsKey('requestHeaders'), isFalse);
    expect(data.containsKey('responseHeaders'), isFalse);
    expect(data.containsKey('responseBody'), isFalse);
    expect(data['responseBodyPreview'], startsWith('z' * 300));
    expect((data['responseBodyPreview'] as String).length, lessThan(400));
  });

  test('classifies cancelled and client-error requests below error', () {
    host.activeHandle.debugLog.appendNetworkLogEntry(
      method: 'GET',
      url: 'https://api.example/cancelled',
      statusCode: null,
      error: 'DioException [request cancelled]',
      startedAt: DateTime.now(),
      cancelled: true,
    );
    host.activeHandle.debugLog.appendNetworkLogEntry(
      method: 'GET',
      url: 'https://api.example/missing',
      statusCode: 404,
      error: null,
      startedAt: DateTime.now(),
    );

    expect(host.logStore.events.map((event) => event.level), [
      AppLogLevel.debug,
      AppLogLevel.warning,
    ]);
    expect(host.logStore.events.first.title, 'GET CANCELLED');
  });

  test('merges consecutive duplicate network entries', () {
    for (var index = 0; index < 2; index++) {
      host.activeHandle.debugLog.appendNetworkLogEntry(
        method: 'GET',
        url: 'https://api.example/user',
        statusCode: 404,
        error: null,
        startedAt: DateTime.now().subtract(Duration(milliseconds: index * 20)),
        responseBody: 'missing',
      );
    }

    expect(host.logStore.events, hasLength(1));
    expect(host.logStore.events.single.occurrences, 2);
  });
}
