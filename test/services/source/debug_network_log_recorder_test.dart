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

    expect(host.activeHandle.debug.recentNetworkLogs, isEmpty);
    expect(host.activeHandle.debug.recentSystemLogs, isEmpty);
  });

  test('retains failed request details with credentials redacted', () {
    host.activeHandle.debugLog.appendNetworkLogEntry(
      method: 'POST',
      url: 'https://api.example/favorite',
      statusCode: 500,
      error: 'server error',
      startedAt: DateTime.now(),
      requestHeaders: const {
        'Authorization': 'Bearer secret',
        'Content-Type': 'application/json',
      },
      requestData: const {'comicId': '123'},
      responseHeaders: const {'Set-Cookie': 'session=secret'},
      responseBody: '{"error":"failed"}',
    );

    final entry = host.activeHandle.debug.recentNetworkLogs.single;
    expect(entry['requestHeaders'], {
      'Authorization': '[redacted]',
      'Content-Type': 'application/json',
    });
    expect(entry['responseHeaders'], {'Set-Cookie': '[redacted]'});
    expect(entry['responseBodyFull'], '{"error":"failed"}');
    expect(host.activeHandle.debug.recentErrorLogs, hasLength(1));
  });

  test('merges duplicate network entries while retaining typed events', () {
    final startedAt = DateTime.now();
    for (var index = 0; index < 2; index++) {
      host.activeHandle.debugLog.appendNetworkLogEntry(
        method: 'GET',
        url: 'https://api.example/user',
        statusCode: 404,
        error: null,
        startedAt: startedAt,
        responseBody: 'missing',
      );
    }

    expect(host.activeHandle.debug.recentNetworkLogs, hasLength(1));
    expect(host.activeHandle.debug.recentNetworkLogs.single['mergedCount'], 2);
    expect(host.activeHandle.debug.networkLogDedupedCount, 1);
    final typedEventCount = host.activeHandle.debug.recentErrorLogs.fold<int>(
      0,
      (total, entry) => total + (entry['mergedCount'] as int? ?? 1),
    );
    expect(typedEventCount, 2);
  });
}
