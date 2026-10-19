import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_login_side_data_operations.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;

  setUp(() async {
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
    await host.activeHandle.facade.ensurePrefs();
    addTearDown(host.dispose);
  });

  test('persists common CopyManga token and normalized avatar', () async {
    final sideData = SourceLoginSideDataOperations(runtimeHost: host);
    final facade = host.activeHandle.facade;

    await sideData.persistLoginSideData(
      facade,
      sourceKey: 'copy_manga',
      result: {
        'token': 'copy-token',
        'avatarUrl': 'https://s3.mangafuna.xyz/user/cover/avatar.jpg',
      },
    );

    expect(facade.loadSourceData('copy_manga', 'token'), 'copy-token');
    expect(
      facade.runtime.transientAvatarUrl,
      'https://s3.mangafuna.xyz/user/cover/avatar.jpg',
    );
  });

  test(
    'persists plugin-normalized profile without site-specific parsing',
    () async {
      final sideData = SourceLoginSideDataOperations(runtimeHost: host);
      final facade = host.activeHandle.facade;
      await sideData.persistLoginSideData(
        facade,
        sourceKey: 'picacg',
        result: {
          'token': 'pica-token',
          'displayName': 'Picacg User',
          'avatarUrl': 'https://images.example/static/avatar.jpg',
        },
      );
      expect(facade.loadSourceData('picacg', 'token'), 'pica-token');
      expect(facade.loadSourceData('picacg', 'display_name'), 'Picacg User');
      expect(
        facade.loadSourceData('picacg', 'avatar_url'),
        'https://images.example/static/avatar.jpg',
      );
    },
  );

  test(
    'ignores non-profile results without changing stored credentials',
    () async {
      final sideData = SourceLoginSideDataOperations(runtimeHost: host);
      final facade = host.activeHandle.facade;
      await facade.saveSourceData('picacg', 'token', 'previous-token');
      await sideData.persistLoginSideData(
        facade,
        sourceKey: 'picacg',
        result: null,
      );
      expect(facade.loadSourceData('picacg', 'token'), 'previous-token');
    },
  );

  test('profile refresh failure falls back to persisted avatar', () async {
    final facade = host.activeHandle.facade;
    facade.runtime.engine = SourceScriptEngine()
      ..evaluate('''
        this.__hazuki_source = {account: {loadProfile() {
          throw new Error('offline');
        }}};
      ''');
    await facade.saveSourceData('jm', 'avatar_url', 'https://example/cached');
    final sideData = SourceLoginSideDataOperations(runtimeHost: host);

    expect(await sideData.loadCurrentAvatarUrl(), 'https://example/cached');
    expect(sideData.cachedAvatarUrl, 'https://example/cached');
  });

  test('concurrent profile refreshes share the same source request', () async {
    final refresh = Completer<dynamic>();
    var calls = 0;
    final facade = host.activeHandle.facade;
    facade.runtime.engine = SourceScriptEngine()
      ..setMessageHandler((_) {
        calls++;
        return refresh.future;
      })
      ..evaluate('''
        this.__hazuki_source = {account: {loadProfile: () => sendMessage({})}};
      ''');
    final sideData = SourceLoginSideDataOperations(runtimeHost: host);

    final first = sideData.loadCurrentAvatarUrl();
    final second = sideData.loadCurrentAvatarUrl();
    refresh.complete({'avatarUrl': 'https://example/new'});
    expect(await first, 'https://example/new');
    expect(await second, 'https://example/new');
    expect(calls, 1);
  });

  test('timed-out profile uses cache and ignores the late result', () async {
    final refresh = Completer<dynamic>();
    final facade = host.activeHandle.facade;
    facade.runtime.engine = SourceScriptEngine()
      ..setMessageHandler((_) => refresh.future)
      ..evaluate('''
        this.__hazuki_source = {account: {loadProfile: () => sendMessage({})}};
      ''');
    await facade.saveSourceData('jm', 'avatar_url', 'https://example/cached');
    final sideData = SourceLoginSideDataOperations(
      runtimeHost: host,
      profileLoadTimeout: const Duration(milliseconds: 10),
    );

    expect(await sideData.loadCurrentAvatarUrl(), 'https://example/cached');
    refresh.complete({'avatarUrl': 'https://example/late'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sideData.cachedAvatarUrl, 'https://example/cached');
  });

  test(
    'profile finishing after logout cannot restore persisted data',
    () async {
      final refresh = Completer<dynamic>();
      final requested = Completer<void>();
      final facade = host.activeHandle.facade;
      await facade.saveSourceData('jm', 'login_session', 'session');
      facade.runtime.engine = SourceScriptEngine()
        ..setMessageHandler((_) {
          requested.complete();
          return refresh.future;
        })
        ..evaluate('''
        this.__hazuki_source = {account: {loadProfile: () => sendMessage({})}};
      ''');
      final sideData = SourceLoginSideDataOperations(runtimeHost: host);
      final pending = sideData.loadCurrentAvatarUrl();
      await requested.future;
      await facade.deleteSourceData('jm', 'login_session');
      refresh.complete({
        'avatarUrl': 'https://example/old',
        'displayName': 'Old',
      });

      expect(await pending, isNull);
      expect(facade.loadSourceData('jm', 'avatar_url'), isNull);
      expect(facade.loadSourceData('jm', 'display_name'), isNull);
    },
  );
}
