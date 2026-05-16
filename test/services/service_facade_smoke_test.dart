import 'dart:typed_data';
import 'dart:convert';
import 'package:hazuki/app/service_locator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/source/debug/debug_log_internals.dart';
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
