import 'dart:typed_data';
import 'dart:convert';
import 'package:hazuki/app/service_locator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/source/debug/debug_log_internals.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
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
    'image memory cache can read a non-active source by sourceKey',
    () async {
      final service = sl<HazukiSourceService>();
      const url = 'https://example.com/shared-cover.jpg';
      final jmBytes = Uint8List.fromList([1, 2, 3]);
      final copyBytes = Uint8List.fromList([4, 5, 6]);

      service.facade.cache.putImageBytes(
        SourceScopedComicId(
          sourceKey: hazukiDefaultSourceKey,
          comicId: url,
        ).imageCacheKey,
        jmBytes,
      );

      await service.runtimeRegistry.activateSource('copy_manga');
      service.facade.cache.putImageBytes(
        SourceScopedComicId(
          sourceKey: 'copy_manga',
          comicId: url,
        ).imageCacheKey,
        copyBytes,
      );

      await service.runtimeRegistry.activateSource(hazukiDefaultSourceKey);

      expect(service.activeSourceKey, hazukiDefaultSourceKey);
      expect(service.peekImageBytesFromMemory(url), jmBytes);
      expect(
        service.peekImageBytesFromMemory(url, sourceKey: 'copy_manga'),
        copyBytes,
      );
      expect(service.activeSourceKey, hazukiDefaultSourceKey);
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
      'picacg',
    ]);
    expect(
      registry.allowedSources
          .firstWhere((s) => s.key == 'jm')
          .matchesIndexEntry({'key': 'jm', 'fileName': 'jm.js'}),
      isTrue,
    );
    expect(
      registry.allowedSources
          .firstWhere((s) => s.key == 'copy_manga')
          .matchesIndexEntry({
            'key': 'copy_manga',
            'fileName': 'copy_manga.js',
          }),
      isTrue,
    );
    expect(
      registry.allowedSources
          .firstWhere((s) => s.key == 'picacg')
          .matchesIndexEntry({'key': 'picacg', 'fileName': 'picacg.js'}),
      isTrue,
    );
    expect(registry.isAllowedSourceKey('not-allowed'), isFalse);
  });

  test('CopyManga avatar path is normalized to its CDN URL', () {
    expect(
      normalizeSourceAvatarUrl(
        sourceKey: 'copy_manga',
        avatar: 'user/cover/d91eed225c6811efbb8d06be79e70c23/177130.jpg',
      ),
      'https://s3.mangafuna.xyz/user/cover/d91eed225c6811efbb8d06be79e70c23/177130.jpg',
    );
    expect(
      normalizeSourceAvatarUrl(
        sourceKey: 'copy_manga',
        avatar:
            'https://s3.mangafuna.xyz/user/cover/d91eed225c6811efbb8d06be79e70c23/177130.jpg',
      ),
      'https://s3.mangafuna.xyz/user/cover/d91eed225c6811efbb8d06be79e70c23/177130.jpg',
    );
  });

  test('relative non-CopyManga avatar path uses image base when available', () {
    expect(
      normalizeSourceAvatarUrl(
        sourceKey: hazukiDefaultSourceKey,
        avatar: '/media/users/123.jpg',
        imageBase: 'https://cdn.example.com/images/',
      ),
      'https://cdn.example.com/media/users/123.jpg',
    );
    expect(
      normalizeSourceAvatarUrl(
        sourceKey: hazukiDefaultSourceKey,
        avatar: 'media/users/123.jpg',
      ),
      isNull,
    );
  });

  test('Picacg avatar object uses fullUrl or fileServer static path', () {
    expect(
      normalizeSourceAvatarUrl(
        sourceKey: 'picacg',
        avatar: {
          'fullUrl': 'https://storage-b.picacomic.com/static/tobs/avatar.jpg',
          'path': 'ignored.jpg',
          'fileServer': 'https://unused.example.com',
        },
      ),
      'https://storage-b.picacomic.com/static/tobs/avatar.jpg',
    );

    expect(
      normalizeSourceAvatarUrl(
        sourceKey: 'picacg',
        avatar: {
          'path': 'tobs/94d06234-fe51-4194-b8fb-434e02b5dae2.jpg',
          'fileServer': 'https://storage-b.picacomic.com',
        },
      ),
      'https://storage-b.picacomic.com/static/tobs/94d06234-fe51-4194-b8fb-434e02b5dae2.jpg',
    );
  });

  test(
    'legacy source secrets migrate to secure storage on prefs init',
    () async {
      final legacyCookies = jsonEncode([
        {
          'name': 'sid',
          'value': 'legacy',
          'domain': 'example.com',
          'path': '/',
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'cookie_store_v1': legacyCookies,
        'cookie_store_v2_jm': legacyCookies,
        'source_data_jm': jsonEncode({
          'account': ['user', 'pass'],
          'token': 'source-token',
          'settings': {'favoriteOrder': 'mr'},
        }),
      });
      final secureStorage = MemorySourceSecureSessionStorage();
      final service = HazukiSourceService(secureSessionStorage: secureStorage);

      final prefs = await service.facade.ensurePrefs();
      final sourceData = jsonDecode(prefs.getString('source_data_jm')!);

      expect(prefs.getString('cookie_store_v1'), isNull);
      expect(prefs.getString('cookie_store_v2_jm'), isNull);
      expect(sourceData, isA<Map>());
      expect((sourceData as Map).containsKey('account'), isFalse);
      expect(sourceData.containsKey('token'), isFalse);
      expect(sourceData['settings'], {'favoriteOrder': 'mr'});
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.account('jm')],
        jsonEncode(['user', 'pass']),
      );
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.token('jm')],
        'source-token',
      );
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.cookies('jm')],
        legacyCookies,
      );
      expect(service.facade.loadAccountDataSync(), ['user', 'pass']);
      expect(service.facade.loadSourceData('jm', 'token'), 'source-token');
    },
  );

  test(
    'legacy source secrets are retained when secure migration fails',
    () async {
      final legacyCookies = jsonEncode([
        {
          'name': 'sid',
          'value': 'legacy',
          'domain': 'example.com',
          'path': '/',
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'cookie_store_v2_jm': legacyCookies,
        'source_data_jm': jsonEncode({
          'account': ['user', 'pass'],
          'token': 'source-token',
          'settings': {'favoriteOrder': 'mr'},
        }),
      });
      final secureStorage = MemorySourceSecureSessionStorage()
        ..failWrites = true;
      final service = HazukiSourceService(secureSessionStorage: secureStorage);

      final prefs = await service.facade.ensurePrefs();
      final sourceData = jsonDecode(prefs.getString('source_data_jm')!);

      expect((sourceData as Map)['account'], ['user', 'pass']);
      expect(sourceData['token'], 'source-token');
      expect(prefs.getString('cookie_store_v2_jm'), legacyCookies);
      expect(service.facade.loadAccountDataSync(), ['user', 'pass']);
      expect(service.facade.loadSourceData('jm', 'token'), 'source-token');

      await expectLater(
        service.facade.saveSourceData('jm', 'account', ['next', 'secret']),
        throwsStateError,
      );
      final afterFailedLoginSave = jsonDecode(
        prefs.getString('source_data_jm')!,
      );
      expect((afterFailedLoginSave as Map)['account'], ['user', 'pass']);
    },
  );

  test(
    'loads secure account state for non-active sources on startup',
    () async {
      SharedPreferences.setMockInitialValues({
        'source_secure_session_migration_v1': true,
      });
      final secureStorage = MemorySourceSecureSessionStorage(
        initialValues: {
          SourceSecureSessionStorageKeys.account('copy_manga'): jsonEncode([
            'copy-user',
            'copy-pass',
          ]),
        },
      );
      final service = HazukiSourceService(secureSessionStorage: secureStorage);

      await service.loadActiveSourcePreference();

      expect(service.activeSourceKey, hazukiDefaultSourceKey);
      expect(service.currentAccountForSource('copy_manga'), 'copy-user');
      expect(service.isLoggedForSource('copy_manga'), isTrue);
    },
  );

  test(
    'logout deletes secure source secrets without clearing settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'source_data_jm': jsonEncode({
          'settings': {'favoriteOrder': 'mr'},
          'display_name': 'Display',
        }),
      });
      final secureStorage = MemorySourceSecureSessionStorage();
      final service = HazukiSourceService(secureSessionStorage: secureStorage);
      await service.facade.ensurePrefs();
      await service.facade.saveSourceData('jm', 'account', ['user', 'pass']);
      await service.facade.saveSourceData('jm', 'token', 'source-token');
      await service.saveCookiesFromHeadersForHandle(
        service.facade.handle,
        'https://example.com/path',
        {
          'set-cookie': ['sid=abc; Path=/'],
        },
      );

      await service.logout();
      final prefs = await SharedPreferences.getInstance();
      final sourceData = jsonDecode(prefs.getString('source_data_jm')!);

      expect(service.facade.loadAccountDataSync(), isNull);
      expect(service.facade.loadSourceData('jm', 'token'), isNull);
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.account('jm')],
        isNull,
      );
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.token('jm')],
        isNull,
      );
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.cookies('jm')],
        isNull,
      );
      expect(sourceData['settings'], {'favoriteOrder': 'mr'});
      expect(sourceData.containsKey('display_name'), isFalse);
    },
  );

  test('debug export data keeps full typed log content', () async {
    final service = sl<HazukiSourceService>();
    await service.setSoftwareLogCaptureEnabled(true);
    final longMessage = 'avatar-${'x' * 520}';

    service.addApplicationLog(
      level: 'info',
      title: 'Avatar diagnostic',
      source: 'source_avatar',
      content: {'message': longMessage},
    );

    final debugInfo = await service.collectTypedDebugInfo(debugLogTypeSystem);
    final logs = (debugInfo['logs'] as List).cast<Map>();
    final log = logs.last.cast<String, dynamic>();

    expect(log['content'].toString(), contains('[omitted'));
    expect(log['contentFull'], {'message': longMessage});
  });

  test('application debug export data keeps full log content', () async {
    final service = sl<HazukiSourceService>();
    await service.setSoftwareLogCaptureEnabled(true);
    final longMessage = 'picacg-${'u' * 520}';

    service.addApplicationLog(
      level: 'info',
      title: 'Picacg login server response',
      source: 'source_login',
      content: {'body': longMessage},
    );

    final debugInfo = await service.collectApplicationDebugInfo();
    final logs = (debugInfo['recentApplicationLogs'] as List).cast<Map>();
    final log = logs.last.cast<String, dynamic>();

    expect(log['content'].toString(), contains('[omitted'));
    expect(log['contentFull'], {'body': longMessage});
  });

  test('network debug export data keeps full response body', () async {
    final service = sl<HazukiSourceService>();
    await service.setSoftwareLogCaptureEnabled(true);
    final longBody = '{"body":"${'y' * 1400}"}';

    service.appendNetworkLogEntry(
      method: 'POST',
      url: 'source://account.login',
      statusCode: 200,
      error: null,
      startedAt: DateTime.now(),
      source: 'source_login',
      responseBody: longBody,
    );

    final debugInfo = await service.collectNetworkDebugInfo();
    final logs = (debugInfo['recentNetworkLogs'] as List).cast<Map>();
    final log = logs.last.cast<String, dynamic>();

    expect(log['responseBodyPreview'].toString(), contains('[omitted'));
    expect(log['responseBodyFull'], longBody);
  });
}
