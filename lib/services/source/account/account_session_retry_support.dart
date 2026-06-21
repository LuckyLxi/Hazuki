part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceAccountSessionRetrySupport on HazukiSourceService {
  Future<T> _runWithReloginRetry<T>(
    Future<T> Function() action, {
    HazukiSourceFacade? targetFacade,
  }) async {
    final facade = targetFacade ?? this.facade;
    try {
      return await action();
    } catch (e) {
      if (!_isLoginExpiredError(e)) {
        rethrow;
      }

      await _clearCookiesForFavoriteDomains(targetFacade: facade);
      final reloginOk = await _tryReloginFromStoredAccount(
        force: true,
        targetFacade: facade,
      );
      if (!reloginOk) {
        rethrow;
      }

      return await action();
    }
  }

  Future<bool> _ensureFavoriteSessionReady({
    HazukiSourceFacade? targetFacade,
  }) async {
    final facade = targetFacade ?? this.facade;
    await facade.ensureInitialized();

    if (!facade.isLogged) {
      return true;
    }

    if (facade.runtime.shouldSkipRelogin(const Duration(minutes: 8))) {
      return true;
    }

    return _tryReloginFromStoredAccount(targetFacade: facade);
  }

  bool _isLoginExpiredError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('login expired') ||
        msg.contains('unauthorized') ||
        msg.contains('status 401') ||
        msg.contains('http 401') ||
        msg.contains('401');
  }

  Future<bool> _tryReloginFromStoredAccount({
    bool force = false,
    HazukiSourceFacade? targetFacade,
  }) async {
    final facade = targetFacade ?? this.facade;
    final accountData = facade.loadAccountDataSync();
    if (accountData == null || accountData.length < 2) {
      return false;
    }

    if (!force) {
      if (facade.runtime.shouldSkipRelogin(const Duration(minutes: 8))) {
        return true;
      }
    }

    try {
      await _loginWithFacade(
        facade,
        account: accountData[0],
        password: accountData[1],
      );
      facade.lastReloginAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearCookiesForFavoriteDomains({
    HazukiSourceFacade? targetFacade,
  }) async {
    final facade = targetFacade ?? this.facade;
    final all = facade._loadCookieStore();
    all.removeWhere((cookie) {
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
    await facade._saveCookieStore(all);
  }
}
