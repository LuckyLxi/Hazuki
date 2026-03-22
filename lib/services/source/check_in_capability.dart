part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCheckInCapability on HazukiSourceService {
  Future<bool> isDailyCheckInCompletedToday() async {
    await ensureInitialized();

    final sourceMeta = _sourceMeta;
    if (sourceMeta == null || !isLogged) {
      return false;
    }

    final today = _dailyCheckInDateTag(DateTime.now());
    final cachedDate = (_loadSourceData(sourceMeta.key, 'lastCheckInDate') ?? '')
        .toString()
        .trim();
    return cachedDate == today;
  }

  Future<DailyCheckInResult> performDailyCheckIn() async {
    await ensureInitialized();

    final engine = _engine;
    final sourceMeta = _sourceMeta;
    if (engine == null || sourceMeta == null) {
      throw Exception('source_not_initialized');
    }

    if (!isLogged) {
      return const DailyCheckInResult.skipped();
    }

    final today = _dailyCheckInDateTag(DateTime.now());
    final cachedDate = (_loadSourceData(sourceMeta.key, 'lastCheckInDate') ?? '')
        .toString()
        .trim();
    if (cachedDate == today) {
      return const DailyCheckInResult.alreadyCheckedIn();
    }

    final uidRaw = engine.evaluate('this.__hazuki_source.loadData("uid")');
    final uid = (await _awaitJsResult(uidRaw) ?? '').toString().trim();
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
      return (await _awaitJsResult(result) ?? '').toString();
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
      return (await _awaitJsResult(result) ?? '').toString();
    });

    final checkResult = _parseDailyCheckInMap(checkResultText);
    final message = checkResult['msg']?.toString().trim() ?? '';
    if (message.isEmpty) {
      throw Exception('invalid_check_in_result');
    }

    if (_looksLikeAlreadyCheckedInMessage(message)) {
      await _saveSourceData(sourceMeta.key, 'lastCheckInDate', today);
      return DailyCheckInResult.alreadyCheckedIn(message);
    }

    await _saveSourceData(sourceMeta.key, 'lastCheckInDate', today);
    return DailyCheckInResult.success(message);
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
