part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceAccountSessionCapability on HazukiSourceService {
  String? get currentAccount {
    final sourceKey = facade.sourceMeta?.key ?? facade.sourceKey;
    final displayName = facade
        .loadSourceData(sourceKey, 'display_name')
        ?.toString()
        .trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
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
        : isHazukiPicacgSourceKey(sourceMeta.key)
        ? _picacgLoginWithResponseTraceScript(
            account: account,
            password: password,
          )
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
      _logPicacgLoginResponseTrace(
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
      _logPicacgLoginResponseTrace(
        facade,
        sourceKey: sourceMeta.key,
        result: resolvedResult,
        error: e.toString(),
      );
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
    final sourceKey = (sourceMeta?.key ?? facade.sourceKey).trim();

    if (engine != null && sourceMeta != null) {
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
    }

    if (sourceKey.isEmpty) {
      return;
    }

    await facade.deleteSourceData(sourceKey, 'account');
    await facade.deleteSourceData(sourceKey, 'avatar_url');
    await facade.deleteSourceData(sourceKey, 'display_name');
    await facade._saveCookieStore(const []);
    facade.runtime.transientAvatarUrl = null;
    await facade.deleteSourceData(sourceKey, 'token');
  }
}

String _picacgLoginWithResponseTraceScript({
  required String account,
  required String password,
}) {
  final accountJson = jsonEncode(account);
  final passwordJson = jsonEncode(password);
  return '''
(async () => {
  const source = this.__hazuki_source;
  const originalPost = Network.post;
  const authResponses = [];
  Network.post = async function(url, headers, data) {
    const response = await originalPost.call(Network, url, headers, data);
    const urlText = String(url || "");
    if (urlText.includes("/auth/sign-in") || urlText.includes("auth/sign-in")) {
      let parsedBody = null;
      try {
        parsedBody = JSON.parse(response && response.body);
      } catch (_) {}
      authResponses.push({
        url: urlText,
        status: response && response.status,
        headers: response && response.headers,
        body: response && response.body,
        parsedBody: parsedBody
      });
    }
    return response;
  };
  try {
    const loginResult = await source.account.login($accountJson, $passwordJson);
    return {
      loginResult: loginResult,
      authResponses: authResponses
    };
  } finally {
    Network.post = originalPost;
  }
})()
''';
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
  const previousToken = source.loadData("token");
  const salt = Math.floor(Math.random() * 9000) + 1000;
  const encodedPassword = Convert.encodeBase64(
    Convert.encodeUtf8(password + "-" + salt)
  );
  const headers = {
    ...source.headers,
    "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
  };
  const body =
    "username=" +
    account +
    "&password=" +
    encodedPassword +
    "\\n&salt=" +
    salt +
    "&authorization=Token+";
  const response = await Network.post(
    source.apiUrl + "/api/v3/login",
    headers,
    body
  );
  if (response.status !== 200) {
    if (previousToken) {
      source.saveData("token", previousToken);
    }
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
    if (isHazukiPicacgSourceKey(sourceKey)) {
      final persisted = await _persistPicacgLoginSideData(
        facade,
        sourceKey: sourceKey,
        result: safeResult,
      );
      if (persisted) {
        return;
      }
    }
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

Future<bool> _persistPicacgLoginSideData(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required dynamic result,
}) async {
  final token = _extractPicacgLoginToken(result)?.trim();
  if (token == null || token.isEmpty) {
    return false;
  }
  await facade.saveSourceData(sourceKey, 'token', token);

  final tokenPayload = _decodeJwtPayload(token);
  final tokenDisplayName = tokenPayload?['name']?.toString().trim();
  if (tokenDisplayName != null && tokenDisplayName.isNotEmpty) {
    await facade.saveSourceData(sourceKey, 'display_name', tokenDisplayName);
  }

  final profile = await _fetchPicacgProfileWithToken(
    facade,
    sourceKey: sourceKey,
    token: token,
  );
  final displayName = profile?.displayName?.trim() ?? tokenDisplayName;
  if (displayName != null && displayName.isNotEmpty) {
    await facade.saveSourceData(sourceKey, 'display_name', displayName);
  }

  final avatarUrl = profile?.avatarUrl?.trim();
  if (avatarUrl != null) {
    facade.runtime.transientAvatarUrl = avatarUrl;
    await facade.saveSourceData(sourceKey, 'avatar_url', avatarUrl);
  }

  _logAvatarEvent(
    facade,
    title: 'Picacg token profile parsed',
    content: {
      'sourceKey': sourceKey,
      'hasProfile': profile != null,
      'displayName': displayName,
      'hasAvatar': avatarUrl != null,
    },
  );
  return true;
}

Future<_PicacgProfileData?> _fetchPicacgProfileWithToken(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required String token,
}) async {
  final engine = facade.js.engine;
  if (engine == null) {
    _logAvatarEvent(
      facade,
      level: 'warn',
      title: 'Picacg avatar profile fetch skipped',
      content: {'sourceKey': sourceKey, 'reason': 'missing_engine'},
    );
    return null;
  }

  final tokenJson = jsonEncode(token);
  try {
    final result = engine.evaluate('''
(async () => {
  const source = this.__hazuki_source;
  const token = $tokenJson;
  const baseUrl = source.loadSetting("base_url") || "https://picaapi.picacomic.com";
  if (!baseUrl || !source.createSignature) {
    return { ok: false, reason: "missing_profile_request_support" };
  }
  const path = "/users/profile";
  const unsignedPath = "users/profile";
  const method = "GET";
  const requestBaseUrl = baseUrl.endsWith("/")
    ? baseUrl.slice(0, -1)
    : baseUrl;
  async function requestProfile(signaturePath) {
    const uuid = createUuid();
    const nonce = uuid.replace(/-/g, "");
    const time = (new Date().getTime() / 1000).toFixed(0);
    const signature = source.createSignature(signaturePath, nonce, time, method);
    const headers = {
      "time": time,
      "nonce": nonce,
      "signature": signature,
      "accept": "application/vnd.picacomic.com.v1+json",
      "api-key": "C69BAF41DA5ABD1FFEDC6D2FEA56B",
      "app-channel": "2",
      "app-version": "2.2.1.2.3.3",
      "app-uuid": uuid,
      "app-platform": "android",
      "app-build-version": "44",
      "image-quality": "original",
      "user-agent": "okhttp/3.8.1",
      "version": "v1.4.1",
      "Host": "picaapi.picacomic.com",
      "Content-Type": "application/json; charset=UTF-8",
      "authorization": token
    };
    const response = await Network.get(requestBaseUrl + path, headers);
    let parsedBody = null;
    try {
      parsedBody = JSON.parse(response && response.body);
    } catch (_) {}
    return {
      ok: response && response.status === 200,
      status: response && response.status,
      path,
      signaturePath,
      requestUrl: requestBaseUrl + path,
      body: response && response.body,
      parsedBody
    };
  }
  const attempts = [await requestProfile(path), await requestProfile(unsignedPath)];
  const withAvatar = attempts.find((item) => {
    const body = item && item.parsedBody;
    const data = body && body.data;
    const user = data && data.user;
    return (user && user.avatar) || (data && data.avatar) || (body && body.avatar);
  });
  const selected = withAvatar || attempts[0];
  return {
    ...selected,
    attempts
  };
})()
''', name: 'picacg_profile_avatar.js');
    final resolved = jsonSafe(await facade.js.resolve(result));
    final profile = _picacgProfileFromProfileResult(
      sourceKey: sourceKey,
      result: resolved,
    );
    if (profile == null) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Picacg avatar profile missing',
        content: {'sourceKey': sourceKey, 'result': resolved},
      );
      return null;
    }
    _logAvatarEvent(
      facade,
      title: 'Picacg avatar profile parsed',
      content: {
        'sourceKey': sourceKey,
        'displayName': profile.displayName,
        'avatarUrl': profile.avatarUrl,
      },
    );
    return profile;
  } catch (error) {
    _logAvatarEvent(
      facade,
      level: 'error',
      title: 'Picacg avatar profile fetch failed',
      content: {'sourceKey': sourceKey, 'error': error.toString()},
    );
    return null;
  }
}

_PicacgProfileData? _picacgProfileFromProfileResult({
  required String sourceKey,
  required dynamic result,
}) {
  if (result is! Map) {
    return null;
  }
  final parsedBody = result['parsedBody'];
  if (parsedBody is Map) {
    final profile = _picacgProfileFromMap(
      sourceKey: sourceKey,
      map: parsedBody,
    );
    if (profile != null) {
      return profile;
    }
  }
  final body = result['body']?.toString();
  if (body == null || body.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      return _picacgProfileFromMap(sourceKey: sourceKey, map: decoded);
    }
  } catch (_) {}
  return null;
}

_PicacgProfileData? _picacgProfileFromMap({
  required String sourceKey,
  required Map<dynamic, dynamic> map,
}) {
  final profile = _findPicacgProfileMap(map);
  if (profile == null) {
    return null;
  }
  final avatarUrl = normalizeSourceAvatarUrl(
    sourceKey: sourceKey,
    avatar: profile['avatar'],
  );
  final displayName = profile['name']?.toString().trim();
  if ((displayName == null || displayName.isEmpty) && avatarUrl == null) {
    return null;
  }
  return _PicacgProfileData(displayName: displayName, avatarUrl: avatarUrl);
}

Map<dynamic, dynamic>? _findPicacgProfileMap(Map<dynamic, dynamic> map) {
  if (map['avatar'] != null || map['name'] != null) {
    return map;
  }
  final data = map['data'];
  if (data is Map) {
    if (data['avatar'] != null || data['name'] != null) {
      return data;
    }
    final user = data['user'];
    if (user is Map) {
      return user;
    }
  }
  final user = map['user'];
  if (user is Map) {
    return user;
  }
  return null;
}

class _PicacgProfileData {
  const _PicacgProfileData({this.displayName, this.avatarUrl});

  final String? displayName;
  final String? avatarUrl;
}

String? _extractPicacgLoginToken(dynamic result) {
  if (result is! Map) {
    return null;
  }
  final authResponses = result['authResponses'];
  if (authResponses is! List) {
    return null;
  }
  for (final response in authResponses) {
    if (response is! Map) {
      continue;
    }
    final parsedBody = response['parsedBody'];
    if (parsedBody is Map) {
      final data = parsedBody['data'];
      final token = data is Map ? data['token']?.toString() : null;
      if (token != null && token.trim().isNotEmpty) {
        return token;
      }
    }
    final body = response['body']?.toString();
    if (body == null || body.trim().isEmpty) {
      continue;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final data = decoded['data'];
        final token = data is Map ? data['token']?.toString() : null;
        if (token != null && token.trim().isNotEmpty) {
          return token;
        }
      }
    } catch (_) {}
  }
  return null;
}

Map<String, dynamic>? _decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    return null;
  }
  try {
    final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
    final payloadText = utf8.decode(payloadBytes);
    final decoded = jsonDecode(payloadText);
    if (decoded is Map) {
      return Map<String, dynamic>.from(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
  } catch (_) {}
  return null;
}

void _logPicacgLoginResponseTrace(
  HazukiSourceFacade facade, {
  required String sourceKey,
  required dynamic result,
  String? error,
}) {
  if (!isHazukiPicacgSourceKey(sourceKey)) {
    return;
  }
  final safeResult = jsonSafe(result);
  final responses = safeResult is Map ? safeResult['authResponses'] : null;
  facade.addApplicationLog(
    level: error == null ? 'info' : 'error',
    title: error == null
        ? 'Picacg login server response'
        : 'Picacg login server response failed',
    source: 'source_login',
    content: {
      'sourceKey': sourceKey,
      'error': ?error,
      'responseCount': responses is List ? responses.length : 0,
      'result': safeResult,
    },
  );
}
