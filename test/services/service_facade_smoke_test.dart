import 'dart:typed_data';
import 'dart:convert';
import 'package:hazuki/app/service_locator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test(
    'HazukiSourceFacade keeps cache operations reachable via service API',
    () {
      final service = sl<HazukiSourceService>();
      final facade = service.facade;
      const url = 'https://example.com/image.jpg';
      final bytes = Uint8List.fromList([1, 2, 3]);

      facade.cache.evictImageBytes([url]);
      facade.cache.putImageBytes(
        SourceScopedComicId(
          sourceKey: hazukiDefaultSourceKey,
          comicId: url,
        ).imageCacheKey,
        bytes,
      );

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

      await sl<CloudSyncService>().saveConfig(config);
      final restored = await sl<CloudSyncService>().facade.configStore
          .loadConfig();
      final client = sl<CloudSyncService>().facade.remoteClient(restored);

      expect(restored.enabled, isTrue);
      expect(restored.url, 'https://example.com');
      expect(client.backupDirUrl, 'https://example.com/HazukiSync/backup');
    },
  );

  test('source registry exposes built-in source catalog entries', () {
    final registry = sl<SourceRuntimeRegistry>();

    expect(registry.activeSourceKey, hazukiDefaultSourceKey);
    expect(registry.allowedSources.map((source) => source.key), [
      'jm',
      'copy_manga',
    ]);
    expect(
      registry.allowedSources.first.matchesIndexEntry({
        'key': 'jm',
        'fileName': 'jm.js',
      }),
      isTrue,
    );
    expect(
      registry.allowedSources.last.matchesIndexEntry({
        'key': 'copy_manga',
        'fileName': 'copy_manga.js',
      }),
      isTrue,
    );
    expect(registry.isAllowedSourceKey('not-allowed'), isFalse);
  });

  test(
    'legacy account and cookie session data is cleared on prefs init',
    () async {
      SharedPreferences.setMockInitialValues({
        'cookie_store_v1': jsonEncode([
          {
            'name': 'sid',
            'value': 'legacy',
            'domain': 'example.com',
            'path': '/',
          },
        ]),
        'source_data_jm': jsonEncode({
          'account': ['user', 'pass'],
          'settings': {'favoriteOrder': 'mr'},
        }),
      });

      final service = sl<HazukiSourceService>();
      final prefs = await service.facade.ensurePrefs();
      final sourceData = jsonDecode(prefs.getString('source_data_jm')!);

      expect(prefs.getString('cookie_store_v1'), isNull);
      expect(sourceData, isA<Map>());
      expect((sourceData as Map).containsKey('account'), isFalse);
      expect(sourceData['settings'], {'favoriteOrder': 'mr'});
    },
  );
}
