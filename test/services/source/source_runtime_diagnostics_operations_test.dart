import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_event.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_diagnostics_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;
  late SourceRuntimeDiagnosticsOperations diagnostics;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
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
    diagnostics = SourceRuntimeDiagnosticsOperations(runtimeHost: host);
    addTearDown(host.dispose);
  });

  test(
    'disabling capture persists preference and clears diagnostics',
    () async {
      final facade = host.activeHandle.facade;
      facade.debug.softwareLogCaptureEnabled = true;
      facade.lastLoginDebugInfo = {'account': 'test'};
      facade.lastSourceVersionDebugInfo = {'version': '1.0.0'};
      host.logStore.add(
        level: 'error',
        area: AppLogArea.application,
        source: 'test',
        event: 'captured',
        title: 'captured',
      );

      await diagnostics.setSoftwareLogCaptureEnabled(false);

      expect(facade.softwareLogCaptureEnabled, isFalse);
      expect(host.logStore.events, isEmpty);
      expect(facade.debug.lastLoginDebugInfoStorage, isNull);
      expect(facade.debug.lastSourceVersionDebugInfoStorage, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SourcePrefsKeys.softwareLogCaptureEnabled), isFalse);
    },
  );

  test('loads capture preference and records retry diagnostics', () async {
    SharedPreferences.setMockInitialValues({
      SourcePrefsKeys.softwareLogCaptureEnabled: true,
    });

    expect(await diagnostics.loadSoftwareLogCaptureEnabled(), isTrue);
    diagnostics.logRuntimeRetryRequested('test_retry');

    expect(host.logStore.events, hasLength(1));
    expect(host.logStore.events.single.title, 'Source retry requested');
  });
}
