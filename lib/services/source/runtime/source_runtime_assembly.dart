import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/hazuki_models.dart';
import '../account/account_session_capability.dart';
import '../account/source_account_operations.dart';
import '../account/source_daily_check_in_capability.dart';
import '../account/source_relogin_coordinator.dart';
import '../category/source_category_capability.dart';
import '../comic/comic_details_capability.dart';
import '../comic/source_comic_details_cache.dart';
import '../comments/comments_capability.dart';
import '../comments/source_comments_operations.dart';
import '../common/source_json_coerce.dart';
import '../content/source_content_operations.dart';
import '../debug/debug_favorites_capability.dart';
import '../debug/debug_report_capability.dart';
import '../debug/source_debug_operations.dart';
import '../explore_capability.dart';
import '../favorites/source_favorites_capability.dart';
import '../favorites/source_favorites_operations.dart';
import '../gateways/source_gateway_set.dart';
import '../image/image_cache_capability.dart';
import '../image/source_image_operations.dart';
import '../image/source_image_preparation_capability.dart';
import '../models/source_contract_models.dart';
import '../models/source_identity.dart';
import 'source_js_bridge_cookie_capability.dart';
import 'source_localization_operations.dart';
import 'source_runtime_capability.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_operations.dart';
import 'source_runtime_view.dart';
import 'source_runtime_registry.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_storage.dart';
import 'source_secure_session_storage.dart';
import '../../logging/app_log_store.dart';
import 'source_settings_operations.dart';

export '../comments/comments_avatar_support.dart' show normalizeSourceAvatarUrl;
export '../debug/source_debug_log_store.dart';
export '../models/source_contract_models.dart';
export '../models/source_identity.dart';
export 'source_cache_store.dart';
export 'source_cookie_store.dart';
export 'source_runtime_facade.dart';
export 'source_runtime_handle.dart';
export 'source_runtime_kernel.dart';
export 'source_runtime_registry.dart';
export 'source_session_store.dart';

const _jmSourceUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/jm.js',
];

const _copyMangaSourceUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/copy_manga.js',
];

const _picacgSourceUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/picacg.js',
];

const _sourceIndexUrls = [
  'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json',
];

const _bundledInitAssetPath = 'assets/init.js';

const List<SourceCatalogEntry> hazukiAllowedSourceCatalog = [
  SourceCatalogEntry(
    key: hazukiDefaultSourceKey,
    name: 'JMComic',
    fileName: 'jm.js',
    directUrls: _jmSourceUrls,
  ),
  SourceCatalogEntry(
    key: 'copy_manga',
    name: 'CopyManga',
    fileName: 'copy_manga.js',
    directUrls: _copyMangaSourceUrls,
  ),
  SourceCatalogEntry(
    key: 'picacg',
    name: 'Picacg',
    fileName: 'picacg.js',
    directUrls: _picacgSourceUrls,
  ),
];

/// Internal composition root for source runtime dependencies.
///
/// Feature and application code consume the focused source gateways instead of
/// depending on this assembly directly.
class SourceRuntimeAssembly {
  SourceRuntimeAssembly({SourceSecureSessionStorage? secureSessionStorage})
    : _secureSessionStorage =
          secureSessionStorage ?? FlutterSourceSecureSessionStorage() {
    _logStore = AppLogStore(secureStorage: _secureSessionStorage);
    _runtimeHost = SourceRuntimeHost(
      catalog: hazukiAllowedSourceCatalog,
      defaultSourceKey: hazukiDefaultSourceKey,
      secureSessionStorage: _secureSessionStorage,
      ensureSourceInitialized: (sourceKey) =>
          _runtimeCapability.initialization.ensureSourceInitialized(sourceKey),
      currentAccountForSource: (sourceKey) =>
          _accountCapability.currentAccountForSource(sourceKey),
      isLoggedForSource: (sourceKey) =>
          _accountCapability.isLoggedForSource(sourceKey),
      logStore: _logStore,
    );
    _accountCapability = SourceAccountSessionCapability(
      runtimeHost: _runtimeHost,
    );
    _reloginCoordinator = SourceReloginCoordinator(
      loginWithStoredAccount: (context, {required account, required password}) {
        final facade = (context as SourceFacadeReloginContext).facade;
        return _accountCapability.loginWithFacade(
          facade,
          account: account,
          password: password,
        );
      },
    );
    _runtimeCapability = SourceRuntimeCapability(
      runtimeHost: _runtimeHost,
      scriptStorage: _scriptStorage,
      jsBridgeCookieCapability: _jsBridgeCookieCapability,
      runtimeStateController: _runtimeStateController,
      reloginCoordinator: _reloginCoordinator,
      bundledInitAssetPath: _bundledInitAssetPath,
      sourceIndexUrls: _sourceIndexUrls,
    );
    _commentsCapability = SourceCommentsCapability(
      runtimeHost: _runtimeHost,
      reloginCoordinator: _reloginCoordinator,
    );
    _dailyCheckInCapability = SourceDailyCheckInCapability(
      runtimeHost: _runtimeHost,
      reloginCoordinator: _reloginCoordinator,
    );
    _comicDetailsCache = SourceComicDetailsCache(runtimeHost: _runtimeHost);
    _comicDetailsCapability = SourceComicDetailsCapability(
      runtimeHost: _runtimeHost,
      cache: _comicDetailsCache,
      reloginCoordinator: _reloginCoordinator,
      translateSourceText: _localizationOperations.translateSourceText,
    );
    _exploreCapability = SourceExploreCapability(
      runtimeHost: _runtimeHost,
      translateSourceText: _localizationOperations.translateSourceText,
    );
    _categoryCapability = SourceCategoryCapability(
      runtimeHost: _runtimeHost,
      translateSourceText: _localizationOperations.translateSourceText,
      parseExploreComics: _parseExploreComics,
    );
    _imagePreparationCapability = SourceImagePreparationCapability(
      runtimeHost: _runtimeHost,
      downloadImageBytes: _imageOperations.downloadImageBytes,
    );
    _favoritesCapability = SourceFavoritesCapability(
      runtimeHost: _runtimeHost,
      reloginCoordinator: _reloginCoordinator,
      parseExploreComics: _parseExploreComics,
      updateComicDetailsFavoriteState:
          ({required sourceKey, required comicId, required isFavorite}) {
            final scopedKey = SourceScopedComicId(
              sourceKey: sourceKey,
              comicId: comicId,
            ).storageKey;
            final cached = _getComicDetailsFromMemoryCache(
              scopedKey,
              sourceKey: sourceKey,
            );
            if (cached != null) {
              _comicDetailsCapability.updateFavoriteStateInMemoryCache(
                cached.scopedId,
                isFavorite: isFavorite,
              );
            }
          },
      notifyCloudFavoritesChanged: _notifyCloudFavoritesChanged,
    );
    _favoritesDebugCapability = SourceFavoritesDebugCapability(
      activeFacade: () => _facade,
      currentAccount: () => _accountOperations.currentAccount,
      ensureFavoriteSessionReady: () => _ensureFavoriteSessionReady(),
      loadFavoriteComics: ({required page, required folderId}) =>
          _favoritesCapability.loadFavoriteComics(
            page: page,
            folderId: folderId,
          ),
    );
    _debugReportCapability = SourceDebugReportCapability(
      activeFacade: () => _facade,
      currentAccount: () => _accountOperations.currentAccount,
      logStore: _logStore,
    );
  }

  final SourceSecureSessionStorage _secureSessionStorage;
  late final AppLogStore _logStore;
  late final SourceRuntimeHost _runtimeHost;
  late final SourceAccountSessionCapability _accountCapability;
  late final SourceReloginCoordinator _reloginCoordinator;
  late final SourceRuntimeCapability _runtimeCapability;
  late final SourceRuntimeOperations _runtimeOperations =
      SourceRuntimeOperationService(
        _runtimeCapability.initialization,
        _runtimeCapability.diagnostics,
        _runtimeCapability.scriptEditing,
        _runtimeCapability.sourceUpdates,
        _runtimeCapability.sourceRecovery,
      );
  late final SourceRuntimeView _runtimeView = SourceRuntimeViewService(
    runtimeHost: _runtimeHost,
    runtimeOperations: _runtimeOperations,
  );
  late final SourceLocalizationOperations _localizationOperations =
      SourceLocalizationOperations(_runtimeHost);
  late final SourceImageOperations _imageOperations =
      SourceImageOperationService(_imageCacheForSourceRequest);
  late final SourceSettingsOperations _settingsOperations =
      SourceSettingsOperations(_runtimeHost);
  late final SourceAccountOperations _accountOperations =
      SourceAccountOperationService(
        accountSession: _accountCapability,
        dailyCheckIn: _dailyCheckInCapability,
      );
  late final SourceCommentsCapability _commentsCapability;
  late final SourceCommentsOperations _commentsOperations =
      SourceCommentsOperations(
        comments: _commentsCapability,
        account: _accountOperations,
      );
  late final SourceDebugOperations _debugOperations = SourceDebugOperations(
    activeDebugLog: () => _activeHandle.debugLog,
    activeFacade: () => _facade,
    debugReport: _debugReportCapability,
    logStore: _logStore,
  );
  late final SourceFavoritesDebugCapability _favoritesDebugCapability;
  late final SourceDebugReportCapability _debugReportCapability;
  late final SourceDailyCheckInCapability _dailyCheckInCapability;
  late final SourceComicDetailsCache _comicDetailsCache;
  late final SourceComicDetailsCapability _comicDetailsCapability;
  late final SourceExploreCapability _exploreCapability;
  late final SourceCategoryCapability _categoryCapability;
  late final SourceImagePreparationCapability _imagePreparationCapability;
  late final SourceFavoritesCapability _favoritesCapability;
  late final SourceContentOperations _contentOperations =
      SourceContentOperationService(
        runtimeHost: _runtimeHost,
        runtimeOperations: _runtimeOperations,
        explore: _exploreCapability,
        category: _categoryCapability,
        comicDetails: _comicDetailsCapability,
      );
  late final SourceFavoritesOperations _favoritesOperations =
      SourceFavoritesOperationService(
        favorites: _favoritesCapability,
        debug: _favoritesDebugCapability,
        changedStream: _cloudFavoritesChangedController.stream,
      );
  late final SourceGatewaySet gateways = SourceGatewaySet(
    runtime: _runtimeView,
    runtimeOperations: _runtimeOperations,
    localization: _localizationOperations,
    settings: _settingsOperations,
    account: _accountOperations,
    comments: _commentsOperations,
    content: _contentOperations,
    favorites: _favoritesOperations,
    image: _imageOperations,
    imagePreparation: _imagePreparationCapability,
    debug: _debugOperations,
  );
  late final SourceScriptStorage _scriptStorage = SourceScriptStorage(
    defaultSourceKey: hazukiDefaultSourceKey,
    normalizeSourceKey: _normalizeAllowedSourceKey,
    ensurePreferences: (sourceKey) =>
        _handleFor(sourceKey).facade.ensurePrefs(),
  );
  late final SourceJsBridgeCookieCapability _jsBridgeCookieCapability =
      SourceJsBridgeCookieCapability(activeHandle: () => _activeHandle);
  final SourceRuntimeStateController _runtimeStateController =
      SourceRuntimeStateController();

  SourceRuntimeRegistry get runtimeRegistry => _runtimeHost.runtimeRegistry;

  @visibleForTesting
  late final SourceRuntimeTestAccess testing = SourceRuntimeTestAccess(
    runtime: _runtimeView,
    runtimeOperations: _runtimeOperations,
    content: _contentOperations,
    comments: _commentsOperations,
    favorites: _favoritesOperations,
    image: _imageOperations,
    settings: _settingsOperations,
    account: _accountOperations,
    debug: _debugOperations,
    activeFacade: () => _facade,
    handleFor: _handleFor,
    notifyRuntimeView: () =>
        _runtimeHost.notifyActiveRuntimeChanged(_runtimeHost.activeSourceKey),
    resolveActiveSourceKey: _resolveActiveSourceKey,
    handleJsMessage: _handleJsMessage,
    saveCookiesFromHeaders: _saveCookiesFromHeaders,
  );

  final StreamController<void> _cloudFavoritesChangedController =
      StreamController<void>.broadcast();
  void _notifyCloudFavoritesChanged() {
    _cloudFavoritesChangedController.add(null);
  }

  SourceRuntimeHandle get _activeHandle => _runtimeHost.activeHandle;

  SourceRuntimeHandle _handleFor(String sourceKey) {
    return _runtimeHost.handleFor(sourceKey);
  }

  HazukiSourceFacade get _facade => _activeHandle.facade;

  dynamic _handleJsMessage(SourceRuntimeHandle handle, dynamic message) {
    return _jsBridgeCookieCapability.handleJsMessageForHandle(handle, message);
  }

  Future<void> _saveCookiesFromHeaders(
    SourceRuntimeHandleView handle,
    String url,
    Map<String, List<String>> headers,
  ) => _jsBridgeCookieCapability.saveCookiesFromHeadersForHandle(
    handle,
    url,
    headers,
  );

  ImageCacheCapability _imageCacheForSourceRequest(String sourceKey) {
    final requested = sourceKey.trim();
    if (requested.isEmpty) {
      return _activeHandle.imageCache;
    }
    return _handleFor(requested).imageCache;
  }

  String _normalizeAllowedSourceKey(String sourceKey) {
    return _runtimeHost.normalize(sourceKey);
  }

  String _resolveActiveSourceKey([String? requestedSourceKey]) {
    final requested = requestedSourceKey?.trim() ?? '';
    return requested.isNotEmpty
        ? _normalizeAllowedSourceKey(requested)
        : _runtimeView.activeSourceKey;
  }

  ComicDetailsData? _getComicDetailsFromMemoryCache(
    String comicId, {
    String sourceKey = '',
  }) => _comicDetailsCache.get(comicId, sourceKey: sourceKey);

  Future<bool> _ensureFavoriteSessionReady({
    HazukiSourceFacade? targetFacade,
  }) => _reloginCoordinator.ensureFavoriteSessionReady(
    SourceFacadeReloginContext(targetFacade ?? _facade),
  );

  List<ExploreComic> _parseExploreComics(List list, {String sourceKey = ''}) {
    final resolvedSourceKey = sourceKey.trim().isEmpty
        ? _runtimeView.activeSourceKey
        : sourceKey.trim();
    final comics = <ExploreComic>[];
    for (final comic in list) {
      if (comic is! Map) {
        continue;
      }
      final comicMap = Map<String, dynamic>.from(comic);
      comics.add(
        ExploreComic(
          id: comicMap['id']?.toString() ?? '',
          title: comicMap['title']?.toString() ?? '',
          subTitle: (comicMap['subTitle'] ?? comicMap['subtitle'] ?? '')
              .toString(),
          cover: comicMap['cover']?.toString() ?? '',
          sourceKey: resolvedSourceKey,
          tags: jsAsStringList(comicMap['tags']),
        ),
      );
    }
    return comics;
  }

  void dispose() {
    _runtimeHost.dispose();
    unawaited(_cloudFavoritesChangedController.close());
  }
}

/// Narrow runtime internals available only to low-level runtime tests.
@visibleForTesting
class SourceRuntimeTestAccess {
  SourceRuntimeTestAccess({
    required this.runtime,
    required this.runtimeOperations,
    required this.content,
    required this.comments,
    required this.favorites,
    required this.image,
    required this.settings,
    required this.account,
    required this.debug,
    required HazukiSourceFacade Function() activeFacade,
    required SourceRuntimeHandle Function(String) handleFor,
    required void Function() notifyRuntimeView,
    required String Function([String?]) resolveActiveSourceKey,
    required dynamic Function(SourceRuntimeHandle, dynamic) handleJsMessage,
    required Future<void> Function(
      SourceRuntimeHandleView,
      String,
      Map<String, List<String>>,
    )
    saveCookiesFromHeaders,
  }) : _activeFacade = activeFacade,
       _handleFor = handleFor,
       _notifyRuntimeView = notifyRuntimeView,
       _resolveActiveSourceKey = resolveActiveSourceKey,
       _handleJsMessage = handleJsMessage,
       _saveCookiesFromHeaders = saveCookiesFromHeaders;

  final SourceRuntimeView runtime;
  final SourceRuntimeOperations runtimeOperations;
  final SourceContentOperations content;
  final SourceCommentsOperations comments;
  final SourceFavoritesOperations favorites;
  final SourceImageOperations image;
  final SourceSettingsOperations settings;
  final SourceAccountOperations account;
  final SourceDebugOperations debug;
  final HazukiSourceFacade Function() _activeFacade;
  final SourceRuntimeHandle Function(String) _handleFor;
  final void Function() _notifyRuntimeView;
  final String Function([String?]) _resolveActiveSourceKey;
  final dynamic Function(SourceRuntimeHandle, dynamic) _handleJsMessage;
  final Future<void> Function(
    SourceRuntimeHandleView,
    String,
    Map<String, List<String>>,
  )
  _saveCookiesFromHeaders;

  HazukiSourceFacade get facade => _activeFacade();
  SourceRuntimeHandle handleFor(String sourceKey) => _handleFor(sourceKey);
  void notifyRuntimeView() => _notifyRuntimeView();
  String resolveActiveSourceKey([String? sourceKey]) =>
      _resolveActiveSourceKey(sourceKey);
  dynamic handleJsMessage(SourceRuntimeHandle handle, dynamic message) =>
      _handleJsMessage(handle, message);
  Future<void> saveCookiesFromHeaders(
    SourceRuntimeHandleView handle,
    String url,
    Map<String, List<String>> headers,
  ) => _saveCookiesFromHeaders(handle, url, headers);
}
