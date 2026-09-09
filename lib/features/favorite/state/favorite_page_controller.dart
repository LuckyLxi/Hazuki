import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import '../support/favorite_comic_tag_loader.dart';
import '../support/favorite_source_policy.dart';
import '../support/favorite_list_loader.dart';
import '../support/favorite_selection_store.dart';
import '../support/favorite_change_coordinator.dart';

import 'favorite_app_bar_actions_state.dart';
import 'favorite_page_state.dart';
import '../support/favorite_cloud_flow.dart';
import '../support/favorite_local_flow.dart';

class FavoritePageController extends ChangeNotifier {
  FavoritePageController({
    required SourceFavoriteGateway sourceService,
    SourceReaderGateway? readerService,
    required LocalFavoritesRepository localFavoritesRepository,
    required LocalFavoritesPreferencesStore localFavoritesPreferences,
  }) : _sourceService = sourceService,
       _tagLoader = FavoriteComicTagLoader(readerService),
       _selectionStore = FavoriteSelectionStore(localFavoritesPreferences),
       _localFavoritesRepository = localFavoritesRepository,
       _cloudFlow = FavoriteCloudFlow(sourceService),
       _localFlow = FavoriteLocalFlow(
         repository: localFavoritesRepository,
         preferences: localFavoritesPreferences,
       ) {
    _lastActiveSourceKey = _activeSourceKey;
    _listLoader = FavoriteListLoader(cloud: _cloudFlow, local: _localFlow);
    _changes = FavoriteChangeCoordinator(
      localChanges: _localFavoritesRepository,
      cloudChanges: _sourceService.cloudFavoritesChangedStream,
      shouldRefreshLocal: () => _state.mode == FavoritePageMode.local,
      shouldRefreshCloud: () =>
          _state.mode == FavoritePageMode.cloud &&
          _sourcePolicy.refreshOnCloudFavoritesChanged(_activeSourceKey),
      refreshLocal: _syncLocalFavoritesAfterExternalChange,
      refreshCloud: _syncCloudFavoritesAfterExternalChange,
    );
    _sourceService.addListener(_handleSourceServiceChanged);
  }

  static const favoriteLoadTimeout = FavoriteListLoader.timeout;

  final SourceFavoriteGateway _sourceService;
  final FavoriteComicTagLoader _tagLoader;
  final FavoriteSourcePolicy _sourcePolicy = const FavoriteSourcePolicy();
  final FavoriteCloudFlow _cloudFlow;
  final FavoriteLocalFlow _localFlow;
  final LocalFavoritesRepository _localFavoritesRepository;
  final FavoritePageData _state = FavoritePageData();

  bool _disposed = false;
  late final FavoriteListLoader _listLoader;
  late final FavoriteChangeCoordinator _changes;
  final FavoriteSelectionStore _selectionStore;
  int _folderRequestVersion = 0;

  FavoriteListRequest _captureFolderRequest() => FavoriteListRequest(
    generation: ++_folderRequestVersion,
    sourceKey: _activeSourceKey,
    mode: _state.mode,
  );

  bool _isCurrentFolderRequest(FavoriteListRequest request) =>
      !_disposed &&
      request.generation == _folderRequestVersion &&
      request.sourceKey == _activeSourceKey &&
      request.mode == _state.mode;

  void _invalidateRequests() {
    _listLoader.invalidate();
    _folderRequestVersion++;
    _state.loadingFolders = false;
  }

  FavoriteListRequest _captureRequest({bool replace = false}) =>
      _listLoader.capture(
        sourceKey: _activeSourceKey,
        mode: _state.mode,
        replace: replace,
      );

  bool _isCurrent(FavoriteListRequest request) => _listLoader.isCurrent(
    request,
    sourceKey: _activeSourceKey,
    mode: _state.mode,
  );
  String _lastActiveSourceKey = '';
  List<ExploreComic> get comics => _state.comics;
  List<FavoriteFolder> get folders => _state.folders;
  String get selectedFolderId => _state.selectedFolderId;
  String? get errorMessage => _state.errorMessage;
  bool get initialLoading => _state.initialLoading;
  bool get refreshing => _state.refreshing;
  bool get loadingMore => _state.loadingMore;
  bool get hasMore => _state.hasMore;
  bool get loadingFolders => _state.loadingFolders;
  FavoritePageMode get mode => _state.mode;
  bool get isLogged => _cloudFlow.isLogged;
  SourceRuntimeState get sourceRuntimeState =>
      _sourceService.sourceRuntimeState;

  void retrySourceRuntime() {
    if (_sourceService.sourceRuntimeState.canRetry) {
      _sourceService.logRuntimeRetryRequested('favorite_page');
    }
  }

  bool get showLoginRequired =>
      _state.mode == FavoritePageMode.cloud && !_cloudFlow.isLogged;

  bool get supportsFolderLoad => true;
  String get _activeSourceKey => _sourceService.activeSourceKey;

  bool get supportsFolderDelete => _state.mode == FavoritePageMode.local
      ? true
      : _cloudFlow.supportsFolderDelete;

  bool get canDeleteSelectedFolder => _state.mode == FavoritePageMode.local
      ? selectedFolderId.isNotEmpty
      : selectedFolderId != '0';

  List<String> get _favoriteSortOrders => _sourceService.favoriteSortOrders;

  FavoriteAppBarActionsState get appBarActionsState =>
      _state.buildAppBarActionsState(
        isLogged: _cloudFlow.isLogged,
        supportFavoriteSortOrder: _cloudFlow.supportsSortOrder,
        supportFavoriteFolderAdd: _cloudFlow.supportsFolderAdd,
        favoriteSortOrders: _favoriteSortOrders,
      );

  void resetForReload() {
    if (_state.mode == FavoritePageMode.local) {
      return;
    }
    _invalidateRequests();
    _state.resetForReload();
    _notify();
  }

  void resetLoggedOut() {
    if (_state.mode == FavoritePageMode.local) {
      return;
    }
    _invalidateRequests();
    _state.resetLoggedOut();
    _notify();
  }

  Future<void> loadInitial({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    if (_state.isFirstLoad) {
      _state.isFirstLoad = false;
      final request = _captureRequest();
      final selection = await _selectionStore.load(request.sourceKey);
      if (!_isCurrent(request)) return;
      final savedMode = selection.mode;
      _state.selectedCloudFolderId = selection.cloudFolderId;
      _state.selectedLocalFolderId = selection.localFolderId;
      if (savedMode != _state.mode) {
        _state.setMode(savedMode);
        _state.folders = _state.mode == FavoritePageMode.local
            ? const <FavoriteFolder>[]
            : const <FavoriteFolder>[defaultCloudFavoriteFolder];
        _notify();
      }
    }

    if (_state.mode == FavoritePageMode.local) {
      await _loadInitialLocal();
      return;
    }

    final requestVersion = _captureRequest(replace: true);
    try {
      await _cloudFlow.ensureInitialized();
      if (!_isCurrent(requestVersion)) return;
    } catch (e) {
      if (!_isCurrent(requestVersion)) return;
      _state.initialLoading = false;
      _state.errorMessage = e.toString();
      _notify();
      return;
    }

    if (_cloudFlow.supportsSortOrder) {
      _state.favoriteSortOrder = _cloudFlow.currentSortOrder;
      _notify();
    }

    if (!_cloudFlow.isLogged) {
      _state.initialLoading = false;
      _notify();
      return;
    }

    await reloadFolders(onError: onFolderLoadError);
    if (!_isCurrent(requestVersion)) return;

    final result = await _listLoader.load(
      request: requestVersion,
      sortOrder: _state.favoriteSortOrder,
      page: 1,
      folderId: _state.selectedCloudFolderId,
      timeoutMessage: timeoutMessage,
    );
    if (!_isCurrent(requestVersion)) {
      return;
    }

    _state.applyFirstPageResult(result);
    _state.initialLoading = false;
    _notify();
  }

  Future<void> toggleMode({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    final nextMode = _state.mode == FavoritePageMode.cloud
        ? FavoritePageMode.local
        : FavoritePageMode.cloud;
    _invalidateRequests();
    _state.setMode(nextMode);
    final request = _captureRequest();
    await _selectionStore.saveMode(nextMode, request.sourceKey);
    if (!_isCurrent(request)) return;
    _state.resetForModeChange();
    if (nextMode == FavoritePageMode.local) {
      await _loadInitialLocal(notifyIntermediate: false);
      return;
    }
    _notify();

    await loadInitial(
      timeoutMessage: timeoutMessage,
      onFolderLoadError: onFolderLoadError,
    );
  }

  Future<void> reloadFolders({ValueChanged<String>? onError}) async {
    if (_state.mode == FavoritePageMode.local) {
      await _reloadLocalFolders();
      return;
    }

    final request = _captureFolderRequest();
    if (!_cloudFlow.supportsFolderLoad) {
      _state.folders = const <FavoriteFolder>[defaultCloudFavoriteFolder];
      _state.selectedCloudFolderId = '0';
      await _saveSelectedFolderId(FavoritePageMode.cloud, '0');
      if (!_isCurrentFolderRequest(request)) return;
      _state.loadingFolders = false;
      _notify();
      return;
    }

    _state.loadingFolders = true;
    _notify();

    final result = await _cloudFlow.loadFolders();
    if (!_isCurrentFolderRequest(request)) {
      return;
    }

    if (result.errorMessage != null) {
      _state.loadingFolders = false;
      _notify();
      onError?.call(result.errorMessage!);
      return;
    }

    final folders = _cloudFlow.normalizeFolders(result);
    final selectedExists = folders.any(
      (folder) => folder.id == _state.selectedCloudFolderId,
    );

    _state.folders = folders;
    if (!selectedExists) {
      _state.selectedCloudFolderId = folders.first.id;
      await _saveSelectedFolderId(
        FavoritePageMode.cloud,
        _state.selectedCloudFolderId,
      );
    }
    if (!_isCurrentFolderRequest(request)) return;
    _state.loadingFolders = false;
    _notify();
  }

  Future<String?> loadMore({required String timeoutMessage}) async {
    if (_state.initialLoading ||
        _state.refreshing ||
        _state.loadingMore ||
        !_state.hasMore) {
      return null;
    }
    if (_state.mode == FavoritePageMode.cloud && !_cloudFlow.isLogged) {
      return null;
    }

    final requestVersion = _captureRequest();
    final targetFolderId = selectedFolderId;

    _state.loadingMore = true;
    _notify();

    try {
      final nextPage = _state.currentPage + 1;
      final result = await _loadPage(
        page: nextPage,
        folderId: targetFolderId,
        timeoutMessage: timeoutMessage,
      );
      if (!_isCurrent(requestVersion)) {
        return null;
      }

      if (result.errorMessage != null) {
        _state.loadingMore = false;
        _notify();
        return result.errorMessage;
      }

      _state.applyNextPageResult(result, page: nextPage);
      _state.loadingMore = false;
      _notify();
      return null;
    } catch (_) {
      if (_isCurrent(requestVersion)) {
        _state.loadingMore = false;
        _notify();
      }
      return null;
    }
  }

  Future<void> refresh({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    if (_state.refreshing) {
      return;
    }
    if (_state.mode == FavoritePageMode.cloud && !_cloudFlow.isLogged) {
      return;
    }

    final requestVersion = _captureRequest(replace: true);

    _state.refreshing = true;
    _state.loadingMore = false;
    _notify();

    try {
      await reloadFolders(onError: onFolderLoadError);
      if (!_isCurrent(requestVersion)) return;
      if (_state.mode == FavoritePageMode.local && selectedFolderId.isEmpty) {
        _state.comics = const <ExploreComic>[];
        _state.errorMessage = null;
        _state.currentPage = 1;
        _state.hasMore = false;
        _notify();
        return;
      }
      final result = await _loadPage(
        page: 1,
        folderId: selectedFolderId,
        timeoutMessage: timeoutMessage,
      );
      if (!_isCurrent(requestVersion)) {
        return;
      }

      _state.applyFirstPageResult(result);
      _notify();
    } finally {
      if (_isCurrent(requestVersion)) {
        _state.refreshing = false;
        _notify();
      }
    }
  }

  Future<void> selectFolder(
    String folderId, {
    required String timeoutMessage,
  }) async {
    if (_state.mode == FavoritePageMode.local && folderId.trim().isEmpty) {
      return;
    }
    if (selectedFolderId == folderId ||
        _state.initialLoading ||
        _state.refreshing) {
      return;
    }

    final requestVersion = _captureRequest(replace: true);
    _state.setSelectedFolderId(folderId);
    await _saveSelectedFolderId(_state.mode, folderId);
    if (!_isCurrent(requestVersion)) return;
    _state.initialLoading = true;
    _state.errorMessage = null;
    _state.comics = const <ExploreComic>[];
    _state.currentPage = 1;
    _state.hasMore = true;
    _state.loadingMore = false;
    _notify();

    final result = await _loadPage(
      page: 1,
      folderId: folderId,
      timeoutMessage: timeoutMessage,
    );
    if (!_isCurrent(requestVersion)) {
      return;
    }

    _state.applyFirstPageResult(result);
    _state.initialLoading = false;
    _notify();
  }

  Future<String?> createFolder(
    String name, {
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.addFolder(name, sourceKey: _activeSourceKey);
        await _reloadLocalFolders();
      } else {
        await _cloudFlow.addFolder(name);
        await reloadFolders(onError: onFolderLoadError);
      }
      if (_disposed) {
        return null;
      }
      final created = _state.folders
          .where((folder) => folder.name == name)
          .toList();
      if (created.isNotEmpty) {
        await selectFolder(created.first.id, timeoutMessage: timeoutMessage);
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> renameLocalFolder(String folderId, String name) async {
    if (_state.mode != FavoritePageMode.local) {
      return null;
    }

    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return null;
    }

    try {
      await _localFlow.renameFolder(
        folderId: normalizedFolderId,
        name: name,
        sourceKey: _activeSourceKey,
      );
      if (_disposed) {
        return null;
      }
      await _reloadLocalFolders();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> changeSortOrder(
    String order, {
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    final allowedOrders = _state.mode == FavoritePageMode.local
        ? _favoriteSortOrders
        : _cloudFlow.sortOrders;
    final normalized = _sourcePolicy.normalizeSortOrder(
      order,
      allowedOrders: allowedOrders,
    );
    if (normalized == _state.favoriteSortOrder) {
      return null;
    }

    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.saveSortOrder(normalized);
        if (_disposed) {
          return null;
        }
        _state.favoriteSortOrder = normalized;
        return await _reloadLocalComicsAfterSort();
      } else {
        await _cloudFlow.setSortOrder(normalized);
      }
      if (_disposed) {
        return null;
      }
      _state.favoriteSortOrder = normalized;
      resetForReload();
      await loadInitial(
        timeoutMessage: timeoutMessage,
        onFolderLoadError: onFolderLoadError,
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> _reloadLocalComicsAfterSort() async {
    final requestVersion = _captureRequest(replace: true);
    final targetFolderId = _state.selectedLocalFolderId;

    _state.refreshing = true;
    _state.loadingMore = false;
    _state.errorMessage = null;
    _notify();

    if (targetFolderId.isEmpty) {
      if (_isCurrent(requestVersion)) {
        _state.comics = const <ExploreComic>[];
        _state.currentPage = 1;
        _state.hasMore = false;
        _state.refreshing = false;
        _notify();
      }
      return null;
    }

    final result = await _listLoader.load(
      request: requestVersion,
      timeoutMessage: '',
      page: 1,
      folderId: targetFolderId,
      sortOrder: _state.favoriteSortOrder,
    );
    if (!_isCurrent(requestVersion)) {
      return null;
    }

    _state.applyFirstPageResult(result);
    _state.refreshing = false;
    _notify();
    return result.errorMessage;
  }

  Future<String?> deleteCurrentFolder({required String timeoutMessage}) async {
    final currentId = selectedFolderId;
    if (_state.mode == FavoritePageMode.local && currentId.isEmpty) {
      return null;
    }
    if (_state.mode == FavoritePageMode.cloud && currentId == '0') {
      return null;
    }

    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.deleteFolder(currentId, sourceKey: _activeSourceKey);
        _state.selectedLocalFolderId = '';
        await _saveSelectedFolderId(FavoritePageMode.local, '');
        await _reloadLocalFolders();
      } else {
        await _cloudFlow.deleteFolder(currentId);
        final updatedFolders = _state.folders
            .where((folder) => folder.id != currentId)
            .toList();
        _state.folders = updatedFolders.isEmpty
            ? const [defaultCloudFavoriteFolder]
            : updatedFolders;
        _state.selectedCloudFolderId = '0';
        await _saveSelectedFolderId(FavoritePageMode.cloud, '0');
        _notify();
        unawaited(reloadFolders());
      }

      await selectFolder(
        _state.mode == FavoritePageMode.local
            ? _state.selectedLocalFolderId
            : '0',
        timeoutMessage: timeoutMessage,
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _listLoader.dispose();
    _changes.dispose();
    _sourceService.removeListener(_handleSourceServiceChanged);
    super.dispose();
  }

  void _handleSourceServiceChanged() {
    final activeSourceKey = _activeSourceKey;
    if (activeSourceKey == _lastActiveSourceKey) {
      _notify();
      return;
    }
    _lastActiveSourceKey = activeSourceKey;
    _invalidateRequests();
    _state.favoriteSortOrder = _sourcePolicy.normalizeSortOrder(
      _state.favoriteSortOrder,
      allowedOrders: _favoriteSortOrders,
    );
    unawaited(_restoreModeForActiveSource());
  }

  Future<void> _restoreModeForActiveSource() async {
    final request = _captureRequest();
    final selection = await _selectionStore.load(request.sourceKey);
    if (!_isCurrent(request)) return;
    _state.selectedCloudFolderId = selection.cloudFolderId;
    _state.selectedLocalFolderId = selection.localFolderId;
    _state.setMode(selection.mode);
    if (_state.mode == FavoritePageMode.local) {
      _state.resetForModeChange();
      _notify();
      unawaited(_loadInitialLocal());
      return;
    }
    _invalidateRequests();
    _state.resetForReload();
    _notify();
    unawaited(_backgroundRefreshCloud());
  }

  Future<FavoriteComicsResult> _loadPage({
    required int page,
    required String folderId,
    required String timeoutMessage,
  }) async {
    final request = _captureRequest();
    final result = await _listLoader.load(
      request: request,
      page: page,
      folderId: folderId,
      sortOrder: _state.favoriteSortOrder,
      timeoutMessage: timeoutMessage,
    );
    if (_isCurrent(request)) unawaited(_backfillComicTags(result, request));
    return result;
  }

  Future<void> _backfillComicTags(
    FavoriteComicsResult result,
    FavoriteListRequest request,
  ) async {
    final tagsByComic = await _tagLoader.load(
      result,
      onTagsLoaded: (comic, tags) {
        if (_isCurrent(request) && request.mode == FavoritePageMode.local) {
          unawaited(
            _localFavoritesRepository.updateComicTags(
              comicId: comic.id,
              sourceKey: comic.sourceKey,
              tags: tags,
            ),
          );
        }
      },
    );
    if (!_isCurrent(request) || tagsByComic.isEmpty) return;
    var changed = false;
    _state.comics = _state.comics
        .map((comic) {
          final tags = tagsByComic[comic.scopedId.storageKey];
          if (tags == null || comic.tags.isNotEmpty) return comic;
          changed = true;
          return comic.copyWith(tags: tags);
        })
        .toList(growable: false);
    if (changed) _notify();
  }

  Future<void> _loadInitialLocal({bool notifyIntermediate = true}) async {
    final requestVersion = _captureRequest(replace: true);
    final sortOrder = await _localFlow.loadSortOrder();
    if (!_isCurrent(requestVersion)) return;
    _state.favoriteSortOrder = _sourcePolicy.normalizeSortOrder(
      sortOrder,
      allowedOrders: _favoriteSortOrders,
    );
    await _reloadLocalFolders(notifyChanges: notifyIntermediate);
    if (!_isCurrent(requestVersion)) return;
    if (_state.selectedLocalFolderId.isEmpty) {
      if (!_isCurrent(requestVersion)) {
        return;
      }
      _state.comics = const <ExploreComic>[];
      _state.errorMessage = null;
      _state.currentPage = 1;
      _state.hasMore = false;
      _state.initialLoading = false;
      _notify();
      return;
    }
    final result = await _loadPage(
      page: 1,
      folderId: _state.selectedLocalFolderId,
      timeoutMessage: '',
    );
    if (!_isCurrent(requestVersion)) {
      return;
    }

    _state.applyFirstPageResult(result);
    _state.initialLoading = false;
    _notify();
  }

  /// 切换源后后台静默刷新云端收藏，不向用户展示任何加载提示或错误
  Future<void> _backgroundRefreshCloud() async {
    if (_disposed || _state.mode != FavoritePageMode.cloud) {
      return;
    }
    // 必须用 loadInitial 而非 refresh：resetForReload 将 initialLoading 置为 true，
    // 只有 loadInitial 会在完成后将其重置为 false，refresh 不处理 initialLoading
    await loadInitial(timeoutMessage: '');
  }

  Future<void> _syncLocalFavoritesAfterExternalChange() async {
    final requestVersion = _captureRequest(replace: true);
    await _reloadLocalFolders();
    if (_disposed ||
        _state.mode != FavoritePageMode.local ||
        !_isCurrent(requestVersion)) {
      return;
    }

    final targetFolderId = _state.selectedLocalFolderId;
    if (targetFolderId.isEmpty) {
      _state.comics = const <ExploreComic>[];
      _state.errorMessage = null;
      _state.currentPage = 1;
      _state.hasMore = false;
      _notify();
      return;
    }

    final result = await _listLoader.load(
      request: requestVersion,
      timeoutMessage: '',
      page: 1,
      folderId: targetFolderId,
      sortOrder: _state.favoriteSortOrder,
    );
    if (_disposed ||
        _state.mode != FavoritePageMode.local ||
        !_isCurrent(requestVersion)) {
      return;
    }

    _state.applyFirstPageResult(result);
    _notify();
  }

  Future<void> _syncCloudFavoritesAfterExternalChange() async {
    if (_disposed ||
        _state.mode != FavoritePageMode.cloud ||
        !_cloudFlow.isLogged) {
      return;
    }

    final requestVersion = _captureRequest(replace: true);
    _state.refreshing = true;
    _notify();

    try {
      final result = await _listLoader.load(
        request: requestVersion,
        sortOrder: _state.favoriteSortOrder,
        page: 1,
        folderId: selectedFolderId,
        timeoutMessage: 'Timeout',
      );
      if (_disposed ||
          _state.mode != FavoritePageMode.cloud ||
          !_isCurrent(requestVersion)) {
        return;
      }
      _state.applyFirstPageResult(result);
      _notify();
    } catch (_) {
      // Ignore background errors
    } finally {
      if (_isCurrent(requestVersion)) {
        _state.refreshing = false;
        _notify();
      }
    }
  }

  Future<void> _reloadLocalFolders({bool notifyChanges = true}) async {
    final request = _captureFolderRequest();
    _state.loadingFolders = true;
    if (notifyChanges) {
      _notify();
    }

    final result = await _localFlow.loadFoldersForSource(request.sourceKey);
    if (!_isCurrentFolderRequest(request)) {
      return;
    }

    final folders = result.folders;
    final selectedExists = folders.any(
      (folder) => folder.id == _state.selectedLocalFolderId,
    );
    _state.folders = folders;
    if (!selectedExists) {
      _state.selectedLocalFolderId = folders.isEmpty ? '' : folders.first.id;
      await _saveSelectedFolderId(
        FavoritePageMode.local,
        _state.selectedLocalFolderId,
      );
    }
    if (!_isCurrentFolderRequest(request)) return;
    if (folders.isEmpty) {
      _state.comics = const <ExploreComic>[];
      _state.errorMessage = null;
      _state.currentPage = 1;
      _state.hasMore = false;
    }
    _state.loadingFolders = false;
    if (notifyChanges) {
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _saveSelectedFolderId(
    FavoritePageMode mode,
    String folderId,
  ) async {
    await _selectionStore.saveFolder(mode, folderId, _activeSourceKey);
  }
}
