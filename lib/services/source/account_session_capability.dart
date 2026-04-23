part of '../hazuki_source_service.dart';

extension HazukiSourceServiceAccountSessionCapability on HazukiSourceService {
  String? get currentAccount {
    final accountData = facade.loadAccountDataSync();
    if (accountData == null || accountData.isEmpty) {
      return null;
    }
    return accountData.first;
  }

  bool get isLogged => _loadAccountDataSync() != null;

  Future<void> login({
    required String account,
    required String password,
  }) async {
    final facade = this.facade;
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    final sourceMeta = facade.sourceMeta;
    if (engine == null || sourceMeta == null) {
      throw Exception('source_not_initialized');
    }

    final supportsAccount = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.account?.login'),
    );
    if (!supportsAccount) {
      throw Exception('account_login_not_supported');
    }

    final script =
        'this.__hazuki_source.account.login(${jsonEncode(account)}, ${jsonEncode(password)})';
    final startedAt = DateTime.now();
    dynamic resolvedResult;

    try {
      final result = engine.evaluate(script, name: 'source_login.js');
      resolvedResult = await facade.js.resolve(result);
      facade.lastLoginDebugInfo = {
        'time': DateTime.now().toIso8601String(),
        'ok': true,
        'account': account,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'result': _jsonSafe(resolvedResult),
      };
      _appendNetworkLog(
        method: 'LOGIN',
        url: 'source://account.login',
        statusCode: 200,
        error: null,
        startedAt: startedAt,
        source: 'source_login',
        requestHeaders: const {},
        requestData: {'account': account},
        responseHeaders: const {},
        responseBody: _jsonSafe(resolvedResult),
      );
      await facade.saveSourceData(sourceMeta.key, 'account', [
        account,
        password,
      ]);
    } catch (e) {
      facade.lastLoginDebugInfo = {
        'time': DateTime.now().toIso8601String(),
        'ok': false,
        'account': account,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'error': e.toString(),
        'result': _jsonSafe(resolvedResult),
      };
      _appendNetworkLog(
        method: 'LOGIN',
        url: 'source://account.login',
        statusCode: null,
        error: e.toString(),
        startedAt: startedAt,
        source: 'source_login',
        requestHeaders: const {},
        requestData: {'account': account},
        responseHeaders: const {},
        responseBody: _jsonSafe(resolvedResult),
      );
      throw Exception('login_failed:$e');
    }
  }

  Future<void> logout() async {
    final facade = this.facade;
    final engine = facade.js.engine;
    final sourceMeta = facade.sourceMeta;
    if (engine == null || sourceMeta == null) {
      return;
    }

    final hasLogout = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.account?.logout'),
    );

    if (hasLogout) {
      try {
        final result = engine.evaluate(
          'this.__hazuki_source.account.logout()',
          name: 'source_logout.js',
        );
        await facade.js.resolve(result);
      } catch (_) {}
    }

    await facade.deleteSourceData(sourceMeta.key, 'account');
  }
}
