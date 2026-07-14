import 'dart:io';

import '../../../models/hazuki_models.dart';
import 'debug_log_internals.dart';
import '../runtime/source_runtime_facade.dart';

class SourceFavoritesDebugCapability {
  SourceFavoritesDebugCapability({
    required HazukiSourceFacade Function() activeFacade,
    required String? Function() currentAccount,
    required Future<bool> Function() ensureFavoriteSessionReady,
    required Future<FavoriteComicsResult> Function({
      required int page,
      required String folderId,
    })
    loadFavoriteComics,
  }) : _activeFacade = activeFacade,
       _currentAccount = currentAccount,
       _ensureFavoriteSessionReady = ensureFavoriteSessionReady,
       _loadFavoriteComics = loadFavoriteComics;

  final HazukiSourceFacade Function() _activeFacade;
  final String? Function() _currentAccount;
  final Future<bool> Function() _ensureFavoriteSessionReady;
  final Future<FavoriteComicsResult> Function({
    required int page,
    required String folderId,
  })
  _loadFavoriteComics;

  Future<void> warmUpFavoritesDebugInfo() async {
    final facade = _activeFacade();
    if (!facade.softwareLogCaptureEnabled || !facade.isLogged) {
      return;
    }
    if (facade.debug.isWarmingUpFavoritesDebug) {
      return;
    }
    facade.debug.isWarmingUpFavoritesDebug = true;
    try {
      await _collectFavoritesDebugInfoCore(includeNetworkCalls: false);
    } catch (_) {
      // Ignore background warmup failures.
    } finally {
      facade.debug.isWarmingUpFavoritesDebug = false;
    }
  }

  Future<Map<String, dynamic>> collectFavoritesDebugInfo({
    bool forceRefresh = true,
  }) async {
    final facade = _activeFacade();
    if (!facade.softwareLogCaptureEnabled) {
      return _buildDisabledFavoritesDebugInfo();
    }
    if (!forceRefresh && facade.favoritesDebugCache != null) {
      return facade.favoritesDebugCache!;
    }
    return _collectFavoritesDebugInfoCore(includeNetworkCalls: true);
  }

  Future<Map<String, dynamic>> _collectFavoritesDebugInfoCore({
    required bool includeNetworkCalls,
  }) async {
    final facade = _activeFacade();
    if (!facade.softwareLogCaptureEnabled) {
      return _buildDisabledFavoritesDebugInfo();
    }
    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }
    if (includeNetworkCalls && facade.isLogged) {
      await _ensureFavoriteSessionReady();
    }

    final info = <String, dynamic>{
      'statusText': facade.statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
        'supportsAccount': facade.sourceMeta?.supportsAccount,
      },
      'isLogged': facade.isLogged,
      'currentAccount': _currentAccount(),
      'generatedAt': DateTime.now().toIso8601String(),
      'checks': <String, dynamic>{},
      'calls': <String, dynamic>{},
      'favoritePageLoadResult': <String, dynamic>{},
    };

    if (!includeNetworkCalls) {
      info['skippedNetworkCalls'] = true;
      info['skipReason'] = 'background_warmup';
    }

    final checks = info['checks'] as Map<String, dynamic>;
    checks['hasSource'] = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source'),
    );
    checks['hasFavorites'] = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source?.favorites'),
    );
    checks['multiFolder'] = jsonSafe(
      engine.evaluate('this.__hazuki_source?.favorites?.multiFolder'),
    );
    checks['hasLoadFolders'] = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source?.favorites?.loadFolders'),
    );
    checks['hasLoadComics'] = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source?.favorites?.loadComics'),
    );
    checks['hasLoadNext'] = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source?.favorites?.loadNext'),
    );

    if (!includeNetworkCalls) {
      facade.favoritesDebugCache = info;
      return info;
    }

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

    final pageLoad = await _loadFavoriteComics(page: 1, folderId: '0');
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

    facade.favoritesDebugCache = info;
    return info;
  }

  Map<String, dynamic> _buildDisabledFavoritesDebugInfo() {
    final facade = _activeFacade();
    return <String, dynamic>{
      'statusText': facade.statusText,
      'platform': Platform.operatingSystem,
      'sourceMeta': {
        'name': facade.sourceMeta?.name,
        'key': facade.sourceMeta?.key,
        'version': facade.sourceMeta?.version,
        'supportsAccount': facade.sourceMeta?.supportsAccount,
      },
      'isLogged': facade.isLogged,
      'currentAccount': _currentAccount(),
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
    final facade = _activeFacade();
    final engine = facade.js.engine;
    if (engine == null) {
      return {'ok': false, 'error': 'engine is null'};
    }

    try {
      final result = engine.evaluate(code, name: name);
      final resolved = await facade.js
          .resolve(result)
          .timeout(const Duration(seconds: 20));
      return {'ok': true, 'data': jsonSafe(resolved)};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
