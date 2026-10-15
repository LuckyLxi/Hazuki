import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:hazuki/services/source/plugins/source_plugin_buttons.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SourceRuntimeHandle> _loadPlugin(
  String id,
  _SiteFixtures fixtures,
) async {
  final handle = SourceRuntimeHandle(
    sourceKey: id,
    secureStorage: MemorySourceSecureSessionStorage(),
    ensureInitialized: (_) async {},
    notifyRuntimeStateChanged: (_) {},
  );
  handle.dio.httpClientAdapter = fixtures;
  await handle.session.ensurePrefs();
  final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
  bridge.configureDioCookieBridge(handle);
  final engine = SourceScriptEngine(
    timeout: 5000,
    hostPromiseRejectionHandler: (_) {},
  );
  handle.runtime.engine = engine;
  engine.setMessageHandler(
    (dynamic request) => bridge.handleJsMessageForHandle(handle, request),
  );
  engine.evaluate(await File('assets/init.js').readAsString());
  engine.evaluate(await File('assets/hazuki_plugin_sdk.js').readAsString());
  engine.evaluate(
    await File('test/fixtures/source_plugins/$id/main.js').readAsString(),
  );
  final manifest = registeredSourcePluginManifest(engine).toJson();
  handle.runtime.sourceMeta = SourceMeta(
    name: manifest['name'] as String,
    key: id,
    version: '1.0.1',
    supportsAccount: true,
    settingsDefaults: parseSourceSettingsDefaults(
      engine.evaluate('source.settings'),
    ),
    presentation: Map<String, dynamic>.from(manifest['presentation'] as Map),
  );
  addTearDown(handle.requestDispose);
  return handle;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'all three plugins declare existing button positions without lab or daily recommendation',
    () async {
      final expected = {
        'jm': {
          'checkIn/homeProfile',
          'autoCheckIn/other',
          'copyComicId/comicDetailInfo',
          'relatedComics/comicDetailTabs',
        },
        'copy_manga': {
          'resetDeviceInfo/advanced',
          'imageQuality/reading',
          'imageQuality/reader',
        },
        'picacg': {
          'checkIn/homeProfile',
          'autoCheckIn/other',
          'imageQuality/reading',
          'imageQuality/reader',
        },
      };
      for (final entry in expected.entries) {
        final handle = await _loadPlugin(entry.key, _SiteFixtures());
        final presentation = handle.runtime.sourceMeta!.presentation;
        final buttons = SourcePluginButton.parseList(presentation['buttons']);
        expect(
          buttons
              .map((button) => '${button.id}/${button.location.name}')
              .toSet(),
          entry.value,
        );
        if (entry.key == 'copy_manga') {
          expect(buttons.first.action, 'clearDeviceInfo');
        }
      }
    },
  );
  test('JM login, profile, check-in and image segments live in the plugin', () async {
    final handle = await _loadPlugin('jm', _SiteFixtures());
    final engine = handle.runtime.engine!;
    engine.evaluate(
      "jmRequest=async(method,path)=>path==='/login'?{uid:123}:path==='/daily_chk'?{msg:'签到成功'}:{daily_id:'today'};",
    );
    await handle.facade.js.resolve(
      engine.evaluate("source.account.login('user','password')"),
    );
    final result =
        await handle.facade.js.resolve(
              engine.evaluate('source.account.checkIn()'),
            )
            as Map;
    expect(result['status'], 'success');
    expect(
      (await handle.facade.js.resolve(
            engine.evaluate('source.account.loadProfile()'),
          )
          as Map)['avatarUrl'],
      contains('/media/users/123.jpg'),
    );
    expect(
      engine.evaluate(
        "source.comic.onImageLoad('https://img.example/a.jpg','1','250000').segments",
      ),
      10,
    );
    expect(
      engine.evaluate(
        "source.comic.onImageLoad('https://img.example/a.jpg','1','100000').segments",
      ),
      0,
    );
    expect(
      engine.evaluate(
        "source.comic.onImageLoad('https://img.example/a.gif?key=1','1','250000').segments",
      ),
      0,
    );
    final snapshot =
        await handle.facade.js.resolve(
              engine.evaluate('source.lines.snapshot()'),
            )
            as Map;
    expect(snapshot['apiDomains'], isA<List>());
  });
  test(
    'CopyManga returns normalized login data without host runtime recovery',
    () async {
      final fixtures = _SiteFixtures();
      final handle = await _loadPlugin('copy_manga', fixtures);
      final result =
          await handle.facade.js.resolve(
                handle.runtime.engine!.evaluate(
                  "source.account.login('user','password')",
                ),
              )
              as Map;
      expect(result['token'], 'copy-token');
      expect(result['avatarUrl'], 'https://s3.mangafuna.xyz/user/avatar.jpg');
      expect(result['displayName'], 'Copy User');
      final login = fixtures.requests.single;
      expect(
        login.headers['Content-Type'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(login.data.toString(), contains('\n&salt='));
      await handle.facade.js.resolve(
        handle.runtime.engine!.evaluate(
          "Hazuki.http.get('https://fixture.example/210')",
        ),
      );
      expect(handle.recreationRequested, false);
    },
  );
  test(
    'CopyManga refreshes runtime defaults without replacing user settings',
    () async {
      final fixtures = _SiteFixtures();
      final handle = await _loadPlugin('copy_manga', fixtures);
      final engine = handle.runtime.engine!;
      expect(engine.evaluate('copyBaseUrl()'), 'https://api.copy2000.online');

      await handle.facade.js.resolve(engine.evaluate('copyRefreshAppApi()'));
      expect(
        engine.evaluate('copyBaseUrl()'),
        'https://${fixtures.copyApiHost}',
      );

      fixtures.copyApiHost = 'next.fixture.example';
      await handle.facade.js.resolve(engine.evaluate('copyRefreshAppApi()'));
      expect(engine.evaluate('copyBaseUrl()'), 'https://next.fixture.example');

      await handle.facade.saveSourceSetting(
        'copy_manga',
        'base_url',
        'custom.fixture.example',
      );
      fixtures.copyApiHost = 'another.fixture.example';
      await handle.facade.js.resolve(engine.evaluate('copyRefreshAppApi()'));
      expect(
        engine.evaluate('copyBaseUrl()'),
        'https://custom.fixture.example',
      );
    },
  );
  test(
    'Picacg signs requests, loads profile, checks in and retries expired search',
    () async {
      final fixtures = _SiteFixtures();
      final handle = await _loadPlugin('picacg', fixtures);
      final engine = handle.runtime.engine!;
      final result =
          await handle.facade.js.resolve(
                engine.evaluate("source.account.login('user','password')"),
              )
              as Map;
      expect(result['displayName'], 'Pica User');
      expect(result['avatarUrl'], 'https://images.example/static/avatar.jpg');
      await handle.facade.saveSourceData('picacg', 'account', [
        'user',
        'password',
      ]);
      final checkIn =
          await handle.facade.js.resolve(
                engine.evaluate('source.account.checkIn()'),
              )
              as Map;
      expect(checkIn['status'], 'success');
      expect(
        await handle.facade.js.resolve(
          engine.evaluate('source.account.checkInStatus()'),
        ),
        true,
      );
      final search =
          await handle.facade.js.resolve(
                engine.evaluate("source.search.load('keyword',['dd'],1)"),
              )
              as Map;
      expect(search['comics'], isEmpty);
      expect(fixtures.searchAttempts, 2);
      expect(
        fixtures.requests.where((r) => r.uri.path.endsWith('/auth/sign-in')),
        hasLength(2),
      );
      for (final request in fixtures.requests.where(
        (r) => r.uri.path.contains('/users/'),
      )) {
        expect(request.headers['signature'], isNotEmpty);
        expect(request.headers['nonce'], isNotEmpty);
      }
      expect(
        (await handle.facade.js.resolve(
              engine.evaluate('source.favorites.loadComics(1,null)'),
            )
            as Map)['comics'],
        isEmpty,
      );
      expect(
        (await handle.facade.js.resolve(
              engine.evaluate("source.comic.loadComments('id',null,1,null)"),
            )
            as Map)['comments'],
        isEmpty,
      );
    },
  );
}

class _SiteFixtures implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String copyApiHost = 'refreshed.fixture.example';
  bool punched = false;
  int searchAttempts = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    var status = 200;
    Object response;
    if (path.endsWith('/api/v3/login')) {
      response = {
        'results': {
          'token': 'copy-token',
          'nickname': 'Copy User',
          'avatar': 'user/avatar.jpg',
        },
      };
    } else if (path.endsWith('/api/v3/system/network2')) {
      response = {
        'results': {
          'api': [
            [copyApiHost],
          ],
        },
      };
    } else if (path.endsWith('/auth/sign-in')) {
      response = {
        'data': {'token': 'pica-token'},
      };
    } else if (path.endsWith('/users/profile')) {
      response = {
        'data': {
          'user': {
            'name': 'Pica User',
            'avatar': {
              'fileServer': 'https://images.example',
              'path': 'avatar.jpg',
            },
            'isPunched': punched,
          },
        },
      };
    } else if (path.endsWith('/users/punch-in')) {
      punched = true;
      response = {'message': 'success'};
    } else if (path.endsWith('/210')) {
      status = 210;
      response = {};
    } else {
      if (path.contains('advanced-search') && searchAttempts++ == 0) {
        status = 401;
      }
      response = {
        'data': {
          'comics': {'docs': [], 'pages': 1},
          'comments': {'docs': [], 'pages': 1},
        },
      };
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
