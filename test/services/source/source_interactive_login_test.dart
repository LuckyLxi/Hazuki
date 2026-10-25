import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/services/source/account/source_interactive_login_operations.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late MemorySourceSecureSessionStorage storage;
  late SourceInteractiveLoginOperations login;
  var script = '';
  var input = 'account';
  var http = _Http();

  setUp(() async {
    input = 'account';
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    http = _Http();
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'sample',
          name: 'Sample',
          fileName: 'sample.js',
        ),
        SourceCatalogEntry(key: 'other', name: 'Other', fileName: 'other.js'),
      ],
      defaultSourceKey: 'sample',
      secureSessionStorage: storage,
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    await host.activeHandle.session.ensurePrefs();
    login = SourceInteractiveLoginOperations(
      host: host,
      loadRuntime: (handle) async {
        await handle.session.ensurePrefs();
        final engine = SourceScriptEngine();
        handle.runtime.engine = engine;
        final bridge = SourceJsBridgeCookieCapability(
          activeHandle: () => handle,
        );
        handle.dio.httpClientAdapter = http;
        bridge.configureDioCookieBridge(handle);
        engine.setContextMessageHandler(
          (message, execution) => bridge.handleJsMessageForHandle(
            handle,
            message,
            execution: execution,
            runtimeId: engine.runtimeId,
          ),
        );
        await engine.evaluate(File('assets/init.js').readAsStringSync());
        await engine.evaluate(
          File('assets/hazuki_plugin_sdk.js').readAsStringSync(),
        );
        await engine.evaluate(
          '''Hazuki.registerSource({id:'sample', search:{load:async()=>({comics:[]})},
        comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})},
        account:{loginMethods:[{id:'sms',title:'SMS',input:'$input'}],
        login:async(account,password,context)=>{ $script }}});''',
        );
      },
    );
  });

  Future<void> run(
    SourceLoginCancellation token,
    SourceLoginPresenter present,
  ) => login.loginInteractive(
    account: 'phone',
    password: '',
    method: 'sms',
    present: present,
    cancellation: token,
  );

  for (final cancelled in [false, true]) {
    test(
      'browser login survives autofill activity suspension: cancelled=$cancelled',
      () async {
        final ui = SourceUiService.instance;
        addTearDown(() => ui.setForeground(true));
        input = 'none';
        script = '''
        const result=await context.requestBrowserAuthorization({url:'https://site.example/login',
          completion:'manual',cookieScopes:[{url:'https://site.example/',names:['sid']}]});
        if(result.status!=='completed') throw Error('not_completed');
        await Hazuki.http.get('https://site.example/verify');
        return {displayName:'Verified after autofill'};
      ''';
        final entered = Completer<void>();
        final browser = Completer<Map<String, Object>>();
        final cancellation = SourceLoginCancellation();
        var completed = false;
        final attempt = run(cancellation, (_, _) {
          ui.setForeground(false);
          entered.complete();
          return browser.future;
        }).then((_) => completed = true);
        final rejected = cancelled
            ? expectLater(attempt, throwsA(isA<SourceLoginCancelled>()))
            : null;
        await entered.future;
        expect(cancellation.isCancelled, false);
        ui.setForeground(false);
        if (cancelled) cancellation.cancel();
        browser.complete({
          'status': 'completed',
          'url': 'https://site.example/login',
          '_userAgent': 'Browser UA',
          '_cookies': [
            {
              'scopeUrl': 'https://site.example/',
              'name': 'sid',
              'value': 'synthetic',
              'domain': 'site.example',
              'path': '/',
              'secure': true,
              'httpOnly': true,
            },
          ],
        });
        await Future<void>.delayed(Duration.zero);
        expect(http.requests, isEmpty);
        expect(completed, false);
        expect(storage.values, isEmpty);
        ui.setForeground(true);
        if (cancelled) {
          await rejected;
          expect(host.activeHandle.facade.isLogged, false);
          expect(storage.values, isEmpty);
        } else {
          await attempt;
          expect(host.activeHandle.facade.isLogged, true);
          expect(http.requests.single.headers['User-Agent'], 'Browser UA');
          expect(
            http.requests.single.headers['cookie'],
            contains('sid=synthetic'),
          );
        }
      },
    );
  }

  test('browser callback commits a verified passwordless session', () async {
    input = 'none';
    script = '''
      const auth = await context.requestBrowserAuthorization({url:'https://provider.example/auth',
        callbacks:[{origin:'https://site.example',path:'/done',requiredQueryKeys:['token']}]});
      if(auth.status!=='completed') throw Error('not completed');
      await Hazuki.secrets.set('auth', auth.url);
      Hazuki.log(auth.url);
      return {displayName:'Browser user'};
    ''';
    await run(SourceLoginCancellation(), (request, _) async {
      expect(request['type'], 'browserAuthorization');
      return {
        'status': 'completed',
        'url': 'https://site.example/done?token=mock-only',
      };
    });
    final handle = host.activeHandle;
    expect(handle.facade.loadAccountDataSync(), isNull);
    expect(handle.facade.isLogged, isTrue);
    expect(
      handle.session.loadSourceData('sample', 'login_session'),
      isA<String>(),
    );
    expect(
      handle.session.loadSourceData('sample', 'display_name'),
      'Browser user',
    );
  });
  test(
    'external authorization keeps createUrl inside JS and closes its native session',
    () async {
      const channel = MethodChannel('hazuki/external_authorization');
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'prepare'
            ? 'hazuki-auth://authorize/${call.arguments['id']}'
            : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      input = 'none';
      script = '''
      const auth=await context.requestExternalAuthorization({allowedSchemes:['mock-provider'],
        createUrl:async callback=>{
          if(!callback.startsWith('hazuki-auth://authorize/')) throw Error('bad_callback');
          await Hazuki.storage.set('url_constructed',true);
          return 'mock-provider://login';
        }});
      if(auth.status!=='completed') throw Error('not_completed');
      return {displayName:'External user'};
    ''';
      await run(SourceLoginCancellation(), (request, _) async {
        expect(request['type'], 'externalAuthorization');
        expect(request['url'], 'mock-provider://login');
        expect(request.containsKey('createUrl'), isFalse);
        return {
          'status': 'completed',
          'url': 'hazuki-auth://authorize/${request['id']}?code=synthetic',
        };
      });
      expect(
        host.activeHandle.session.loadSourceData('sample', 'url_constructed'),
        isTrue,
      );
      expect(calls, ['prepare', 'close']);
    },
  );

  for (final fail in [false, true]) {
    test(
      'manual cookie import is staged until account verification succeeds: fail=$fail',
      () async {
        input = 'none';
        script =
            '''
        await context.requestBrowserAuthorization({url:'https://site.example/login',completion:'manual',
          cookieScopes:[{url:'https://site.example/account',names:['sid']}]});
        const cookies = await Hazuki.cookies.get('https://site.example/account');
        if(cookies.length!==1 || !cookies[0].httpOnly) throw Error('cookie_missing');
        await Hazuki.http.get('https://site.example/account', {'User-Agent':'Old plugin UA'});
        ${fail ? "throw Error('verification_failed');" : "return {displayName:'Cookie user'};"}
      ''';
        final result = run(
          SourceLoginCancellation(),
          (_, _) async => {
            'status': 'completed',
            'url': 'https://site.example/login',
            '_userAgent': 'Synthetic browser UA',
            '_cookies': [
              {
                'scopeUrl': 'https://site.example/account',
                'name': 'sid',
                'value': 'mock-only',
                'domain': 'site.example',
                'path': '/',
                'secure': true,
                'httpOnly': true,
                'hostOnly': true,
              },
            ],
          },
        );
        if (fail) {
          await expectLater(result, throwsA(anything));
        } else {
          await result;
        }
        expect(
          host.activeHandle.cookieStore
              .get('https://site.example/account')
              .where((cookie) => cookie.name == 'sid')
              .length,
          fail ? 0 : 1,
        );
        expect(host.activeHandle.facade.isLogged, !fail);
        expect(
          http.requests.single.headers['User-Agent'],
          'Synthetic browser UA',
        );
        expect(
          http.requests.single.headers['cookie'],
          contains('sid=mock-only'),
        );
        expect(
          host.activeHandle.session.browserUserAgentFor(
            'https://site.example/',
          ),
          fail ? isNull : 'Synthetic browser UA',
        );
      },
    );
  }

  test(
    'browser account verification failure discards pending writes',
    () async {
      input = 'none';
      script = '''
      const auth = await context.requestBrowserAuthorization({url:'https://provider.example/auth',
        callbacks:[{origin:'https://site.example',path:'/done'}]});
      await Hazuki.secrets.set('auth', auth.url);
      await Hazuki.storage.set('unverified',true);
      throw Error('account_verification_failed');
    ''';
      await expectLater(
        run(
          SourceLoginCancellation(),
          (_, _) async => {
            'status': 'completed',
            'url': 'https://site.example/done?token=mock-only',
          },
        ),
        throwsA(anything),
      );
      expect(storage.values, isEmpty);
      expect(host.activeHandle.facade.isLogged, isFalse);
      expect(
        host.activeHandle.session.loadSourceData('sample', 'unverified'),
        isNull,
      );
    },
  );
  for (final failure in ['verify', 'cancel', 'commit']) {
    test(
      'cookie and UA transaction preserves previous session on $failure',
      () async {
        final previous = host.activeHandle;
        await previous.cookieStore.set('https://site.example/', [
          SourceCookie(
            name: 'sid',
            value: 'previous',
            domain: 'site.example',
            path: '/',
            secure: true,
          ),
        ]);
        await previous.session.saveBrowserUserAgents({
          'https://site.example': 'Previous UA',
        });
        final before = Map<String, String>.from(storage.values);
        if (failure == 'commit') (storage as _Storage).failNextUaWrite = true;
        input = 'none';
        script =
            '''
        const auth=await context.requestBrowserAuthorization({url:'https://site.example/',completion:'manual',
          cookieScopes:[{url:'https://site.example/',names:['sid']}]});
        if('_cookies' in auth || '_userAgent' in auth) throw Error('internal_result_leaked');
        await Hazuki.http.get('https://site.example/verify',{'User-Agent':'Old plugin UA'});
        ${failure == 'verify'
                ? "throw Error('verification_failed');"
                : failure == 'cancel'
                ? "await context.requestText({title:'Pending'});"
                : "return {displayName:'Verified'};"}
      ''';
        final token = SourceLoginCancellation();
        final reached = Completer<void>();
        final answer = Completer<String>();
        final attempt = run(token, (request, _) async {
          if (request['type'] == 'text') {
            reached.complete();
            return answer.future;
          }
          return {
            'status': 'completed',
            'url': 'https://site.example/',
            '_userAgent': 'New UA',
            '_cookies': [
              {
                'scopeUrl': 'https://site.example/',
                'name': 'sid',
                'value': 'new',
                'domain': 'site.example',
                'path': '/',
                'secure': true,
                'httpOnly': true,
              },
            ],
          };
        });
        final rejected = expectLater(attempt, throwsA(anything));
        if (failure == 'cancel') {
          await reached.future;
          token.cancel();
          answer.complete('late');
        }
        await rejected;
        expect(http.requests.single.headers['User-Agent'], 'New UA');
        expect(http.requests.single.headers['cookie'], contains('sid=new'));
        expect(storage.values, before);
        expect(
          previous.session.browserUserAgentFor('https://site.example/'),
          'Previous UA',
        );
        expect(
          previous.cookieStore.get('https://site.example/').single.value,
          'previous',
        );
      },
    );
  }
  test(
    'verified cookie login rolls back when secure storage commit fails',
    () async {
      input = 'none';
      script = '''
      await context.requestBrowserAuthorization({url:'https://site.example/login',completion:'manual',
        cookieScopes:[{url:'https://site.example/account',names:['sid']}]});
      return {displayName:'Verified cookie account'};
    ''';
      storage.failWrites = true;
      await expectLater(
        run(
          SourceLoginCancellation(),
          (_, _) async => {
            'status': 'completed',
            'url': 'https://site.example/login',
            '_userAgent': 'Synthetic browser UA',
            '_cookies': [
              {
                'scopeUrl': 'https://site.example/account',
                'name': 'sid',
                'value': 'synthetic',
                'domain': 'site.example',
                'path': '/',
                'secure': true,
                'httpOnly': true,
                'hostOnly': true,
              },
            ],
          },
        ),
        throwsA(anything),
      );
      storage.failWrites = false;
      expect(storage.values, isEmpty);
      expect(
        host.activeHandle.cookieStore.get('https://site.example/account'),
        isEmpty,
      );
      expect(host.activeHandle.facade.isLogged, isFalse);
    },
  );

  test(
    'commits isolated storage, secrets, cookies and profile after multistep success',
    () async {
      script = '''
      await Hazuki.storage.set('pending', 'yes');
      await Hazuki.settings.set('quality', 'high');
      await Hazuki.secrets.set('session', 'secret');
      await Hazuki.cookies.set('https://example.com', [{name:'session',value:'cookie',domain:'example.com',path:'/'}]);
      const text = await context.requestText({title:'SMS'});
      const click = await context.requestClickCaptcha({image: [1]});
      if (text !== '1234' || click.points[1].x !== 2 || context.method !== 'sms') throw Error('bad result');
      return {token:'token',displayName:'User'};
    ''';
      var calls = 0;
      await run(SourceLoginCancellation(), (request, _) async {
        expect(
          host.activeHandle.session.loadSourceData('sample', 'pending'),
          isNull,
        );
        expect(storage.values, isEmpty);
        calls++;
        return request['type'] == 'text'
            ? '1234'
            : {
                'status': 'submitted',
                'points': [
                  {'x': 9, 'y': 8},
                  {'x': 2, 'y': 1},
                ],
              };
      });
      expect(calls, 2);
      final session = host.activeHandle.session;
      expect(session.loadAccountDataSync(null), ['phone', '']);
      expect(session.loadSourceData('sample', 'pending'), 'yes');
      expect(session.loadSourceData('sample', 'display_name'), 'User');
      expect(session.loadSourceData('sample', 'token'), 'token');
      expect(session.loadCookieStore().single.value, 'cookie');
      expect(
        storage.values['hazuki_plugin_secret_v1:sample:session'],
        'secret',
      );
    },
  );

  test(
    'cancel discards writes and rejects late results without changing previous session',
    () async {
      await host.activeHandle.facade.saveSourceData(
        'sample',
        'token',
        'previous',
      );
      final before = Map.of(storage.values);
      script = '''await Hazuki.storage.set('pending',1);
      await Hazuki.secrets.set('session','pending');
      await Hazuki.cookies.set('https://example.com',[{name:'session',value:'pending',domain:'example.com',path:'/'}]);
      await context.requestText({title:'SMS'}); return {token:'late'};''';
      final presented = Completer<void>();
      final answer = Completer<Object?>();
      final token = SourceLoginCancellation();
      final result = run(token, (_, _) {
        presented.complete();
        return answer.future;
      });
      final assertion = expectLater(
        result,
        throwsA(isA<SourceLoginCancelled>()),
      );
      await presented.future;
      token.cancel();
      await assertion;
      answer.complete('late');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(storage.values, before);
      expect(
        host.activeHandle.session.loadSourceData('sample', 'pending'),
        isNull,
      );
    },
  );

  test(
    'source switch cancels and prevents same-plugin concurrent attempts',
    () async {
      script =
          "await context.requestText({title:'Wait'}); return {token:'late'};";
      final presented = Completer<void>();
      final answer = Completer<Object?>();
      final token = SourceLoginCancellation();
      final pending = run(token, (_, _) {
        presented.complete();
        return answer.future;
      });
      final assertion = expectLater(
        pending,
        throwsA(isA<SourceLoginCancelled>()),
      );
      await presented.future;
      await expectLater(
        run(SourceLoginCancellation(), (_, _) async => ''),
        throwsStateError,
      );
      await host.activateSource('other');
      await assertion;
      answer.complete('late');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(storage.values, isEmpty);
    },
  );

  test(
    'secure commit failure does not publish profile or private storage',
    () async {
      script =
          "await Hazuki.storage.set('pending',1); return {token:'pending',displayName:'Pending'};";
      storage.failWrites = true;
      await expectLater(
        run(SourceLoginCancellation(), (_, _) async => null),
        throwsA(anything),
      );
      storage.failWrites = false;
      expect(storage.values, isEmpty);
      expect(
        host.activeHandle.session.loadSourceData('sample', 'pending'),
        isNull,
      );
      expect(
        host.activeHandle.session.loadSourceData('sample', 'display_name'),
        isNull,
      );
    },
  );

  test(
    'HTTP cookies are staged and cancellation aborts the private client',
    () async {
      script =
          "await Hazuki.http.get('https://example.com/login'); await context.requestText({title:'Confirm'}); return {token:'new'};";
      final presented = Completer<void>();
      final answer = Completer<Object?>();
      final cancellation = SourceLoginCancellation();
      final pending = run(cancellation, (_, _) {
        presented.complete();
        return answer.future;
      });
      final assertion = expectLater(
        pending,
        throwsA(isA<SourceLoginCancelled>()),
      );
      await presented.future;
      expect(host.activeHandle.session.loadCookieStore(), isEmpty);
      expect(storage.values, isEmpty);
      cancellation.cancel();
      await assertion;
      expect(http.closed, isTrue);
      answer.complete('late');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(storage.values, isEmpty);
    },
  );

  test('refresh and validation retries stay in one login attempt', () async {
    script =
        '''let answer; do {answer = await context.requestClickCaptcha({image:[1]});}
      while(answer.status === 'refresh');
      if (account !== 'phone' || answer.points[0].x !== 8) throw Error('bad retry');
      return {displayName:'Retried'};''';
    var count = 0;
    await run(
      SourceLoginCancellation(),
      (_, _) async => count++ == 0
          ? {'status': 'refresh'}
          : {
              'status': 'submitted',
              'points': [
                {'x': 8, 'y': 3},
              ],
            },
    );
    expect(count, 2);
    expect(
      host.activeHandle.session.loadSourceData('sample', 'display_name'),
      'Retried',
    );
  });
}

class _Storage extends MemorySourceSecureSessionStorage {
  bool failNextUaWrite = false;
  @override
  Future<void> write(String key, String value) async {
    if (failNextUaWrite &&
        key == SourceSecureSessionStorageKeys.browserUserAgents('sample')) {
      failNextUaWrite = false;
      throw StateError('synthetic_user_agent_commit_failure');
    }
    await super.write(key, value);
  }
}

class _Http implements HttpClientAdapter {
  bool closed = false;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        'set-cookie': ['session=http-cookie; Path=/; Secure'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}
