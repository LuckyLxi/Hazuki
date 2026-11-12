import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'runtime context retains its original handle across source switches',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ui = SourceUiService();
      final host = SourceRuntimeHost(
        sourceUiService: ui,
        catalog: const [
          SourceCatalogEntry(key: 'one', name: 'One', fileName: 'one.js'),
          SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
        ],
        defaultSourceKey: 'one',
        secureSessionStorage: MemorySourceSecureSessionStorage(),
        ensureSourceInitialized: (_) async {},
        currentAccountForSource: (_) => null,
        isLoggedForSource: (_) => true,
      );
      addTearDown(host.dispose);
      addTearDown(ui.detach);
      final original = host.activeHandle;
      await original.session.ensurePrefs();
      await original.session.saveSourceData('one', 'account', [
        'user',
        'password',
      ]);
      final context = SourceRuntimeReloginContext(original);
      expect(context.skipPeriodicRelogin, isFalse);
      await original.session.saveSourceData('one', 'interactive_login', true);
      expect(context.skipPeriodicRelogin, isTrue);
      await original.session.saveSourceData('one', 'interactive_login', false);
      original.runtime.sourceMeta = SourceMeta(
        name: 'One',
        key: 'one',
        version: '1',
        supportsAccount: true,
        settingsDefaults: {},
        presentation: {'skipPeriodicRelogin': true},
      );
      expect(context.skipPeriodicRelogin, isTrue);

      final entered = Completer<void>();
      final release = Completer<void>();
      final coordinator = SourceReloginCoordinator<SourceRuntimeReloginContext>(
        loginWithStoredAccount:
            (bound, {required account, required password}) async {
              expect(bound.handle, same(original));
              entered.complete();
              await release.future;
              expect(bound.handle, same(original));
              expect(bound.handle, isNot(same(host.activeHandle)));
            },
      );
      final running = original.runOperation(
        () => coordinator.tryReloginFromStoredAccount(context, force: true),
      );
      await entered.future;
      await host.activateSource('two');
      release.complete();
      expect(await running, isTrue);
      expect(host.activeHandle.runtime.lastReloginAt, isNull);
      await original.whenDisposed;
    },
  );

  test('periodic opt-out does not suppress forced recovery', () async {
    var loginCount = 0;
    final coordinator = SourceReloginCoordinator<_FakeReloginContext>(
      loginWithStoredAccount: (_, {required account, required password}) async {
        loginCount++;
      },
    );
    final context = _FakeReloginContext(
      skipPeriodicRelogin: true,
      accountData: const ['user', 'password'],
    );
    expect(await coordinator.ensureFavoriteSessionReady(context), isTrue);
    expect(loginCount, 0);
    expect(
      await coordinator.tryReloginFromStoredAccount(context, force: true),
      isTrue,
    );
    expect(loginCount, 1);
  });

  test(
    'retries an expired session once after clearing matching cookies',
    () async {
      var loginCount = 0;
      var attempts = 0;
      final context = _FakeReloginContext(
        accountData: const ['user', 'password'],
        cookies: [
          const SourceCookie(
            name: 'session',
            value: 'old',
            domain: 'jmcomic.example',
            path: '/',
          ),
          const SourceCookie(
            name: 'other',
            value: 'keep',
            domain: 'example.test',
            path: '/',
          ),
        ],
      );
      final coordinator = SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {
              loginCount++;
              expect(account, 'user');
              expect(password, 'password');
            },
      );

      final result = await coordinator.runWithReloginRetry(() async {
        attempts++;
        if (attempts == 1) throw StateError('http 401');
        return 'recovered';
      }, context: context);

      expect(result, 'recovered');
      expect(attempts, 2);
      expect(loginCount, 1);
      expect(context.cookies, isEmpty);
      expect(context.lastReloginAt, isNotNull);
    },
  );

  test(
    'does not retry non-authentication failures or expired sessions without credentials',
    () async {
      var loginCount = 0;
      final coordinator = SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {
              loginCount++;
            },
      );
      final context = _FakeReloginContext(
        accountData: const ['user', 'password'],
      );

      await expectLater(
        coordinator.runWithReloginRetry(
          () async => throw StateError('network unavailable'),
          context: context,
        ),
        throwsA(isA<StateError>()),
      );
      expect(loginCount, 0);

      await expectLater(
        coordinator.runWithReloginRetry(
          () async => throw StateError('status 401'),
          context: _FakeReloginContext(),
        ),
        throwsA(isA<StateError>()),
      );
      expect(loginCount, 0);
    },
  );

  test(
    'prepares favorite sessions for guest, throttled, and stored accounts',
    () async {
      var loginCount = 0;
      final coordinator = SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {
              loginCount++;
            },
      );

      expect(
        await coordinator.ensureFavoriteSessionReady(
          _FakeReloginContext(isLogged: false),
        ),
        isTrue,
      );
      expect(
        await coordinator.ensureFavoriteSessionReady(
          _FakeReloginContext(
            shouldSkip: true,
            accountData: const ['user', 'password'],
          ),
        ),
        isTrue,
      );
      final stored = _FakeReloginContext(
        accountData: const ['user', 'password'],
      );
      expect(await coordinator.ensureFavoriteSessionReady(stored), isTrue);
      expect(loginCount, 1);
      expect(stored.initialized, isTrue);
      expect(stored.lastReloginAt, isNotNull);
    },
  );

  test('renews stored sessions using generic policy', () async {
    var loginCount = 0;
    final coordinator = SourceReloginCoordinator(
      loginWithStoredAccount: (_, {required account, required password}) async {
        loginCount++;
      },
    );

    final ready = await coordinator.ensureFavoriteSessionReady(
      _FakeReloginContext(
        sourceKey: 'copy_manga',
        accountData: const ['user', 'password'],
      ),
    );

    expect(ready, isTrue);
    expect(loginCount, 1);
  });
}

class _FakeReloginContext implements SourceReloginContext {
  _FakeReloginContext({
    this.sourceKey = 'jm',
    this.isLogged = true,
    this.shouldSkip = false,
    this.skipPeriodicRelogin = false,
    this.accountData,
    List<SourceCookie>? cookies,
  }) : cookies = List.of(cookies ?? const []);

  @override
  final String sourceKey;
  @override
  final bool isLogged;
  @override
  final bool skipPeriodicRelogin;
  final bool shouldSkip;
  final List<String>? accountData;
  final List<SourceCookie> cookies;
  bool initialized = false;
  @override
  DateTime? lastReloginAt;

  @override
  Future<void> ensureInitialized() async {
    initialized = true;
  }

  @override
  List<String>? loadAccountDataSync() => accountData;

  @override
  List<SourceCookie> loadCookieStore() => cookies;

  @override
  Future<void> saveCookieStore(List<SourceCookie> next) async {
    final copy = List<SourceCookie>.of(next);
    cookies
      ..clear()
      ..addAll(copy);
  }

  @override
  bool shouldSkipRelogin(Duration duration) => shouldSkip;
}
