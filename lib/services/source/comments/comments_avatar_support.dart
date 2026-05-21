part of '../../hazuki_source_service.dart';

@visibleForTesting
String? normalizeSourceAvatarUrl({
  required String sourceKey,
  required Object? avatar,
  String imageBase = '',
}) {
  if (avatar is Map) {
    final fullUrl = avatar['fullUrl']?.toString().trim();
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return normalizeSourceAvatarUrl(
        sourceKey: sourceKey,
        avatar: fullUrl,
        imageBase: imageBase,
      );
    }
    final fileServer = avatar['fileServer']?.toString().trim() ?? '';
    final path = avatar['path']?.toString().trim();
    if (path != null && path.isNotEmpty) {
      final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
      final baseUri = Uri.tryParse(fileServer);
      if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
        return baseUri.resolve('/static/$normalizedPath').toString();
      }
      return normalizeSourceAvatarUrl(
        sourceKey: sourceKey,
        avatar: normalizedPath,
        imageBase: imageBase,
      );
    }
  }

  final raw = avatar?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  final normalizedPath = raw.replaceFirst(RegExp(r'^/+'), '');
  final baseUri = Uri.tryParse(imageBase);
  if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
    return baseUri.resolve('/$normalizedPath').toString();
  }

  if (isHazukiCopyMangaSourceKey(sourceKey) &&
      normalizedPath.startsWith('user/cover/')) {
    return 'https://s3.mangafuna.xyz/$normalizedPath';
  }

  return null;
}

String _avatarUrlForDisplay({
  required String sourceKey,
  required String avatarUrl,
}) {
  final uri = Uri.tryParse(avatarUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return avatarUrl;
  }
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'hazuki_avatar_refresh': DateTime.now().millisecondsSinceEpoch
              .toString(),
        },
      )
      .toString();
}

extension HazukiSourceServiceCommentsAvatarSupport on HazukiSourceService {
  Future<String?> loadCurrentAvatarUrl() async {
    final facade = this.facade;
    final sourceKey = facade.sourceMeta?.key ?? facade.sourceKey;
    _logAvatarEvent(
      facade,
      title: 'Avatar load started',
      content: {
        'sourceKey': sourceKey,
        'isLogged': facade.isLogged,
        'hasEngine': facade.js.engine != null,
      },
    );
    if (!facade.isLogged) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar load skipped',
        content: {'reason': 'not_logged', 'sourceKey': sourceKey},
      );
      return null;
    }

    final engine = facade.js.engine;
    if (engine == null) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar load skipped',
        content: {'reason': 'missing_engine', 'sourceKey': sourceKey},
      );
      return null;
    }

    final transientAvatarUrl = facade.runtime.transientAvatarUrl?.trim();
    if (transientAvatarUrl != null && transientAvatarUrl.isNotEmpty) {
      final avatarUrl = _avatarUrlForDisplay(
        sourceKey: sourceKey,
        avatarUrl: transientAvatarUrl,
      );
      _logAvatarEvent(
        facade,
        title: 'Avatar resolved from login response',
        content: {'sourceKey': sourceKey, 'avatarUrl': avatarUrl},
      );
      return avatarUrl;
    }

    final storedAvatarUrl = facade
        .loadSourceData(sourceKey, 'avatar_url')
        ?.toString()
        .trim();
    if (storedAvatarUrl != null && storedAvatarUrl.isNotEmpty) {
      final avatarUrl = _avatarUrlForDisplay(
        sourceKey: sourceKey,
        avatarUrl: storedAvatarUrl,
      );
      _logAvatarEvent(
        facade,
        title: 'Avatar resolved from stored profile',
        content: {'sourceKey': sourceKey, 'avatarUrl': avatarUrl},
      );
      return avatarUrl;
    }

    final baseUrl = facade.js.evaluateString('this.__hazuki_source.baseUrl');
    final imageUrl = facade.js.evaluateString('this.__hazuki_source.imageUrl');
    _logAvatarEvent(
      facade,
      title: 'Avatar JM uid path check',
      content: {
        'sourceKey': sourceKey,
        'hasBaseUrl': baseUrl.isNotEmpty,
        'hasImageUrl': imageUrl.isNotEmpty,
      },
    );
    if (baseUrl.isNotEmpty) {
      final baseUri = Uri.tryParse(baseUrl);
      if (baseUri != null && baseUri.hasScheme && baseUri.host.isNotEmpty) {
        final imageBaseUri = facade.resolveImageBaseUri(imageUrl, baseUri);
        try {
          final storedUidRaw = facade.js.evaluate(
            'this.__hazuki_source.loadData("uid")',
          );
          final storedUid = (await facade.js.resolve(storedUidRaw) ?? '')
              .toString()
              .trim();
          if (RegExp(r'^\d+$').hasMatch(storedUid)) {
            final avatarUrl = imageBaseUri
                .resolve('/media/users/$storedUid.jpg')
                .toString();
            _logAvatarEvent(
              facade,
              title: 'Avatar resolved from uid',
              content: {
                'sourceKey': sourceKey,
                'uid': storedUid,
                'avatarUrl': avatarUrl,
              },
            );
            return _avatarUrlForDisplay(
              sourceKey: sourceKey,
              avatarUrl: avatarUrl,
            );
          }
          _logAvatarEvent(
            facade,
            title: 'Avatar uid unavailable',
            content: {'sourceKey': sourceKey, 'uid': storedUid},
          );
        } catch (error) {
          _logAvatarEvent(
            facade,
            level: 'warn',
            title: 'Avatar uid read failed',
            content: {'sourceKey': sourceKey, 'error': error.toString()},
          );
        }
      }
    }

    if (isHazukiCopyMangaSourceKey(sourceKey)) {
      return _tryRefreshCopyMangaAvatarViaLogin(facade);
    }

    final apiAvatarUrl = await _tryFetchAvatarViaApi(engine, facade);
    if (apiAvatarUrl != null) {
      return apiAvatarUrl;
    }

    return null;
  }

  Future<String?> _tryFetchAvatarViaApi(
    dynamic engine,
    HazukiSourceFacade facade,
  ) async {
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar API fetch skipped',
        content: {'reason': 'missing_source_meta'},
      );
      return null;
    }

    try {
      _logAvatarEvent(
        facade,
        title: 'Avatar API fetch started',
        content: {'sourceKey': sourceMeta.key},
      );
      final result = engine.evaluate(r'''
        (async () => {
          try {
            let apiUrl = this.__hazuki_source.apiUrl;
            if (!apiUrl) return "__NO_API_URL__";
            let res = await Network.get(
              apiUrl + "/api/v3/me",
              this.__hazuki_source.headers
            );
            return "__RAW__" + res.status + "|" + (res.body || "");
          } catch (e) {
            return "__ERR__" + String(e);
          }
        })()
        ''', name: 'fetch_avatar_url.js');

      final resolved = await facade.js.resolve(result);
      final raw = resolved?.toString() ?? '';
      if (!raw.startsWith('__RAW__')) {
        _logAvatarEvent(
          facade,
          level: 'warn',
          title: 'Avatar API fetch failed',
          content: {
            'sourceKey': sourceMeta.key,
            'stage': 'js_result',
            'raw': raw,
          },
        );
        return null;
      }

      final payload = raw.substring('__RAW__'.length);
      final sepIdx = payload.indexOf('|');
      if (sepIdx < 0) {
        _logAvatarEvent(
          facade,
          level: 'warn',
          title: 'Avatar API response malformed',
          content: {'sourceKey': sourceMeta.key, 'raw': raw},
        );
        return null;
      }

      final statusCode = int.tryParse(payload.substring(0, sepIdx)) ?? 0;
      final body = payload.substring(sepIdx + 1);
      if (statusCode != 200 || body.isEmpty) {
        _logAvatarEvent(
          facade,
          level: 'warn',
          title: 'Avatar API response unusable',
          content: {
            'sourceKey': sourceMeta.key,
            'statusCode': statusCode,
            'bodyLength': body.length,
            'body': body,
          },
        );
        return null;
      }

      final data = jsonDecode(body);
      final results = data is Map ? data['results'] : null;
      if (results is! Map) {
        _logAvatarEvent(
          facade,
          level: 'warn',
          title: 'Avatar API results missing',
          content: {'sourceKey': sourceMeta.key, 'body': body},
        );
        return null;
      }

      final imageBase = facade.js.evaluateString(
        'this.__hazuki_source.imageUrl',
      );
      final avatarUrl = normalizeSourceAvatarUrl(
        sourceKey: sourceMeta.key,
        avatar:
            results['avatar'] ??
            results['user_cover'] ??
            results['cover'] ??
            results['avatar_url'] ??
            results['user_avatar'],
        imageBase: imageBase,
      );
      if (avatarUrl == null) {
        _logAvatarEvent(
          facade,
          level: 'warn',
          title: 'Avatar URL normalize failed',
          content: {
            'sourceKey': sourceMeta.key,
            'avatar':
                results['avatar'] ??
                results['user_cover'] ??
                results['cover'] ??
                results['avatar_url'] ??
                results['user_avatar'],
            'imageBase': imageBase,
          },
        );
        return null;
      }

      _logAvatarEvent(
        facade,
        title: 'Avatar API fetch succeeded',
        content: {'sourceKey': sourceMeta.key, 'avatarUrl': avatarUrl},
      );
      return _avatarUrlForDisplay(
        sourceKey: sourceMeta.key,
        avatarUrl: avatarUrl,
      );
    } catch (error) {
      _logAvatarEvent(
        facade,
        level: 'error',
        title: 'Avatar API fetch threw',
        content: {'sourceKey': sourceMeta.key, 'error': error.toString()},
      );
    }

    return null;
  }

  Future<String?> _tryRefreshCopyMangaAvatarViaLogin(
    HazukiSourceFacade facade,
  ) async {
    final sourceMeta = facade.sourceMeta;
    final engine = facade.js.engine;
    if (sourceMeta == null ||
        engine == null ||
        !isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      return null;
    }
    final accountData = facade.loadAccountDataSync();
    if (accountData == null || accountData.length < 2) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar relogin skipped',
        content: {'sourceKey': sourceMeta.key, 'reason': 'missing_account'},
      );
      return null;
    }
    if (facade.runtime.shouldSkipRelogin(const Duration(minutes: 2))) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar relogin skipped',
        content: {'sourceKey': sourceMeta.key, 'reason': 'recent_relogin'},
      );
      return null;
    }

    _logAvatarEvent(
      facade,
      title: 'Avatar relogin fallback started',
      content: {'sourceKey': sourceMeta.key},
    );
    final result = engine.evaluate(
      _copyMangaAvatarRefreshScript(
        account: accountData[0],
        password: accountData[1],
      ),
      name: 'copy_manga_avatar_refresh.js',
    );
    final resolved = jsonSafe(await facade.js.resolve(result));
    if (resolved is! Map || resolved['ok'] != true) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar relogin fallback failed',
        content: {'sourceKey': sourceMeta.key, 'result': resolved},
      );
      return null;
    }

    final loginResult = resolved['result'];
    await _persistLoginSideData(
      facade,
      sourceKey: sourceMeta.key,
      result: loginResult,
    );
    facade.lastReloginAt = DateTime.now();

    final refreshedAvatarUrl = facade.runtime.transientAvatarUrl?.trim();
    if (refreshedAvatarUrl == null || refreshedAvatarUrl.isEmpty) {
      _logAvatarEvent(
        facade,
        level: 'warn',
        title: 'Avatar relogin returned no avatar',
        content: {'sourceKey': sourceMeta.key},
      );
      return null;
    }

    final avatarUrl = _avatarUrlForDisplay(
      sourceKey: sourceMeta.key,
      avatarUrl: refreshedAvatarUrl,
    );
    _logAvatarEvent(
      facade,
      title: 'Avatar relogin fallback succeeded',
      content: {'sourceKey': sourceMeta.key, 'avatarUrl': avatarUrl},
    );
    return avatarUrl;
  }
}

String _copyMangaAvatarRefreshScript({
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
  try {
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
    if (!response || response.status !== 200) {
      return {
        ok: false,
        status: response && response.status,
        body: response && response.body
      };
    }
    const data = JSON.parse(response.body);
    const token = data && data.results && data.results.token;
    if (token) {
      source.saveData("token", token);
    }
    return {
      ok: true,
      status: response.status,
      result: data
    };
  } catch (error) {
    return {
      ok: false,
      error: String(error)
    };
  }
})()
''';
}

void _logAvatarEvent(
  HazukiSourceFacade facade, {
  required String title,
  Object? content,
  String level = 'info',
}) {
  facade.addApplicationLog(
    level: level,
    title: title,
    source: 'source_avatar',
    content: content,
  );
}
