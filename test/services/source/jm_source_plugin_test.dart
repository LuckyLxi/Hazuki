import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/account/source_daily_check_in_capability.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _encrypt(Object data, String secret) {
  final key = Uint8List.fromList(
    utf8.encode(md5.convert(utf8.encode(secret)).toString()),
  );
  final plain = utf8.encode(jsonEncode(data));
  final padding = 16 - plain.length % 16;
  final bytes = Uint8List.fromList([
    ...plain,
    ...List.filled(padding, padding),
  ]);
  final cipher = ECBBlockCipher(AESEngine())..init(true, KeyParameter(key));
  final encrypted = Uint8List(bytes.length);
  for (var offset = 0; offset < bytes.length; offset += 16) {
    cipher.processBlock(bytes, offset, encrypted, offset);
  }
  return base64Encode(encrypted);
}

class _JmFixtures implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <String, Object>{
    '/setting': {'img_host': 'https://images.fixture.example'},
    '/login': {'uid': 123, 'nickname': 'JM User', 'photo': 'custom.jpg'},
    '/daily': {'daily_id': 'today'},
    '/daily_chk': {'msg': '签到成功'},
    '/promote': [
      {
        'title': '最新更新',
        'type': 'category_id',
        'slug': 'doujin',
        'content': [
          {'id': 7, 'name': 'New comic'},
        ],
      },
      {'title': 'Library', 'type': 'library', 'content': []},
    ],
    '/search': {
      'total': 81,
      'content': [
        {'id': 7, 'name': 'Comic', 'author': 'Author'},
      ],
    },
    '/categories/filter': {
      'total': 80,
      'content': [
        {'id': 7, 'name': 'Category comic'},
      ],
    },
    '/week': {
      'categories': [
        {'id': 4, 'time': 'Week 4'},
      ],
    },
    '/week/filter': {
      'list': [
        {'id': 7, 'name': 'Weekly comic'},
      ],
    },
    '/favorite': {
      'total': 20,
      'list': [
        {'id': 7, 'name': 'Favorite'},
      ],
      'folder_list': [
        {'FID': 2, 'name': 'Folder'},
      ],
    },
    '/favorite_folder': <String, Object>{},
    '/album': {
      'name': 'Details',
      'likes': '5',
      'total_views': 123,
      'series': [
        {'id': 12, 'sort': 2, 'name': ' '},
        {'id': 11, 'sort': 1, 'name': 'First'},
      ],
      'related_list': [
        {'id': 8, 'name': 'Related', 'author': 'Related author'},
      ],
    },
    '/chapter': {
      'images': ['001.jpg', '002.gif'],
    },
    '/forum': {
      'total': 6,
      'list': [
        {
          'CID': 9,
          'username': 'Reader',
          'photo': '//images.fixture.example/avatar.jpg',
          'content': '<p>Hello</p>',
        },
      ],
    },
    '/comment': {'status': 'ok'},
    '/like': {'code': 200, 'status': 'ok'},
  };
  bool failDomains = false;
  bool unauthorized = false;
  bool unauthorizedDaily = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.path.endsWith('/newsvr-2025.txt')) {
      return ResponseBody.fromString(
        failDomains
            ? 'offline'
            : _encrypt({
                'Server': ['api.fixture.example', 'second.fixture.example'],
              }, 'diosfjckwpqpdfjkvnqQjsik'),
        failDomains ? 503 : 200,
      );
    }
    final time = options.headers['tokenparam'].toString().split(',').first;
    expect(options.headers['tokenparam'], '$time,2.0.16');
    expect(
      options.headers['token'],
      md5.convert(utf8.encode('${time}18comicAPPContent')).toString(),
    );
    final data = responses[options.uri.path];
    if (data == null) throw StateError('Unexpected JM request: ${options.uri}');
    return ResponseBody.fromString(
      jsonEncode({'data': _encrypt(data, '${time}185Hcomic3PAPP7R')}),
      unauthorized || (unauthorizedDaily && options.uri.path == '/daily')
          ? 401
          : 200,
      headers: {
        'content-type': ['application/json'],
        if (options.uri.path == '/login')
          'set-cookie': ['sid=fixture; Path=/; HttpOnly'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceRuntimeHandle handle;
  late _JmFixtures fixtures;
  late SourceScriptEngine engine;
  Future<dynamic> run(String code) =>
      handle.facade.js.resolve(engine.evaluate(code));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixtures = _JmFixtures();
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'main.js',
          presentation: {'dailyCheckIn': true},
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    handle = host.activeHandle;
    handle.dio.httpClientAdapter = fixtures;
    await handle.session.ensurePrefs();
    final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
    bridge.configureDioCookieBridge(handle);
    engine = SourceScriptEngine(
      timeout: 5000,
      hostPromiseRejectionHandler: (_) {},
    );
    handle.runtime.engine = engine;
    engine.setMessageHandler(
      (dynamic message) => bridge.handleJsMessageForHandle(handle, message),
    );
    engine.evaluate(await File('assets/init.js').readAsString());
    engine.evaluate(await File('assets/hazuki_plugin_sdk.js').readAsString());
    // Prove the plugin uses only documented SDK APIs, without legacy globals.
    engine.evaluate(
      'Network=undefined;Convert=undefined;Comic=undefined;ComicDetails=undefined;Comment=undefined;HazukiSource=undefined;',
    );
    engine.evaluate(
      await File('test/fixtures/source_plugins/jm/main.js').readAsString(),
    );
    handle.runtime.sourceMeta = SourceMeta(
      name: 'JMComic',
      key: 'jm',
      version: '1.0.1',
      supportsAccount: true,
      settingsDefaults: parseSourceSettingsDefaults(
        engine.evaluate('source.settings'),
      ),
    );
  });

  tearDown(() => host.dispose());

  Future<void> storeAccount() async {
    await handle.facade.saveSourceData('jm', 'account', ['user', 'password']);
    await handle.facade.saveSourceData('jm', 'uid', 123);
  }

  test(
    'host and JM share the date and skip repeated check-in requests',
    () async {
      await storeAccount();
      final capability = SourceDailyCheckInCapability(
        runtimeHost: host,
        reloginCoordinator: SourceReloginCoordinator(
          loginWithStoredAccount:
              (_, {required account, required password}) async {
                fail('A valid session should not require relogin');
              },
        ),
      );

      expect((await capability.perform()).isSuccess, isTrue);
      expect(
        handle.facade.loadSourceData('jm', 'lastCheckInDate'),
        engine.evaluate('jmToday()'),
      );
      expect(await capability.isCompletedToday(), isTrue);
      final requestCount = fixtures.requests.length;
      expect((await capability.perform()).isAlreadyCheckedIn, isTrue);
      expect(fixtures.requests, hasLength(requestCount));
    },
  );

  test(
    'JM recognizes the existing ISO check-in date without a request',
    () async {
      await storeAccount();
      await handle.facade.saveSourceData(
        'jm',
        'lastCheckInDate',
        SourceDailyCheckInCapability.dailyCheckInDateTag(DateTime.now()),
      );
      expect(await run('source.account.checkInStatus()'), isTrue);
      expect(
        (await run('source.account.checkIn()') as Map)['status'],
        'alreadyCheckedIn',
      );
      expect(fixtures.requests, isEmpty);
    },
  );

  for (final retryStillExpired in [false, true]) {
    test(
      'host retries expired JM check-in once (still expired: $retryStillExpired)',
      () async {
        await storeAccount();
        fixtures.unauthorizedDaily = true;
        var relogins = 0;
        final capability = SourceDailyCheckInCapability(
          runtimeHost: host,
          reloginCoordinator: SourceReloginCoordinator(
            loginWithStoredAccount:
                (_, {required account, required password}) async {
                  relogins++;
                  expect(account, 'user');
                  expect(password, 'password');
                  await run("source.account.login('user','password')");
                  fixtures.unauthorizedDaily = retryStillExpired;
                },
          ),
        );

        if (retryStillExpired) {
          await expectLater(capability.perform(), throwsA(anything));
          expect(handle.facade.loadSourceData('jm', 'lastCheckInDate'), isNull);
        } else {
          expect((await capability.perform()).isSuccess, isTrue);
          expect(await capability.isCompletedToday(), isTrue);
        }
        expect(relogins, 1);
        expect(
          fixtures.requests.where((r) => r.uri.path == '/daily'),
          hasLength(2),
        );
        expect(
          fixtures.requests.where((r) => r.uri.path == '/login'),
          hasLength(1),
        );
      },
    );
  }

  test('ordinary check-in errors do not trigger relogin', () async {
    await storeAccount();
    fixtures.responses['/daily_chk'] = {
      'status': 'fail',
      'msg': 'Server error',
    };
    var relogins = 0;
    final capability = SourceDailyCheckInCapability(
      runtimeHost: host,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {
              relogins++;
            },
      ),
    );
    await expectLater(capability.perform(), throwsA(anything));
    expect(relogins, 0);
    expect(handle.facade.loadSourceData('jm', 'lastCheckInDate'), isNull);
  });

  test(
    'registration is local and retains the JM identity and settings',
    () async {
      final manifest = await SourcePluginScriptInspector().inspect(
        await File('test/fixtures/source_plugins/jm/main.js').readAsString(),
      );
      expect(manifest.id, 'jm');
      expect(fixtures.requests, isEmpty);
      expect(engine.evaluate("source.settings.apiDomain.default"), '1');
      expect(
        engine.evaluate(
          "Object.values(source.settings).some(s=>s.type==='callback')",
        ),
        isFalse,
      );
    },
  );

  test('login awaits storage and returns standard profile fields', () async {
    final result = await run("source.account.login('a&b','p=+&')") as Map;
    expect(result['displayName'], 'JM User');
    expect(result['avatarUrl'], endsWith('/media/users/custom.jpg'));
    expect(result.containsKey('token'), isFalse);
    expect(handle.facade.loadSourceData('jm', 'uid'), 123);
    expect(Uri.splitQueryString(fixtures.requests.single.data as String), {
      'username': 'a&b',
      'password': 'p=+&',
    });
    expect(await run('source.account.loadProfile()'), result);

    await handle.facade.deleteSourceData('jm', 'profile');
    await handle.facade.saveSourceData('jm', 'account', [
      'Legacy user',
      'password',
    ]);
    final legacy = await run('source.account.loadProfile()') as Map;
    expect(legacy['displayName'], 'Legacy user');
    expect(legacy['avatarUrl'], endsWith('/media/users/123.jpg'));
  });

  test('invalid login and expired requests report errors', () async {
    fixtures.responses['/login'] = {'msg': 'Bad password'};
    await expectLater(
      run("source.account.login('user','bad')"),
      throwsA(anything),
    );
    expect(handle.facade.loadSourceData('jm', 'uid'), isNull);
    await expectLater(
      run('source.account.loadProfile()'),
      throwsA(
        predicate((Object e) => e.toString().contains('HAZUKI_AUTH_EXPIRED')),
      ),
    );
    fixtures.unauthorized = true;
    await expectLater(
      run("source.search.load('keyword',['mr'],1)"),
      throwsA(
        predicate((Object e) => e.toString().contains('HAZUKI_AUTH_EXPIRED')),
      ),
    );
  });

  test(
    'init refreshes signed lines and settings refresh the image host',
    () async {
      await run('source.init()');
      final lines = await run('source.lines.snapshot()') as Map;
      expect(lines['apiDomains'], [
        'api.fixture.example',
        'second.fixture.example',
      ]);
      expect(lines['imageHost'], 'https://images.fixture.example');
      expect(fixtures.requests.last.uri.host, 'api.fixture.example');
      await run(
        "Hazuki.settings.set('imageStream','2');source.settings.imageStream.onChanged('2')",
      );
      expect(fixtures.requests.last.uri.queryParameters['app_img_shunt'], '2');
      fixtures.failDomains = true;
      await run('source.actions.refreshLines()');
      expect(
        (await run('source.lines.snapshot()') as Map)['apiDomains'],
        contains('www.cdntwice.org'),
      );
    },
  );

  test(
    'explore, search, categories and rankings return standard comic pages',
    () async {
      final sections = await run('source.explore[0].load(1)') as List;
      expect(sections, hasLength(1));
      expect((sections.single as Map)['offersInitialComicsFilter'], isTrue);
      expect((sections.single as Map)['viewMore'], 'category:最新更新@doujin');
      final search = await run("source.search.load('a b&c',['mv'],2)") as Map;
      expect(search['maxPage'], 2);
      expect(((search['comics'] as List).single as Map)['subTitle'], isNull);
      expect(fixtures.requests.last.uri.queryParameters, {
        'search_query': 'a b&c',
        'o': 'mv',
        'page': '2',
      });
      expect(
        (await run("source.categoryComics.load('Category','doujin',['mr'],1)")
            as Map)['maxPage'],
        1,
      );
      expect(
        (await run("source.categoryComics.load('每週必看',null,['4','manga'],1)")
            as Map)['maxPage'],
        1,
      );
      expect(
        await run("source.categoryComics.optionLoader('每週必看',null)"),
        isA<List>(),
      );
      await run("source.categoryComics.ranking.load('mv_m',1)");
      expect(fixtures.requests.last.uri.queryParameters['o'], 'mv_m');
    },
  );

  test('favorites preserve folders, pagination and form encoding', () async {
    final page = await run('source.favorites.loadComics(1,null)') as Map;
    expect(page['maxPage'], 1);
    expect(fixtures.requests.last.uri.queryParameters['folder_id'], '0');
    final folders = await run('source.favorites.loadFolders(null)') as Map;
    expect((folders['folders'] as Map)['2'], 'Folder');
    await run("source.favorites.addFolder('A&B=+')");
    expect(
      Uri.splitQueryString(
        fixtures.requests.last.data as String,
      )['folder_name'],
      'A&B=+',
    );
    await run("source.favorites.deleteFolder('2')");
    await run("source.favorites.addOrDelFavorite('7','2',true,null)");
    expect(fixtures.requests.last.uri.path, '/favorite_folder');
    expect(Uri.splitQueryString(fixtures.requests.last.data as String), {
      'type': 'move',
      'folder_id': '2',
      'aid': '7',
    });
  });

  test('details and chapter images use plain standard data', () async {
    final details = await run("source.comic.loadInfo('jm7')") as Map;
    expect(details['id'], '7');
    expect(details['chapters'], {'11': 'First', '12': '第2話'});
    expect(((details['recommend'] as List).single as Map)['subTitle'], isNull);
    expect((details['tags'] as Map)['View'], ['123']);
    fixtures.responses['/album'] = {'name': 'Single chapter'};
    expect((await run("source.comic.loadInfo('7')") as Map)['chapters'], {
      '7': '第1話',
    });
    final chapter = await run("source.comic.loadEp('7','11')") as Map;
    expect(chapter['images'], hasLength(2));
    expect(
      (chapter['images'] as List).first,
      endsWith('/media/photos/11/001.jpg'),
    );
    await run("source.comic.likeComic('7',true)");
  });

  test('plugin owns HTTPS port correction for API and all media URLs', () async {
    expect(
      await run("jmNormalizeUrl('https://www.cdntwice.org:45176/a?q=1#frag')"),
      'https://www.cdntwice.org/a?q=1#frag',
    );
    expect(
      await run("jmNormalizeUrl('http://www.cdntwice.org:45176/a')"),
      'http://www.cdntwice.org:45176/a',
    );
    expect(
      await run("jmNormalizeUrl('https://example.test:45176/a')"),
      'https://example.test:45176/a',
    );
    expect(
      await run(
        "jmNormalizeUrl('https://user:pass@cdnsha.jmapiproxyxxx.vip:45176/a')",
      ),
      'https://user:pass@cdnsha.jmapiproxyxxx.vip/a',
    );
    engine.evaluate(
      "jmApiDomains=['www.cdntwice.org:45176'];jmImageHost='https://cdn-msp.jmapinodeudzn.net:45176';",
    );
    final info = await run("source.comic.loadInfo('7')") as Map;
    expect(fixtures.requests.last.uri.hasPort, false);
    expect(info['cover'], startsWith('https://cdn-msp.jmapinodeudzn.net/'));
    final chapter = await run("source.comic.loadEp('7','10')") as Map;
    expect(
      (chapter['images'] as List).first.toString(),
      startsWith('https://cdn-msp.jmapinodeudzn.net/'),
    );
    expect(
      await run("jmAvatarUrl('//cdnsha.jmapiproxyxxx.vip:45176/avatar.jpg')"),
      'https://cdnsha.jmapiproxyxxx.vip/avatar.jpg',
    );
    final image =
        await run(
              "source.comic.onImageLoad('https://cdnsha.jmapiproxyxxx.vip:45176/1.jpg','7','250000')",
            )
            as Map;
    expect(image['url'], 'https://cdnsha.jmapiproxyxxx.vip/1.jpg');
    expect(image['segments'], 10);
  });

  test('image rules preserve segments and request headers', () async {
    Map config(String id, String name) =>
        engine.evaluate(
              "source.comic.onImageLoad('https://img.example/$name','7','$id')",
            )
            as Map;
    expect(config('100000', '1.jpg')['segments'], 0);
    expect(config('250000', '1.jpg')['segments'], 10);
    expect(config('250000', '1.GIF?key=1')['segments'], 0);
    final hash = md5.convert(utf8.encode('5000001')).toString();
    expect(
      config('500000', '1.jpg')['segments'],
      hash.codeUnitAt(hash.length - 1) % 8 * 2 + 2,
    );
    expect(
      (config('250000', '1.jpg')['headers'] as Map)['Referer'],
      'https://localhost/',
    );
  });

  test(
    'comments include identity, full avatar URLs and correct page counts',
    () async {
      final result =
          await run("source.comic.loadComments('7',null,1,null)") as Map;
      expect(result['maxPage'], 1);
      expect((result['comments'] as List).single, containsPair('id', '9'));
      expect(
        ((result['comments'] as List).single as Map)['avatar'],
        'https://images.fixture.example/avatar.jpg',
      );
      expect(((result['comments'] as List).single as Map)['content'], 'Hello');
      await run("source.comic.sendComment('7',null,'A&B=+',null)");
      expect(
        Uri.splitQueryString(fixtures.requests.last.data as String)['comment'],
        'A&B=+',
      );
    },
  );

  test('check-in is awaited, persisted and shared by concurrent calls', () async {
    await run("source.account.login('user','password')");
    final results =
        await run(
              'Promise.all([source.account.checkIn(),source.account.checkIn()])',
            )
            as List;
    expect((results.first as Map)['status'], 'success');
    expect(
      fixtures.requests.where((r) => r.uri.path == '/daily_chk'),
      hasLength(1),
    );
    expect(await run('source.account.checkInStatus()'), isTrue);
    expect(
      (await run('source.account.checkIn()') as Map)['status'],
      'alreadyCheckedIn',
    );
    await run("Hazuki.settings.set('dailyCheckInTask',true)");
    await run("source.search.load('keyword',['mr'],1)");
    expect(
      fixtures.requests.where((r) => r.uri.path == '/daily_chk'),
      hasLength(1),
    );
  });

  test(
    'automatic check-in runs before mutations without recursive requests',
    () async {
      await run("source.account.login('user','password')");
      await run("Hazuki.settings.set('dailyCheckInTask',true)");
      await run("source.comic.likeComic('7',true)");
      expect(fixtures.requests.map((r) => r.uri.path), [
        '/login',
        '/daily',
        '/daily_chk',
        '/like',
      ]);
      await run("source.search.load('keyword',['mr'],1)");
      expect(
        fixtures.requests.where((r) => r.uri.path == '/daily_chk'),
        hasLength(1),
      );
    },
  );

  test('failed automatic check-in leaves comic requests usable', () async {
    await run("source.account.login('user','password')");
    fixtures.responses['/daily_chk'] = {'status': 'fail', 'msg': 'Try later'};
    await run("Hazuki.settings.set('dailyCheckInTask',true)");
    final result = await run("source.search.load('keyword',['mr'],1)") as Map;
    expect(result['comics'], hasLength(1));
    expect(await run('source.account.checkInStatus()'), isFalse);
  });

  test(
    'SDK cookie mutations are awaitable and logout clears plugin session data',
    () async {
      final set = engine.evaluate(
        "Hazuki.cookies.set('https://www.cdntwice.org/',[{name:'test',value:'cookie',path:'/'}])",
      );
      expect(set, isA<Future>());
      await handle.facade.js.resolve(set);
      expect(
        handle.cookieStore.buildHeader('https://www.cdntwice.org/'),
        contains('test=cookie'),
      );
      final delete = engine.evaluate(
        "Hazuki.cookies.delete('https://www.cdntwice.org/')",
      );
      expect(delete, isA<Future>());
      await handle.facade.js.resolve(delete);
      expect(
        handle.cookieStore.buildHeader('https://www.cdntwice.org/'),
        isNull,
      );
      await run("source.account.login('user','password')");
      expect(
        handle.cookieStore.buildHeader('https://www.cdntwice.org/'),
        contains('sid=fixture'),
      );
      await run('source.account.logout()');
      expect(
        handle.cookieStore.buildHeader('https://www.cdntwice.org/'),
        isNull,
      );
      expect(handle.facade.loadSourceData('jm', 'uid'), isNull);
      expect(handle.facade.loadSourceData('jm', 'profile'), isNull);
    },
  );
}
