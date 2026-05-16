part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceAccountSessionCapability on HazukiSourceService {
  String? get currentAccount {
    final accountData = facade.loadAccountDataSync();
    if (accountData == null || accountData.isEmpty) {
      return null;
    }
    return accountData.first;
  }

  bool get isLogged => facade.loadAccountDataSync() != null;

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

    final script = isHazukiCopyMangaSourceKey(sourceMeta.key)
        ? _copyMangaLoginScript(account: account, password: password)
        : 'this.__hazuki_source.account.login(${jsonEncode(account)}, ${jsonEncode(password)})';
    final startedAt = DateTime.now();
    dynamic resolvedResult;

    try {
      final result = engine.evaluate(
        script,
        name: isHazukiCopyMangaSourceKey(sourceMeta.key)
            ? 'copy_manga_login.js'
            : 'source_login.js',
      );
      resolvedResult = await facade.js.resolve(result);
      await _persistLoginSideData(
        facade,
        sourceKey: sourceMeta.key,
        result: resolvedResult,
      );
      facade.lastLoginDebugInfo = {
        'time': DateTime.now().toIso8601String(),
        'ok': true,
        'account': account,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'result': jsonSafe(resolvedResult),
      };
      facade.networkLogSink.append(
        method: 'LOGIN',
        url: 'source://account.login',
        statusCode: 200,
        error: null,
        startedAt: startedAt,
        source: 'source_login',
        requestHeaders: const {},
        requestData: {'account': account},
        responseHeaders: const {},
        responseBody: jsonSafe(resolvedResult),
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
        'result': jsonSafe(resolvedResult),
      };
      facade.networkLogSink.append(
        method: 'LOGIN',
        url: 'source://account.login',
        statusCode: null,
        error: e.toString(),
        startedAt: startedAt,
        source: 'source_login',
        requestHeaders: const {},
        requestData: {'account': account},
        responseHeaders: const {},
        responseBody: jsonSafe(resolvedResult),
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
    await facade.deleteSourceData(sourceMeta.key, 'avatar_url');
    facade.runtime.transientAvatarUrl = null;
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      await facade.deleteSourceData(sourceMeta.key, 'token');
    }
  }
}

String _copyMangaLoginScript({
  required String account,
  required String password,
}) {
  final accountJson = jsonEncode(account);
  final passwordJson = jsonEncode(password);
  return '''
(async () => {
  const source = this.__hazuki_source;
  const account = $accountJson;
  const password = $passwordJson;
  const salt = Math.floor(Math.random() * 9000) + 1000;
  const encodedPassword = Convert.encodeBase64(
    Convert.encodeUtf8(password + "-" + salt)
  );
  const response = await Network.post(
    source.apiUrl + "/api/v3/login",
    {
      ...source.headers,
      "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
    },
    "username=" +
      account +
      "&password=" +
      encodedPassword +
      "\\n&salt=" +
      salt +
      "&authorization=Token+"
  );
  if (response.status !== 200) {
    throw "Invalid Status Code " + response.status;
  }
  const data = JSON.parse(response.body);
  const token = data && data.results && data.results.token;
  if (token) {
    source.saveData("token", token);
  }
  return data;
})()
''';
}

Future<void> _persistLoginSideData(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required dynamic result,
}) async {
  final safeResult = jsonSafe(result);
  final results = safeResult is Map ? safeResult['results'] : null;
  if (results is! Map) {
    _logAvatarEvent(
      facade,
      level: 'warn',
      title: 'Login side data missing',
      content: {
        'sourceKey': sourceKey,
        'resultType': safeResult.runtimeType.toString(),
      },
    );
    return;
  }

  final token = results['token'];
  if (isHazukiCopyMangaSourceKey(sourceKey) &&
      token is String &&
      token.trim().isNotEmpty) {
    await facade.saveSourceData(sourceKey, 'token', token.trim());
  }

  final avatarUrl = normalizeSourceAvatarUrl(
    sourceKey: sourceKey,
    avatar: results['avatar'],
  );
  if (avatarUrl != null) {
    facade.runtime.transientAvatarUrl = avatarUrl;
    _logAvatarEvent(
      facade,
      title: 'Login avatar parsed',
      content: {
        'sourceKey': sourceKey,
        'avatar': results['avatar'],
        'avatarUrl': avatarUrl,
        'hasToken': token is String && token.trim().isNotEmpty,
      },
    );
  } else {
    _logAvatarEvent(
      facade,
      level: 'warn',
      title: 'Login avatar missing',
      content: {
        'sourceKey': sourceKey,
        'resultKeys': results.keys.map((key) => key.toString()).toList(),
        'avatar': results['avatar'],
        'hasToken': token is String && token.trim().isNotEmpty,
      },
    );
  }
}
