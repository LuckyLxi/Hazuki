import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';

import 'favorite_app_bar_actions_state.dart';
import 'favorite_page_state.dart';
import '../support/favorite_cloud_flow.dart';
import '../support/favorite_local_flow.dart';

class FavoritePageController extends ChangeNotifier {
  FavoritePageController({
    HazukiSourceService? sourceService,
    LocalFavoritesService? localFavoritesService,
  }) : _sourceService = sourceService ?? HazukiSourceService.instance,
       _localFavoritesService =
           localFavoritesService ?? LocalFavoritesService.instance,
       _cloudFlow = FavoriteCloudFlow(
         sourceService ?? HazukiSourceService.instance,
       ),
       _localFlow = FavoriteLocalFlow(
         localFavoritesService ?? LocalFavoritesService.instance,
       ) {
    _localFavoritesService.addListener(_handleLocalFavoritesChanged);
    _sourceService.addListener(_handleSourceServiceChanged);
  }

  static const favoriteLoadTimeout = Duration(seconds: 90);

  final HazukiSourceService _sourceService;
  final FavoriteCloudFlow _cloudFlow;
  final FavoriteLocalFlow _localFlow;
  final LocalFavoritesService _localFavoritesService;
  final FavoritePageState _state = FavoritePageState();

  bool _disposed = false;
  bool _syncingExternalLocalChange = false;
  bool _queuedExternalLocalChange = false;
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

  bool get supportsFolderDelete => _state.mode == FavoritePageMode.local
      ? true
      : _cloudFlow.supportsFolderDelete;

  bool get canDeleteSelectedFolder => _state.mode == FavoritePageMode.local
      ? selectedFolderId.isNotEmpty
      : selectedFolderId != '0';

  FavoriteAppBarActionsState get appBarActionsState =>
      _state.buildAppBarActionsState(
        isLogged: _cloudFlow.isLogged,
        supportFavoriteSortOrder: _cloudFlow.supportsSortOrder,
        supportFavoriteFolderAdd: _cloudFlow.supportsFolderAdd,
      );

  void resetForReload() {
    if (_state.mode == FavoritePageMode.local) {
      return;
    }
    _state.resetForReload();
    _notify();
  }

  void resetLoggedOut() {
    if (_state.mode == FavoritePageMode.local) {
      return;
    }
    _state.resetLoggedOut();
    _notify();
  }

  Future<void> loadInitial({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    if (_state.isFirstLoad) {
      _state.isFirstLoad = false;
      final savedMode = await _localFlow.loadFavoritePageMode();
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

    try {
      await _cloudFlow.ensureInitialized();
    } catch (e) {
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

    final requestVersion = ++_state.listRequestVersion;
    final targetFolderId = _state.selectedCloudFolderId;

    await reloadFolders(onError: onFolderLoadError);

    final result = await _cloudFlow.loadPage(
      page: 1,
      folderId: targetFolderId,
      timeoutMessage: timeoutMessage,
      timeout: favoriteLoadTimeout,
    );
    if (_disposed || requestVersion != _state.listRequestVersion) {
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
    _state.setMode(
      _state.mode == FavoritePageMode.cloud
          ? FavoritePageMode.local
          : FavoritePageMode.cloud,
    );
    await _localFlow.saveFavoritePageMode(_state.mode);
    _state.resetForModeChange();
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

    if (!_cloudFlow.supportsFolderLoad) {
      _state.folders = const <FavoriteFolder>[defaultCloudFavoriteFolder];
      _state.selectedCloudFolderId = '0';
      _notify();
      return;
    }

    _state.loadingFolders = true;
    _notify();

    final result = await _cloudFlow.loadFolders();
    if (_disposed) {
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
    }
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

    final requestVersion = _state.listRequestVersion;
    final targetFolderId = selectedFolderId;

    _state.loadingMore = true;
    _notify();

    try {
      final nextPage = _state.currentPage + 1;
      final result = _state.mode == FavoritePageMode.local
          ? await _localFlow.loadPage(
              page: nextPage,
              folderId: targetFolderId,
              sortOrder: _state.favoriteSortOrder,
            )
          : await _cloudFlow.loadPage(
              page: nextPage,
              folderId: targetFolderId,
              timeoutMessage: timeoutMessage,
              timeout: favoriteLoadTimeout,
            );
      if (_disposed || requestVersion != _state.listRequestVersion) {
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
      if (!_disposed && requestVersion == _state.listRequestVersion) {
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

    final requestVersion = ++_state.listRequestVersion;
    final targetFolderId = selectedFolderId;

    _state.refreshing = true;
    _state.loadingMore = false;
    _notify();

    try {
      await reloadFolders(onError: onFolderLoadError);
      if (_state.mode == FavoritePageMode.local && selectedFolderId.isEmpty) {
        _state.comics = const <ExploreComic>[];
        _state.errorMessage = null;
        _state.currentPage = 1;
        _state.hasMore = false;
        _notify();
        return;
      }
      final result = _state.mode == FavoritePageMode.local
          ? await _localFlow.loadPage(
              page: 1,
              folderId: targetFolderId,
              sortOrder: _state.favoriteSortOrder,
            )
          : await _cloudFlow.loadPage(
              page: 1,
              folderId: targetFolderId,
              timeoutMessage: timeoutMessage,
              timeout: favoriteLoadTimeout,
            );
      if (_disposed || requestVersion != _state.listRequestVersion) {
        return;
      }

      _state.applyFirstPageResult(result);
      _notify();
    } finally {
      if (!_disposed && requestVersion == _state.listRequestVersion) {
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

    final requestVersion = ++_state.listRequestVersion;
    _state.setSelectedFolderId(folderId);
    _state.initialLoading = true;
    _state.errorMessage = null;
    _state.comics = const <ExploreComic>[];
    _state.currentPage = 1;
    _state.hasMore = true;
    _state.loadingMore = false;
    _notify();

    final result = _state.mode == FavoritePageMode.local
        ? await _localFlow.loadPage(
            page: 1,
            folderId: folderId,
            sortOrder: _state.favoriteSortOrder,
          )
        : await _cloudFlow.loadPage(
            page: 1,
            folderId: folderId,
            timeoutMessage: timeoutMessage,
            timeout: favoriteLoadTimeout,
          );
    if (_disposed || requestVersion != _state.listRequestVersion) {
      return;
    }

    if (result.errorMessage == null) {
      _state.comics = result.comics;
      _state.currentPage = 1;
      if (result.maxPage != null) {
        _state.hasMore = _state.currentPage < result.maxPage!;
      } else {
        _state.hasMore = result.comics.isNotEmpty;
      }
    } else {
      _state.errorMessage = result.errorMessage;
    }
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
        await _localFlow.addFolder(name);
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
      await _localFlow.renameFolder(folderId: normalizedFolderId, name: name);
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
    final normalized = order == 'mp' ? 'mp' : 'mr';
    if (normalized == _state.favoriteSortOrder) {
      return null;
    }

    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.saveSortOrder(normalized);
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
        await _localFlow.deleteFolder(currentId);
        _state.selectedLocalFolderId = '';
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
    _localFavoritesService.removeListener(_handleLocalFavoritesChanged);
    _sourceService.removeListener(_handleSourceServiceChanged);
    super.dispose();
  }

  void _handleSourceServiceChanged() {
    _notify();
  }

  void _handleLocalFavoritesChanged() {
    if (_disposed || _state.mode != FavoritePageMode.local) {
      return;
    }
    if (_syncingExternalLocalChange) {
      _queuedExternalLocalChange = true;
      return;
    }
    unawaited(_syncLocalFavoritesAfterExternalChange());
  }

  Future<void> _loadInitialLocal() async {
    final requestVersion = ++_state.listRequestVersion;
    _state.favoriteSortOrder = await _localFlow.loadSortOrder();
    await _reloadLocalFolders();
    if (_state.selectedLocalFolderId.isEmpty) {
      if (_disposed || requestVersion != _state.listRequestVersion) {
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
    final result = await _localFlow.loadPage(
      page: 1,
      folderId: _state.selectedLocalFolderId,
      sortOrder: _state.favoriteSortOrder,
    );
    if (_disposed || requestVersion != _state.listRequestVersion) {
      return;
    }

    _state.applyFirstPageResult(result);
    _state.initialLoading = false;
    _notify();
  }

  Future<void> _syncLocalFavoritesAfterExternalChange() async {
    _syncingExternalLocalChange = true;
    try {
      do {
        _queuedExternalLocalChange = false;
        final requestVersion = ++_state.listRequestVersion;
        await _reloadLocalFolders();
        if (_disposed ||
            _state.mode != FavoritePageMode.local ||
            requestVersion != _state.listRequestVersion) {
          continue;
        }

        final targetFolderId = _state.selectedLocalFolderId;
        if (targetFolderId.isEmpty) {
          _state.comics = const <ExploreComic>[];
          _state.errorMessage = null;
          _state.currentPage = 1;
          _state.hasMore = false;
          _notify();
          continue;
        }

        final result = await _localFlow.loadPage(
          page: 1,
          folderId: targetFolderId,
          sortOrder: _state.favoriteSortOrder,
        );
        if (_disposed ||
            _state.mode != FavoritePageMode.local ||
            requestVersion != _state.listRequestVersion) {
          continue;
        }

        _state.applyFirstPageResult(result);
        _notify();
      } while (_queuedExternalLocalChange && !_disposed);
    } finally {
      _syncingExternalLocalChange = false;
    }
  }

  Future<void> _reloadLocalFolders() async {
    _state.loadingFolders = true;
    _notify();

    final result = await _localFlow.loadFolders();
    if (_disposed) {
      return;
    }

    final folders = result.folders;
    final selectedExists = folders.any(
      (folder) => folder.id == _state.selectedLocalFolderId,
    );
    _state.folders = folders;
    if (!selectedExists) {
      _state.selectedLocalFolderId = folders.isEmpty ? '' : folders.first.id;
    }
    if (folders.isEmpty) {
      _state.comics = const <ExploreComic>[];
      _state.errorMessage = null;
      _state.currentPage = 1;
      _state.hasMore = false;
    }
    _state.loadingFolders = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
