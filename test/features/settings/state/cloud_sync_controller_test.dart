import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/state/cloud_sync_controller.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockCloudSyncService extends Mock implements CloudSyncService {}

const _initialConfig = CloudSyncConfig(
  enabled: true,
  url: '',
  username: '',
  password: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(_initialConfig));

  test(
    'restore persists the entered WebDAV config before downloading',
    () async {
      final service = _MockCloudSyncService();
      CloudSyncConfig? savedConfig;
      const restoreResult = CloudSyncRestoreResult(
        restoredSettings: true,
        restoredReading: true,
        restoredSearchHistory: true,
        appliedPlatformFilteredKeys: [],
        skippedKeys: [],
      );
      when(service.loadConfig).thenAnswer((_) async => _initialConfig);
      when(() => service.saveConfig(any())).thenAnswer((invocation) async {
        savedConfig = invocation.positionalArguments.single as CloudSyncConfig;
      });
      when(
        () => service.restoreLatestBackup(
          configOverride: any(named: 'configOverride'),
        ),
      ).thenAnswer((_) async {
        expect(savedConfig, isNotNull);
        return restoreResult;
      });
      when(
        () => service.testConnection(
          configOverride: any(named: 'configOverride'),
        ),
      ).thenAnswer(
        (_) async => CloudSyncConnectionStatus(
          ok: true,
          message: 'ok',
          checkedAt: DateTime(2026),
        ),
      );

      final controller = CloudSyncController(service: service);
      addTearDown(controller.dispose);
      await controller.loadConfig();
      controller.urlController.text = ' https://dav.example.test/root ';
      controller.usernameController.text = ' user ';
      controller.passwordController.text = 'secret';

      await controller.restoreBackup(applyRestore: (_) async {});

      expect(savedConfig?.enabled, isTrue);
      expect(savedConfig?.url, 'https://dav.example.test/root');
      expect(savedConfig?.username, 'user');
      expect(savedConfig?.password, 'secret');
      verify(
        () => service.restoreLatestBackup(
          configOverride: any(named: 'configOverride'),
        ),
      ).called(1);
    },
  );
}
