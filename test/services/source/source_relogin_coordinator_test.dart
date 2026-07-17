import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';

void main() {
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
      expect(context.cookies.single.name, 'other');
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
}

class _FakeReloginContext implements SourceReloginContext {
  _FakeReloginContext({
    this.isLogged = true,
    this.shouldSkip = false,
    this.accountData,
    List<SourceCookie>? cookies,
  }) : cookies = List.of(cookies ?? const []);

  @override
  final bool isLogged;
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
