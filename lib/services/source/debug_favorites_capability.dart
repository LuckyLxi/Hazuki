part of '../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesDebugCapability on HazukiSourceService {
  Future<void> warmUpFavoritesDebugInfo() async {
    if (!_softwareLogCaptureEnabled || !isLogged) {
      return;
    }
    if (_isWarmingUpFavoritesDebug) {
      return;
    }
    _isWarmingUpFavoritesDebug = true;
    try {
      await _collectFavoritesDebugInfoCore();
    } catch (_) {
      // 静默预热，不向 UI 抛错。
    } finally {
      _isWarmingUpFavoritesDebug = false;
    }
  }

  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  }) async {
    if (!_softwareLogCaptureEnabled) {
      return _buildDisabledFavoritesDebugInfo();
    }
    if (!forceRefresh && _favoritesDebugCache != null) {
      return _favoritesDebugCache!;
    }
    return _collectFavoritesDebugInfoCore();
  }

  Future<Map<String, dynamic>> _collectFavoritesDebugInfoCore() async {
    if (!_softwareLogCaptureEnabled) {
      return _buildDisabledFavoritesDebugInfo();
    }
    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final info = <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
        'supportsAccount': _sourceMeta?.supportsAccount,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'checks': <String, dynamic>{},
      'calls': <String, dynamic>{},
      'favoritePageLoadResult': <String, dynamic>{},
    };

    final checks = info['checks'] as Map<String, dynamic>;
    checks['hasSource'] = _asBool(engine.evaluate('!!this.__hazuki_source'));
    checks['hasFavorites'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites'),
    );
    checks['multiFolder'] = _jsonSafe(
      engine.evaluate('this.__hazuki_source?.favorites?.multiFolder'),
    );
    checks['hasLoadFolders'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites?.loadFolders'),
    );
    checks['hasLoadComics'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites?.loadComics'),
    );
    checks['hasLoadNext'] = _asBool(
      engine.evaluate('!!this.__hazuki_source?.favorites?.loadNext'),
    );

    final calls = info['calls'] as Map<String, dynamic>;
    calls['loadFolders(null)'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadFolders?.(null)',
      name: 'debug_favorites_loadFolders.js',
    );
    calls['loadComics(1, "0")'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadComics?.(1, "0")',
      name: 'debug_favorites_loadComics_0.js',
    );
    calls['loadComics(1, null)'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadComics?.(1, null)',
      name: 'debug_favorites_loadComics_null.js',
    );
    calls['loadNext(null, "0")'] = await _debugJsCall(
      code: 'this.__hazuki_source.favorites?.loadNext?.(null, "0")',
      name: 'debug_favorites_loadNext.js',
    );

    final pageLoad = await loadFavoriteComics(page: 1, folderId: '0');
    final pageLoadInfo = info['favoritePageLoadResult'] as Map<String, dynamic>;
    pageLoadInfo['errorMessage'] = pageLoad.errorMessage;
    pageLoadInfo['count'] = pageLoad.comics.length;
    pageLoadInfo['firstFive'] = pageLoad.comics
        .take(5)
        .map(
          (comic) => {
            'id': comic.id,
            'title': comic.title,
            'subTitle': comic.subTitle,
            'cover': comic.cover,
          },
        )
        .toList();

    _favoritesDebugCache = info;
    return info;
  }

  Map<String, dynamic> _buildDisabledFavoritesDebugInfo() {
    return <String, dynamic>{
      'statusText': _statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': _sourceMeta?.name,
        'key': _sourceMeta?.key,
        'version': _sourceMeta?.version,
        'supportsAccount': _sourceMeta?.supportsAccount,
      },
      'isLogged': isLogged,
      'currentAccount': currentAccount,
      'generatedAt': DateTime.now().toIso8601String(),
      'captureEnabled': false,
      'disabledReason': 'software_log_capture_disabled',
      'checks': <String, dynamic>{},
      'calls': <String, dynamic>{},
      'favoritePageLoadResult': <String, dynamic>{},
    };
  }

  Future<Map<String, dynamic>> _debugJsCall({
    required String code,
    required String name,
  }) async {
    final engine = _engine;
    if (engine == null) {
      return {'ok': false, 'error': 'engine is null'};
    }

    try {
      final result = engine.evaluate(code, name: name);
      final resolved = await _awaitJsResult(
        result,
      ).timeout(const Duration(seconds: 20));
      return {'ok': true, 'data': _jsonSafe(resolved)};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
