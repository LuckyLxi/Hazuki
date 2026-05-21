part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceCheckInCapability on HazukiSourceService {
  Future<bool> isDailyCheckInCompletedToday() async {
    if (!isActiveDailyCheckInSource) {
      return false;
    }

    final facade = this.facade;
    await facade.ensureInitialized();

    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null || !isLogged) {
      return false;
    }

    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      final remoteChecked = await _isPicacgDailyCheckInCompleted(
        facade,
        sourceKey: sourceMeta.key,
      );
      if (remoteChecked != null) {
        if (remoteChecked) {
          await facade.saveSourceData(
            sourceMeta.key,
            'lastCheckInDate',
            _dailyCheckInDateTag(DateTime.now()),
          );
        }
        return remoteChecked;
      }
    }

    final today = _dailyCheckInDateTag(DateTime.now());
    final cachedDate =
        (facade.loadSourceData(sourceMeta.key, 'lastCheckInDate') ?? '')
            .toString()
            .trim();
    return cachedDate == today;
  }

  Future<DailyCheckInResult> performDailyCheckIn() async {
    if (!isActiveDailyCheckInSource) {
      return const DailyCheckInResult.skipped();
    }

    final facade = this.facade;
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    final sourceMeta = facade.sourceMeta;
    if (engine == null || sourceMeta == null) {
      throw Exception('source_not_initialized');
    }

    if (!isLogged) {
      return const DailyCheckInResult.skipped();
    }

    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      return _performPicacgDailyCheckIn(facade, sourceKey: sourceMeta.key);
    }

    final today = _dailyCheckInDateTag(DateTime.now());
    final cachedDate =
        (facade.loadSourceData(sourceMeta.key, 'lastCheckInDate') ?? '')
            .toString()
            .trim();
    if (cachedDate == today) {
      return const DailyCheckInResult.alreadyCheckedIn();
    }

    final uidRaw = engine.evaluate('this.__hazuki_source.loadData("uid")');
    final uid = (await facade.js.resolve(uidRaw) ?? '').toString().trim();
    if (!RegExp(r'^\d+$').hasMatch(uid)) {
      throw Exception('invalid_uid');
    }

    final baseUrl = (engine.evaluate('this.__hazuki_source.baseUrl') ?? '')
        .toString()
        .trim();
    if (baseUrl.isEmpty) {
      throw Exception('invalid_base_url');
    }

    final checkRecordText = await _runWithReloginRetry(() async {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.get(${jsonEncode('$baseUrl/daily?user_id=$uid')})',
        name: 'source_daily_check_record.js',
      );
      return (await facade.js.resolve(result) ?? '').toString();
    });

    final checkRecord = _parseDailyCheckInMap(checkRecordText);
    final dailyId = checkRecord['daily_id']?.toString().trim() ?? '';
    if (dailyId.isEmpty) {
      throw Exception('invalid_daily_id');
    }

    final checkResultText = await _runWithReloginRetry(() async {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.post(${jsonEncode('$baseUrl/daily_chk')}, ${jsonEncode('user_id=$uid&daily_id=$dailyId')})',
        name: 'source_daily_check_submit.js',
      );
      return (await facade.js.resolve(result) ?? '').toString();
    });

    final checkResult = _parseDailyCheckInMap(checkResultText);
    final message = checkResult['msg']?.toString().trim() ?? '';
    if (message.isEmpty) {
      throw Exception('invalid_check_in_result');
    }

    if (_looksLikeAlreadyCheckedInMessage(message)) {
      await facade.saveSourceData(sourceMeta.key, 'lastCheckInDate', today);
      return DailyCheckInResult.alreadyCheckedIn(message);
    }

    await facade.saveSourceData(sourceMeta.key, 'lastCheckInDate', today);
    return DailyCheckInResult.success(message);
  }

  Future<DailyCheckInResult> _performPicacgDailyCheckIn(
    HazukiSourceFacade facade, {
    required String sourceKey,
  }) async {
    final today = _dailyCheckInDateTag(DateTime.now());
    final cachedDate =
        (facade.loadSourceData(sourceKey, 'lastCheckInDate') ?? '')
            .toString()
            .trim();
    if (cachedDate == today) {
      return const DailyCheckInResult.alreadyCheckedIn();
    }

    final checkedBefore = await _isPicacgDailyCheckInCompleted(
      facade,
      sourceKey: sourceKey,
    );
    if (checkedBefore == true) {
      await facade.saveSourceData(sourceKey, 'lastCheckInDate', today);
      return const DailyCheckInResult.alreadyCheckedIn();
    }

    var token = _picacgStoredToken(facade, sourceKey);
    if (token == null) {
      throw Exception('picacg_token_missing');
    }

    var response = await _picacgSignedRequest(
      facade,
      sourceKey: sourceKey,
      method: 'POST',
      endpoint: '/users/punch-in',
      token: token,
    );
    if (response.statusCode == 401) {
      final reloginOk = await _tryReloginFromStoredAccount(force: true);
      token = _picacgStoredToken(facade, sourceKey);
      if (reloginOk && token != null) {
        response = await _picacgSignedRequest(
          facade,
          sourceKey: sourceKey,
          method: 'POST',
          endpoint: '/users/punch-in',
          token: token,
        );
      }
    }

    if (response.statusCode == 401) {
      throw Exception('picacg_login_expired');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('picacg_check_in_failed:${response.statusCode}');
    }

    final status = _picacgResponseData(
      response.body,
    )['status']?.toString().trim().toLowerCase();
    if (status != null && status.isNotEmpty && status != 'ok') {
      throw Exception('picacg_check_in_failed:$status');
    }

    final checkedAfter = await _isPicacgDailyCheckInCompleted(
      facade,
      sourceKey: sourceKey,
    );
    if (checkedAfter == true) {
      await facade.saveSourceData(sourceKey, 'lastCheckInDate', today);
      return const DailyCheckInResult.success();
    }

    await facade.saveSourceData(sourceKey, 'lastCheckInDate', today);
    return const DailyCheckInResult.success();
  }

  Future<bool?> _isPicacgDailyCheckInCompleted(
    HazukiSourceFacade facade, {
    required String sourceKey,
  }) async {
    var token = _picacgStoredToken(facade, sourceKey);
    if (token == null) {
      return null;
    }

    var response = await _picacgSignedRequest(
      facade,
      sourceKey: sourceKey,
      method: 'GET',
      endpoint: '/users/profile',
      token: token,
    );
    if (response.statusCode == 401) {
      final reloginOk = await _tryReloginFromStoredAccount(force: true);
      token = _picacgStoredToken(facade, sourceKey);
      if (reloginOk && token != null) {
        response = await _picacgSignedRequest(
          facade,
          sourceKey: sourceKey,
          method: 'GET',
          endpoint: '/users/profile',
          token: token,
        );
      }
    }

    if (response.statusCode == 401) {
      throw Exception('picacg_login_expired');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return _extractPicacgIsPunched(response.body);
  }

  Future<_PicacgSignedResponse> _picacgSignedRequest(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required String method,
    required String endpoint,
    String? token,
  }) async {
    final normalizedMethod = method.toUpperCase();
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';
    final baseUrl = _picacgBaseUrl(facade, sourceKey);
    final url = '$baseUrl$normalizedEndpoint';
    final signedHeaders = _picacgSignedHeaders(
      facade,
      sourceKey: sourceKey,
      endpoint: normalizedEndpoint,
      method: normalizedMethod,
      token: token,
    );
    final startedAt = DateTime.now();
    try {
      final response = normalizedMethod == 'GET'
          ? await facade.httpGateway.request<String>(
              url,
              options: Options(headers: signedHeaders),
              withCookies: false,
            )
          : await facade.httpGateway.request<String>(
              url,
              method: 'POST',
              options: Options(headers: signedHeaders),
              retryPolicy: HazukiNetworkRetryPolicy.none,
              withCookies: false,
            );
      final body = response.data ?? '';
      facade.networkLogSink.append(
        method: normalizedMethod,
        url: url,
        statusCode: response.statusCode,
        error: null,
        startedAt: startedAt,
        source: 'picacg_check_in',
        requestHeaders: _redactPicacgHeaders(signedHeaders),
        responseHeaders: _flattenDioHeaders(response.headers),
        responseBody: _jsonDecodeOrText(body),
      );
      return _PicacgSignedResponse(
        statusCode: response.statusCode ?? 0,
        body: body,
      );
    } catch (error) {
      facade.networkLogSink.append(
        method: normalizedMethod,
        url: url,
        statusCode: null,
        error: error.toString(),
        startedAt: startedAt,
        source: 'picacg_check_in',
        requestHeaders: _redactPicacgHeaders(signedHeaders),
      );
      rethrow;
    }
  }

  Map<String, String> _picacgSignedHeaders(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required String endpoint,
    required String method,
    String? token,
  }) {
    const apiKey = 'C69BAF41DA5ABD1FFEDC6D2FEA56B';
    const secret =
        r'~d}$Q7$eIni=V)9\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn';
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final nonce = _picacgNonce();
    final raw = '$endpoint$timestamp$nonce$method$apiKey'.toLowerCase();
    final signature = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(raw)).toString();
    final imageQuality = facade
        .loadSourceSetting(sourceKey, 'imageQuality')
        ?.toString()
        .trim();
    return {
      'accept': 'application/vnd.picacomic.com.v1+json',
      'api-key': apiKey,
      'app-channel': '2',
      'app-version': '2.2.1.2.3.3',
      'app-uuid': 'defaultUuid',
      'app-platform': 'android',
      'app-build-version': '44',
      'user-agent': 'okhttp/3.8.1',
      'image-quality': (imageQuality == null || imageQuality.isEmpty)
          ? 'original'
          : imageQuality,
      'content-type': 'application/json; charset=UTF-8',
      'time': timestamp,
      'nonce': nonce,
      'signature': signature,
      if (token != null && token.trim().isNotEmpty)
        'authorization': token.trim(),
    };
  }

  String _picacgBaseUrl(HazukiSourceFacade facade, String sourceKey) {
    final raw = facade.loadSourceSetting(sourceKey, 'base_url')?.toString();
    final normalized = (raw == null || raw.trim().isEmpty)
        ? 'https://picaapi.picacomic.com'
        : raw.trim();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  String? _picacgStoredToken(HazukiSourceFacade facade, String sourceKey) {
    final token = facade.loadSourceData(sourceKey, 'token')?.toString().trim();
    return token == null || token.isEmpty ? null : token;
  }

  String _picacgNonce() {
    const hex = '0123456789abcdef';
    final random = math.Random.secure();
    return String.fromCharCodes(
      List<int>.generate(32, (_) => hex.codeUnitAt(random.nextInt(16))),
    );
  }

  bool? _extractPicacgIsPunched(String body) {
    final decoded = _jsonDecodeOrText(body);
    if (decoded is! Map) {
      return null;
    }
    final direct = _boolFromDynamic(decoded['isPunched']);
    if (direct != null) {
      return direct;
    }
    final data = decoded['data'];
    if (data is Map) {
      final fromData = _boolFromDynamic(data['isPunched']);
      if (fromData != null) {
        return fromData;
      }
      final user = data['user'];
      if (user is Map) {
        return _boolFromDynamic(user['isPunched']);
      }
    }
    final user = decoded['user'];
    if (user is Map) {
      return _boolFromDynamic(user['isPunched']);
    }
    return null;
  }

  Map<dynamic, dynamic> _picacgResponseData(String body) {
    final decoded = _jsonDecodeOrText(body);
    if (decoded is! Map) {
      return const {};
    }
    final data = decoded['data'];
    return data is Map ? data : const {};
  }

  bool? _boolFromDynamic(dynamic value) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return null;
  }

  dynamic _jsonDecodeOrText(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  Map<String, dynamic> _redactPicacgHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      final lower = key.toLowerCase();
      if (lower == 'authorization' || lower == 'signature') {
        return MapEntry(key, value.isEmpty ? value : '<redacted>');
      }
      return MapEntry(key, value);
    });
  }

  Map<String, dynamic> _flattenDioHeaders(Headers headers) {
    return headers.map.map((key, values) => MapEntry(key, values.join(', ')));
  }

  String _dailyCheckInDateTag(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _parseDailyCheckInMap(String raw) {
    if (raw.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return const <String, dynamic>{};
  }

  bool _looksLikeAlreadyCheckedInMessage(String message) {
    final lower = message.trim().toLowerCase();
    return lower.contains('already checked') ||
        message.contains('\u5df2\u7b7e\u5230') ||
        message.contains('\u4eca\u5929\u5df2\u7b7e');
  }
}

class _PicacgSignedResponse {
  const _PicacgSignedResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
