part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCommentsCapability on HazukiSourceService {
Future<ComicCommentsPageResult> loadCommentsPage({
  required String comicId,
  String? subId,
  int page = 1,
  int pageSize = 16,
  String? replyTo,
}) async {
  final engine = _engine;
  if (engine == null) {
    throw Exception('漫画源尚未初始化完成');
  }

  final subIdArg = subId == null ? 'null' : jsonEncode(subId);
  final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);
  final dynamic result = engine.evaluate(
    'this.__hazuki_source.comic.loadComments(${jsonEncode(comicId)}, $subIdArg, $page, $replyToArg)',
    name: 'source_comments.js',
  );
  final dynamic resolved = await _awaitJsResult(result);
  if (resolved is! Map) {
    return const ComicCommentsPageResult(comments: [], maxPage: null);
  }

  final resultMap = Map<String, dynamic>.from(resolved);
  final commentsRaw = resultMap['comments'];
  if (commentsRaw is! List) {
    return ComicCommentsPageResult(
      comments: const [],
      maxPage: _asInt(resultMap['maxPage']),
    );
  }

  final all = commentsRaw.whereType<Map>().map((e) {
    final map = Map<String, dynamic>.from(e);
    return ComicCommentData(
      avatar: map['avatar']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      id: map['id']?.toString() ?? map['commentId']?.toString(),
      replyCount: _asInt(map['replyCount']),
      isLiked: map['isLiked'] is bool ? map['isLiked'] as bool : null,
      score: _asInt(map['score']),
      voteStatus: _asInt(map['voteStatus']),
    );
  }).toList();

  final comments = (pageSize <= 0 || all.length <= pageSize)
      ? all
      : all.sublist(0, pageSize);

  return ComicCommentsPageResult(
    comments: comments,
    maxPage: _asInt(resultMap['maxPage']),
  );
}

Future<List<ComicCommentData>> loadComments({
  required String comicId,
  String? subId,
  int page = 1,
  int pageSize = 16,
  String? replyTo,
}) async {
  final result = await loadCommentsPage(
    comicId: comicId,
    subId: subId,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
  );
  return result.comments;
}

Future<void> sendComment({
  required String comicId,
  String? subId,
  required String content,
  String? replyTo,
}) async {
  final engine = _engine;
  if (engine == null) {
    throw Exception('漫画源尚未初始化完成');
  }

  final text = content.trim();
  if (text.isEmpty) {
    throw Exception('评论内容不能为空');
  }

  final subIdArg = subId == null ? 'null' : jsonEncode(subId);
  final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);

  await _runWithReloginRetry(() async {
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.comic.sendComment(${jsonEncode(comicId)}, $subIdArg, ${jsonEncode(text)}, $replyToArg)',
      name: 'source_send_comment.js',
    );
    await _awaitJsResult(result);
  });
}

Future<String?> loadCurrentAvatarUrl() async {
  if (!isLogged) {
    return null;
  }

  final engine = _engine;
  if (engine == null) {
    return null;
  }

  final account = currentAccount?.trim();
  final baseUrl =
      (engine.evaluate('this.__hazuki_source.baseUrl') ?? '').toString().trim();
  final imageUrl =
      (engine.evaluate('this.__hazuki_source.imageUrl') ?? '').toString().trim();
  if (baseUrl.isEmpty) {
    return null;
  }

  final baseUri = Uri.tryParse(baseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
    return null;
  }

  final imageBaseUri = _resolveImageBaseUri(imageUrl, baseUri);
  final loginProbeStartedAt = DateTime.now();
  final avatarFromLogin = await _loadAvatarUrlFromLatestLoginLog(imageBaseUri);
  if (avatarFromLogin != null && avatarFromLogin.isNotEmpty) {
    return avatarFromLogin;
  }

  final avatarFromPostLogin = await _loadAvatarUrlAfterRecentLogin(
    imageBaseUri: imageBaseUri,
    since: loginProbeStartedAt,
  );
  if (avatarFromPostLogin != null && avatarFromPostLogin.isNotEmpty) {
    return avatarFromPostLogin;
  }

  final candidatePaths = <String>[
    if (account != null && account.isNotEmpty)
      '/user/${Uri.encodeComponent(account)}',
    '/user',
    '/favorite',
  ];

  var index = 0;
  for (final path in candidatePaths) {
    final startedAt = DateTime.now();
    final endpoint = baseUri.resolve(path).toString();
    try {
      final dynamic raw = engine.evaluate(
        'this.__hazuki_source.get(${jsonEncode(endpoint)})',
        name: 'source_avatar_lookup_${index++}.js',
      );
      final dynamic resolved = await _awaitJsResult(raw);
      final payload = _tryParseJsonPayload(resolved) ?? resolved;

      _appendNetworkLog(
        method: 'GET',
        url: 'source://avatar$path',
        statusCode: 200,
        error: null,
        startedAt: startedAt,
        source: 'source_avatar',
        requestHeaders: const {},
        requestData: null,
        responseHeaders: const {},
        responseBody: _jsonSafe(payload),
      );

      final avatarUrl = _extractAvatarUrlFromPayload(
        payload: payload,
        pageUrl: endpoint,
        imageBaseUri: imageBaseUri,
      );
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        return avatarUrl;
      }

      final userId = _extractUidFromPayload(payload);
      if (userId != null && userId.isNotEmpty) {
        return imageBaseUri.resolve('/media/users/$userId.jpg').toString();
      }
    } catch (e) {
      _appendNetworkLog(
        method: 'GET',
        url: 'source://avatar$path',
        statusCode: null,
        error: e.toString(),
        startedAt: startedAt,
        source: 'source_avatar',
        requestHeaders: const {},
        requestData: null,
        responseHeaders: const {},
        responseBody: null,
      );
    }
  }

  return null;
}

Future<String?> _loadAvatarUrlFromLatestLoginLog(Uri imageBaseUri) async {
  const retryDelaysMs = <int>[0, 220, 360];

  Map<String, dynamic>? loginLog;
  for (var index = 0; index < retryDelaysMs.length; index++) {
    final delayMs = retryDelaysMs[index];
    final attempt = index + 1;

    if (delayMs > 0) {
      _appendNetworkLog(
        method: 'GET',
        url: 'source://avatar/login_retry',
        statusCode: null,
        error: null,
        startedAt: DateTime.now(),
        source: 'source_avatar',
        requestHeaders: const {},
        requestData: null,
        responseHeaders: const {},
        responseBody: {'attempt': attempt, 'delayMs': delayMs},
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    loginLog = _findLatestLoginNetworkLog();
    if (loginLog != null) {
      if (attempt > 1) {
        _appendNetworkLog(
          method: 'GET',
          url: 'source://avatar/login_scan',
          statusCode: 200,
          error: null,
          startedAt: DateTime.now(),
          source: 'source_avatar',
          requestHeaders: const {},
          requestData: null,
          responseHeaders: const {},
          responseBody: {'result': 'login_log_found', 'attempt': attempt},
        );
      }
      break;
    }
  }

  if (loginLog == null) {
    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/login_scan',
      statusCode: null,
      error: 'login_log_not_found',
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {
        'result': 'login_log_not_found',
        'attempts': retryDelaysMs.length,
      },
    );
    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/login_retry_exhausted',
      statusCode: null,
      error: 'login_log_not_found',
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {
        'result': 'login_retry_exhausted',
        'attempts': retryDelaysMs.length,
      },
    );
    return null;
  }

  final tokenparam = _extractTokenparamFromHeaders(loginLog['requestHeaders']);
  if (tokenparam == null) {
    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/login_headers',
      statusCode: null,
      error: 'tokenparam_missing',
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {
        'result': 'tokenparam_missing',
        'login_url': (loginLog['url'] ?? '').toString(),
      },
    );
    return null;
  }

  final encryptedData = _extractEncryptedDataFromLoginResponse(
    loginLog['responseBodyFull'],
  );
  if (encryptedData == null) {
    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/login_response',
      statusCode: null,
      error: 'login_data_missing',
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {
        'result': 'login_data_missing',
        'login_url': (loginLog['url'] ?? '').toString(),
      },
    );
    return null;
  }

  try {
    final decrypted = _decryptJmPayload(
      encryptedBase64: encryptedData,
      tokenparam: tokenparam,
    );
    if (decrypted == null || decrypted.isEmpty) {
      _appendNetworkLog(
        method: 'GET',
        url: 'source://avatar/login_decrypt',
        statusCode: null,
        error: 'decrypt_empty',
        startedAt: DateTime.now(),
        source: 'source_avatar',
        requestHeaders: const {},
        requestData: null,
        responseHeaders: const {},
        responseBody: {'result': 'decrypt_empty'},
      );
      return null;
    }

    final payload = _tryParseJsonPayload(decrypted);
    final avatarUrl = _extractAvatarUrlFromPayload(
      payload: payload,
      pageUrl: (loginLog['url'] ?? '').toString(),
      imageBaseUri: imageBaseUri,
    );
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      _appendNetworkLog(
        method: 'GET',
        url: 'source://avatar/login_payload',
        statusCode: 200,
        error: null,
        startedAt: DateTime.now(),
        source: 'source_avatar',
        requestHeaders: const {},
        requestData: null,
        responseHeaders: const {},
        responseBody: {'result': 'avatar_from_login', 'avatar': avatarUrl},
      );
      return avatarUrl;
    }

    final uid = _extractUidFromPayload(payload);
    if (uid != null && uid.isNotEmpty) {
      final url = imageBaseUri.resolve('/media/users/$uid.jpg').toString();
      _appendNetworkLog(
        method: 'GET',
        url: 'source://avatar/login_payload',
        statusCode: 200,
        error: null,
        startedAt: DateTime.now(),
        source: 'source_avatar',
        requestHeaders: const {},
        requestData: null,
        responseHeaders: const {},
        responseBody: {'result': 'avatar_from_login_uid', 'uid': uid, 'avatar': url},
      );
      return url;
    }

    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/login_payload',
      statusCode: null,
      error: 'payload_without_avatar_uid',
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {
        'result': 'payload_without_avatar_uid',
        'payloadType': payload.runtimeType.toString(),
      },
    );
  } catch (e) {
    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/login_payload',
      statusCode: null,
      error: e.toString(),
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {'result': 'decrypt_failed'},
    );
  }

  return null;
}

Future<String?> _loadAvatarUrlAfterRecentLogin({
  required Uri imageBaseUri,
  required DateTime since,
}) async {
  const postLoginWaitsMs = <int>[300, 450, 700, 900];

  for (var i = 0; i < postLoginWaitsMs.length; i++) {
    final delayMs = postLoginWaitsMs[i];
    final attempt = i + 1;
    await Future<void>.delayed(Duration(milliseconds: delayMs));

    final loginInfo = _lastLoginDebugInfo;
    final loginOk = loginInfo?['ok'] == true;
    final loginTimeRaw = loginInfo?['time']?.toString();
    final loginTime =
        loginTimeRaw == null ? null : DateTime.tryParse(loginTimeRaw)?.toLocal();

    final loginLog = _findLatestLoginNetworkLog();
    final hasLoginLog = loginLog != null;

    _appendNetworkLog(
      method: 'GET',
      url: 'source://avatar/post_login_wait',
      statusCode: null,
      error: null,
      startedAt: DateTime.now(),
      source: 'source_avatar',
      requestHeaders: const {},
      requestData: null,
      responseHeaders: const {},
      responseBody: {
        'attempt': attempt,
        'delayMs': delayMs,
        'loginOk': loginOk,
        'loginTime': loginTime?.toIso8601String(),
        'hasLoginLog': hasLoginLog,
      },
    );

    if (loginOk && loginTime != null && loginTime.isAfter(since) && hasLoginLog) {
      final avatar = await _loadAvatarUrlFromLatestLoginLog(imageBaseUri);
      if (avatar != null && avatar.isNotEmpty) {
        _appendNetworkLog(
          method: 'GET',
          url: 'source://avatar/post_login_reprobe',
          statusCode: 200,
          error: null,
          startedAt: DateTime.now(),
          source: 'source_avatar',
          requestHeaders: const {},
          requestData: null,
          responseHeaders: const {},
          responseBody: {'result': 'avatar_after_login', 'attempt': attempt},
        );
        return avatar;
      }
    }
  }

  _appendNetworkLog(
    method: 'GET',
    url: 'source://avatar/post_login_reprobe',
    statusCode: null,
    error: 'post_login_reprobe_miss',
    startedAt: DateTime.now(),
    source: 'source_avatar',
    requestHeaders: const {},
    requestData: null,
    responseHeaders: const {},
    responseBody: {'result': 'post_login_reprobe_miss'},
  );

  return null;
}

Map<String, dynamic>? _findLatestLoginNetworkLog() {
  for (var i = _recentNetworkLogs.length - 1; i >= 0; i--) {
    final log = _recentNetworkLogs[i];
    final source = (log['source'] ?? '').toString();
    final method = (log['method'] ?? '').toString().toUpperCase();
    final url = (log['url'] ?? '').toString();
    if (source == 'js_http' &&
        method == 'POST' &&
        (url.endsWith('/login') || url.contains('/login?'))) {
      return log;
    }
  }
  return null;
}

String? _extractTokenparamFromHeaders(dynamic headers) {
  if (headers is! Map) {
    return null;
  }
  for (final entry in headers.entries) {
    final key = entry.key.toString().toLowerCase();
    if (key == 'tokenparam') {
      final value = entry.value?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

String? _extractEncryptedDataFromLoginResponse(dynamic responseBody) {
  if (responseBody == null) {
    return null;
  }
  final payload = _tryParseJsonPayload(responseBody);
  if (payload is Map) {
    final data = payload['data'];
    final text = data?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String? _decryptJmPayload({
  required String encryptedBase64,
  required String tokenparam,
}) {
  final parts = tokenparam.split(',');
  final time = parts.isEmpty ? '' : parts.first.trim();
  if (time.isEmpty) {
    return null;
  }

  final secret = '${time}185Hcomic3PAPP7R';
  final keyBytes = md5.convert(utf8.encode(secret)).bytes;
  final keyHex = keyBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final key = Uint8List.fromList(utf8.encode(keyHex));

  final encrypted = base64Decode(encryptedBase64);
  final cipher = ECBBlockCipher(AESEngine())..init(false, KeyParameter(key));
  if (encrypted.length % cipher.blockSize != 0) {
    return null;
  }

  final decrypted = Uint8List(encrypted.length);
  var offset = 0;
  while (offset < encrypted.length) {
    offset += cipher.processBlock(encrypted, offset, decrypted, offset);
  }

  final text = utf8.decode(decrypted, allowMalformed: true);
  final objectIndex = text.indexOf('{');
  final arrayIndex = text.indexOf('[');
  var start = -1;
  if (objectIndex >= 0 && arrayIndex >= 0) {
    start = objectIndex < arrayIndex ? objectIndex : arrayIndex;
  } else if (objectIndex >= 0) {
    start = objectIndex;
  } else if (arrayIndex >= 0) {
    start = arrayIndex;
  }
  if (start < 0) {
    return null;
  }

  final endObject = text.lastIndexOf('}');
  final endArray = text.lastIndexOf(']');
  final end = endObject > endArray ? endObject : endArray;
  if (end < start) {
    return null;
  }
  return text.substring(start, end + 1);
}

Uri _resolveImageBaseUri(String imageUrl, Uri baseUri) {
  final imageUri = Uri.tryParse(imageUrl);
  if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
    return imageUri;
  }
  return baseUri;
}

dynamic _tryParseJsonPayload(dynamic raw) {
  if (raw is String) {
    final text = raw.trim();
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        return jsonDecode(text);
      } catch (_) {
        return raw;
      }
    }
  }
  return raw;
}

String? _extractAvatarUrlFromPayload({
  required dynamic payload,
  required String pageUrl,
  required Uri imageBaseUri,
}) {
  final direct = RegExp(
    r'''https?://[^"'\s>]+/media/users/[^"'\s>]+(?:\.(?:jpg|jpeg|png|webp))?[^"'\s>]*''',
    caseSensitive: false,
  ).firstMatch(payload.toString())?.group(0);
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }

  final relative = RegExp(
    r'''/media/users/[^"'\s>]+(?:\.(?:jpg|jpeg|png|webp))?[^"'\s>]*''',
    caseSensitive: false,
  ).firstMatch(payload.toString())?.group(0);
  if (relative != null && relative.isNotEmpty) {
    return Uri.parse(pageUrl).resolve(relative).toString();
  }

  final avatarKeys = <String>{
    'avatar',
    'avatarurl',
    'avatar_url',
    'photo',
    'face',
    'head',
    'headimg',
    'head_img',
    'pic',
    'img',
    'image',
  };
  final candidates = <String>[];

  void collect(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final item = entry.value;
        if (item is String) {
          final text = item.trim();
          if (text.isNotEmpty &&
              (avatarKeys.contains(key) ||
                  key.contains('avatar') ||
                  key.contains('photo') ||
                  key.contains('head'))) {
            candidates.add(text);
          }
        }
        collect(item);
      }
      return;
    }

    if (value is List) {
      for (final item in value) {
        collect(item);
      }
    }
  }

  collect(payload);
  for (final candidate in candidates) {
    final text = candidate.trim();
    if (text.isEmpty) {
      continue;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    if (text.startsWith('/media/users/')) {
      return imageBaseUri.resolve(text).toString();
    }
    final lower = text.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return imageBaseUri.resolve('/media/users/$text').toString();
    }
  }

  return null;
}

String? _extractUidFromPayload(dynamic payload) {
  String? picked;

  void visit(dynamic value) {
    if (picked != null) {
      return;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final item = entry.value;
        if (key == 'uid' || key == 'user_id') {
          final text = item?.toString().trim() ?? '';
          if (RegExp(r'^\d+$').hasMatch(text)) {
            picked = text;
            return;
          }
        }
        visit(item);
      }
      return;
    }

    if (value is List) {
      for (final item in value) {
        visit(item);
        if (picked != null) {
          return;
        }
      }
    }
  }

  visit(payload);
  return picked;
}
}

