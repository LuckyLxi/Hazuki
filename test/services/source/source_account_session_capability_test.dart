import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/account_session_capability.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;
  late SourceAccountSessionCapability accountSession;

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
    accountSession = SourceAccountSessionCapability(runtimeHost: host);
    addTearDown(host.dispose);
  });

  test(
    'prefers the persisted display name over the login identifier',
    () async {
      final facade = host.activeHandle.facade;
      await facade.saveSourceData('jm', 'account', ['login-id', 'password']);

      expect(accountSession.currentAccount, 'login-id');
      expect(accountSession.isLogged, isTrue);

      await facade.saveSourceData('jm', 'display_name', 'Display Name');

      expect(accountSession.currentAccount, 'Display Name');
      expect(accountSession.currentAccountForSource('jm'), 'Display Name');
      expect(accountSession.isLoggedForSource('jm'), isTrue);
    },
  );

  test('logout clears all persisted session side data', () async {
    final facade = host.activeHandle.facade;
    await facade.saveSourceData('jm', 'account', ['login-id', 'password']);
    await facade.saveSourceData('jm', 'avatar_url', 'https://example/avatar');
    await facade.saveSourceData('jm', 'display_name', 'Display Name');
    await facade.saveSourceData('jm', 'token', 'secret-token');
    await facade.saveSourceData('jm', 'login_session', 'session-id');
    await facade.saveCookieStore(const [
      SourceCookie(
        name: 'session',
        value: 'secret',
        domain: 'example.com',
        path: '/',
      ),
    ]);
    facade.runtime.transientAvatarUrl = 'https://example/transient';

    await accountSession.logout();

    expect(facade.loadSourceData('jm', 'account'), isNull);
    expect(facade.loadSourceData('jm', 'avatar_url'), isNull);
    expect(facade.loadSourceData('jm', 'display_name'), isNull);
    expect(facade.loadSourceData('jm', 'token'), isNull);
    expect(facade.loadSourceData('jm', 'login_session'), isNull);
    expect(facade.loadCookieStore(), isEmpty);
    expect(facade.runtime.transientAvatarUrl, isNull);
    expect(accountSession.isLogged, isFalse);
  });

  test('recognizes passwordless sessions without legacy credentials', () async {
    final facade = host.activeHandle.facade;
    await facade.saveSourceData('jm', 'login_session', 'session-id');
    await facade.saveSourceData('jm', 'display_name', 'Browser user');
    expect(facade.loadAccountDataSync(), isNull);
    expect(facade.isLogged, isTrue);
    expect(accountSession.isLogged, isTrue);
    expect(accountSession.isLoggedForSource('jm'), isTrue);
    expect(accountSession.currentAccount, 'Browser user');
    await accountSession.logout();
    expect(facade.isLogged, isFalse);
  });

  test('logout publishes the cleared session to runtime listeners', () async {
    await host.activeHandle.session.saveSourceData(
      'jm',
      'login_session',
      'session-id',
    );
    final identities = <String?>[];
    host.addListener(() {
      identities.add(host.activeHandle.session.loginIdentity);
    });

    await accountSession.logout();

    expect(identities, [null]);
  });

  test('malformed marker safely falls back to a legacy login', () async {
    final session = host.activeHandle.session;
    await session.saveSourceData('jm', 'login_session', true);
    expect(session.hasLogin, isFalse);
    expect(session.loginIdentity, isNull);
    await session.saveSourceData('jm', 'account', ['user', 'password']);
    expect(session.hasLogin, isTrue);
    expect(session.loginIdentity, isA<String>());
  });

  test('plugin isLogged follows passwordless and legacy sessions', () async {
    final handle = host.activeHandle;
    final engine = SourceScriptEngine();
    handle.runtime.engine = engine;
    final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
    engine.setMessageHandler(
      (message) => bridge.handleJsMessageForHandle(handle, message),
    );
    engine.evaluate(File('assets/init.js').readAsStringSync());
    engine.evaluate(File('assets/hazuki_plugin_sdk.js').readAsStringSync());
    engine.evaluate("const source = new HazukiSource(); source.key = 'jm';");

    expect(engine.evaluate('source.isLogged'), isFalse);
    await handle.facade.saveSourceData('jm', 'login_session', 'session-id');
    expect(handle.facade.loadAccountDataSync(), isNull);
    expect(engine.evaluate('source.isLogged'), isTrue);

    await accountSession.logout();
    expect(engine.evaluate('source.isLogged'), isFalse);

    await handle.facade.saveSourceData('jm', 'login_session', true);
    expect(engine.evaluate('source.isLogged'), isFalse);
    await handle.facade.saveSourceData('jm', 'account', ['user', 'password']);
    expect(engine.evaluate('source.isLogged'), isTrue);
  });
}
