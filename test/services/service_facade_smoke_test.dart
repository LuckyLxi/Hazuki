import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test(
    'HazukiSourceFacade keeps cache operations reachable via service API',
    () {
      final service = HazukiSourceService.instance;
      final facade = service.facade;
      const url = 'https://example.com/image.jpg';
      final bytes = Uint8List.fromList([1, 2, 3]);

      facade.cache.evictImageBytes([url]);
      facade.cache.putImageBytes(url, bytes);

      expect(service.peekImageBytesFromMemory(url), bytes);
      expect(
        facade
            .resolveImageBaseUri(
              'https://img.example.com/avatar.jpg',
              Uri.parse('https://base.example.com'),
            )
            .host,
        'img.example.com',
      );
    },
  );

  test(
    'CloudSyncFacade keeps config and remote client access reachable',
    () async {
      const config = CloudSyncConfig(
        enabled: true,
        url: 'https://example.com',
        username: 'hazuki',
        password: 'secret',
      );

      await CloudSyncService.instance.saveConfig(config);
      final restored = await CloudSyncService.instance.facade.configStore
          .loadConfig();
      final client = CloudSyncService.instance.facade.remoteClient(restored);

      expect(restored.enabled, isTrue);
      expect(restored.url, 'https://example.com');
      expect(client.backupDirUrl, 'https://example.com/HazukiSync/backup');
    },
  );
}
