import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/account_session_capability.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
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
    expect(facade.loadCookieStore(), isEmpty);
    expect(facade.runtime.transientAvatarUrl, isNull);
    expect(accountSession.isLogged, isFalse);
  });
}
