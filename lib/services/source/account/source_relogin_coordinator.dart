import '../runtime/source_cookie_store.dart';
import '../runtime/source_runtime_facade.dart';

abstract interface class SourceReloginContext {
  Future<void> ensureInitialized();
  bool get isLogged;
  bool shouldSkipRelogin(Duration duration);
  List<String>? loadAccountDataSync();
  DateTime? get lastReloginAt;
  set lastReloginAt(DateTime? value);
  List<SourceCookie> loadCookieStore();
  Future<void> saveCookieStore(List<SourceCookie> cookies);
}

class SourceFacadeReloginContext implements SourceReloginContext {
  SourceFacadeReloginContext(this.facade);

  final HazukiSourceFacade facade;

  @override
  Future<void> ensureInitialized() => facade.ensureInitialized();

  @override
  bool get isLogged => facade.isLogged;

  @override
  bool shouldSkipRelogin(Duration duration) =>
      facade.runtime.shouldSkipRelogin(duration);

  @override
  List<String>? loadAccountDataSync() => facade.loadAccountDataSync();

  @override
  DateTime? get lastReloginAt => facade.lastReloginAt;

  @override
  set lastReloginAt(DateTime? value) => facade.lastReloginAt = value;

  @override
  List<SourceCookie> loadCookieStore() => facade.loadCookieStore();

  @override
  Future<void> saveCookieStore(List<SourceCookie> cookies) =>
      facade.saveCookieStore(cookies);
}

typedef SourceStoredAccountLogin =
    Future<void> Function(
      SourceReloginContext context, {
      required String account,
      required String password,
    });

/// Coordinates source-session renewal independently from business capabilities.
class SourceReloginCoordinator {
  SourceReloginCoordinator({
    required SourceStoredAccountLogin loginWithStoredAccount,
  }) : _loginWithStoredAccount = loginWithStoredAccount;

  static const _reloginInterval = Duration(minutes: 8);

  final SourceStoredAccountLogin _loginWithStoredAccount;

  Future<T> runWithReloginRetry<T>(
    Future<T> Function() action, {
    required SourceReloginContext context,
  }) async {
    try {
      return await action();
    } catch (error) {
      if (!isLoginExpiredError(error)) rethrow;
      await clearCookiesForFavoriteDomains(context);
      if (!await tryReloginFromStoredAccount(context, force: true)) rethrow;
      return action();
    }
  }

  Future<bool> ensureFavoriteSessionReady(SourceReloginContext context) async {
    await context.ensureInitialized();
    if (!context.isLogged || context.shouldSkipRelogin(_reloginInterval)) {
      return true;
    }
    return tryReloginFromStoredAccount(context);
  }

  Future<bool> tryReloginFromStoredAccount(
    SourceReloginContext context, {
    bool force = false,
  }) async {
    final accountData = context.loadAccountDataSync();
    if (accountData == null || accountData.length < 2) return false;
    if (!force && context.shouldSkipRelogin(_reloginInterval)) return true;
    try {
      await _loginWithStoredAccount(
        context,
        account: accountData[0],
        password: accountData[1],
      );
      context.lastReloginAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearCookiesForFavoriteDomains(
    SourceReloginContext context,
  ) async {
    final cookies = context.loadCookieStore();
    cookies.removeWhere((cookie) {
      final domain = cookie.domain.toLowerCase();
      return domain.contains('jmcomic') ||
          domain.contains('18comic') ||
          domain.contains('jm365') ||
          domain.contains('cdn-msp') ||
          domain.contains('cdnhth') ||
          domain.contains('cdntwice') ||
          domain.contains('cdnsha') ||
          domain.contains('cdnaspa') ||
          domain.contains('cdnntr');
    });
    await context.saveCookieStore(cookies);
  }

  static bool isLoginExpiredError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('login expired') ||
        message.contains('unauthorized') ||
        message.contains('status 401') ||
        message.contains('http 401') ||
        message.contains('401');
  }
}
