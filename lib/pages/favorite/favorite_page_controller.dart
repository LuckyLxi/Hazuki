import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import '../../services/local_favorites_service.dart';
import 'favorite_app_bar_actions_state.dart';

const defaultCloudFavoriteFolder = FavoriteFolder(
  id: '0',
  name: '__favorite_all__',
  source: FavoriteFolderSource.cloud,
);

class FavoritePageController extends ChangeNotifier {
  FavoritePageController({
    HazukiSourceService? sourceService,
    LocalFavoritesService? localFavoritesService,
  }) : _sourceService = sourceService ?? HazukiSourceService.instance,
       _localFavoritesService =
           localFavoritesService ?? LocalFavoritesService.instance;

  static const favoriteLoadTimeout = Duration(seconds: 90);

  final HazukiSourceService _sourceService;
  final LocalFavoritesService _localFavoritesService;

  bool _disposed = false;
  bool _isFirstLoad = true;
  FavoritePageMode _mode = FavoritePageMode.cloud;
  List<ExploreComic> _comics = const [];
  List<FavoriteFolder> _folders = const [defaultCloudFavoriteFolder];
  String _selectedCloudFolderId = '0';
  String _selectedLocalFolderId = '';
  String? _errorMessage;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadingFolders = false;
  int _currentPage = 1;
  int _listRequestVersion = 0;
  String _favoriteSortOrder = 'mr';

  List<ExploreComic> get comics => _comics;
  List<FavoriteFolder> get folders => _folders;
  String get selectedFolderId => _mode == FavoritePageMode.local
      ? _selectedLocalFolderId
      : _selectedCloudFolderId;
  String? get errorMessage => _errorMessage;
  bool get initialLoading => _initialLoading;
  bool get refreshing => _refreshing;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get loadingFolders => _loadingFolders;
  FavoritePageMode get mode => _mode;
  bool get isLogged => _sourceService.isLogged;
  bool get showLoginRequired =>
      _mode == FavoritePageMode.cloud && !_sourceService.isLogged;

  bool get supportsFolderLoad => true;

  bool get supportsFolderDelete => _mode == FavoritePageMode.local
      ? true
      : _sourceService.supportFavoriteFolderDelete;

  bool get canDeleteSelectedFolder => _mode == FavoritePageMode.local
      ? selectedFolderId.isNotEmpty
      : selectedFolderId != '0';

  FavoriteAppBarActionsState get appBarActionsState {
    if (_mode == FavoritePageMode.local) {
      return FavoriteAppBarActionsState(
        showSort: true,
        showCreateFolder: true,
        currentSortOrder: _favoriteSortOrder,
        showModeToggle: true,
        currentMode: _mode,
      );
    }

    final canOperate = _sourceService.isLogged;
    return FavoriteAppBarActionsState(
      showSort: canOperate && _sourceService.supportFavoriteSortOrder,
      showCreateFolder: canOperate && _sourceService.supportFavoriteFolderAdd,
      currentSortOrder: _favoriteSortOrder,
      showModeToggle: true,
      currentMode: _mode,
    );
  }

  void resetForReload() {
    if (_mode == FavoritePageMode.local) {
      return;
    }
    _initialLoading = true;
    _refreshing = false;
    _loadingMore = false;
    _errorMessage = null;
    _comics = const [];
    _currentPage = 1;
    _hasMore = true;
    _notify();
  }

  void resetLoggedOut() {
    if (_mode == FavoritePageMode.local) {
      return;
    }
    _comics = const [];
    _folders = const [defaultCloudFavoriteFolder];
    _selectedCloudFolderId = '0';
    _errorMessage = null;
    _initialLoading = false;
    _refreshing = false;
    _loadingMore = false;
    _hasMore = true;
    _currentPage = 1;
    _loadingFolders = false;
    _favoriteSortOrder = 'mr';
    _notify();
  }

  Future<void> loadInitial({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    if (_isFirstLoad) {
      _isFirstLoad = false;
      final savedMode = await _localFavoritesService.loadFavoritePageMode();
      if (savedMode != _mode) {
        _mode = savedMode;
        _folders = _mode == FavoritePageMode.local
            ? const <FavoriteFolder>[]
            : const <FavoriteFolder>[defaultCloudFavoriteFolder];
        _notify();
      }
    }

    if (_mode == FavoritePageMode.local) {
      await _loadInitialLocal();
      return;
    }

    try {
      await _sourceService.ensureInitialized();
    } catch (e) {
      _initialLoading = false;
      _errorMessage = e.toString();
      _notify();
      return;
    }

    if (_sourceService.supportFavoriteSortOrder) {
      _favoriteSortOrder = _sourceService.favoriteSortOrder;
      _notify();
    }

    if (!_sourceService.isLogged) {
      _initialLoading = false;
      _notify();
      return;
    }

    final requestVersion = ++_listRequestVersion;
    final targetFolderId = _selectedCloudFolderId;

    await reloadFolders(onError: onFolderLoadError);

    final result = await _loadCloudFavoritesPage(
      page: 1,
      folderId: targetFolderId,
      timeoutMessage: timeoutMessage,
    );
    if (_disposed || requestVersion != _listRequestVersion) {
      return;
    }

    _applyFirstPageResult(result);
    _initialLoading = false;
    _notify();
  }

  Future<void> toggleMode({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    _mode = _mode == FavoritePageMode.cloud
        ? FavoritePageMode.local
        : FavoritePageMode.cloud;
    unawaited(_localFavoritesService.saveFavoritePageMode(_mode));
    _comics = const [];
    _folders = _mode == FavoritePageMode.local
        ? const <FavoriteFolder>[]
        : const <FavoriteFolder>[defaultCloudFavoriteFolder];
    _errorMessage = null;
    _initialLoading = true;
    _refreshing = false;
    _loadingMore = false;
    _loadingFolders = false;
    _hasMore = true;
    _currentPage = 1;
    _notify();

    await loadInitial(
      timeoutMessage: timeoutMessage,
      onFolderLoadError: onFolderLoadError,
    );
  }

  Future<void> reloadFolders({ValueChanged<String>? onError}) async {
    if (_mode == FavoritePageMode.local) {
      await _reloadLocalFolders();
      return;
    }

    if (!_sourceService.supportFavoriteFolderLoad) {
      _folders = const [defaultCloudFavoriteFolder];
      _selectedCloudFolderId = '0';
      _notify();
      return;
    }

    _loadingFolders = true;
    _notify();

    final result = await _sourceService.loadFavoriteFolders();
    if (_disposed) {
      return;
    }

    if (result.errorMessage != null) {
      _loadingFolders = false;
      _notify();
      onError?.call(result.errorMessage!);
      return;
    }

    final folders = result.folders.isEmpty
        ? const [defaultCloudFavoriteFolder]
        : result.folders;
    final selectedExists = folders.any(
      (folder) => folder.id == _selectedCloudFolderId,
    );

    _folders = folders;
    if (!selectedExists) {
      _selectedCloudFolderId = folders.first.id;
    }
    _loadingFolders = false;
    _notify();
  }

  Future<String?> loadMore({required String timeoutMessage}) async {
    if (_initialLoading || _refreshing || _loadingMore || !_hasMore) {
      return null;
    }
    if (_mode == FavoritePageMode.cloud && !_sourceService.isLogged) {
      return null;
    }

    final requestVersion = _listRequestVersion;
    final targetFolderId = selectedFolderId;

    _loadingMore = true;
    _notify();

    try {
      final nextPage = _currentPage + 1;
      final result = _mode == FavoritePageMode.local
          ? await _loadLocalFavoritesPage(
              page: nextPage,
              folderId: targetFolderId,
            )
          : await _loadCloudFavoritesPage(
              page: nextPage,
              folderId: targetFolderId,
              timeoutMessage: timeoutMessage,
            );
      if (_disposed || requestVersion != _listRequestVersion) {
        return null;
      }

      if (result.errorMessage != null) {
        _loadingMore = false;
        _notify();
        return result.errorMessage;
      }

      final incoming = result.comics;
      _comics = _mergeComics(_comics, incoming);
      _currentPage = nextPage;
      if (result.maxPage != null) {
        _hasMore = _currentPage < result.maxPage!;
      } else {
        _hasMore = incoming.isNotEmpty;
      }
      _loadingMore = false;
      _notify();
      return null;
    } catch (_) {
      if (!_disposed && requestVersion == _listRequestVersion) {
        _loadingMore = false;
        _notify();
      }
      return null;
    }
  }

  Future<void> refresh({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    if (_refreshing) {
      return;
    }
    if (_mode == FavoritePageMode.cloud && !_sourceService.isLogged) {
      return;
    }

    final requestVersion = ++_listRequestVersion;
    final targetFolderId = selectedFolderId;

    _refreshing = true;
    _loadingMore = false;
    _notify();

    try {
      await reloadFolders(onError: onFolderLoadError);
      if (_mode == FavoritePageMode.local && selectedFolderId.isEmpty) {
        _comics = const [];
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = false;
        _notify();
        return;
      }
      final result = _mode == FavoritePageMode.local
          ? await _loadLocalFavoritesPage(page: 1, folderId: targetFolderId)
          : await _loadCloudFavoritesPage(
              page: 1,
              folderId: targetFolderId,
              timeoutMessage: timeoutMessage,
            );
      if (_disposed || requestVersion != _listRequestVersion) {
        return;
      }

      _applyFirstPageResult(result);
      _notify();
    } finally {
      if (!_disposed && requestVersion == _listRequestVersion) {
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> selectFolder(
    String folderId, {
    required String timeoutMessage,
  }) async {
    if (_mode == FavoritePageMode.local && folderId.trim().isEmpty) {
      return;
    }
    if (selectedFolderId == folderId || _initialLoading || _refreshing) {
      return;
    }

    final requestVersion = ++_listRequestVersion;
    _setSelectedFolderId(folderId);
    _initialLoading = true;
    _errorMessage = null;
    _comics = const [];
    _currentPage = 1;
    _hasMore = true;
    _loadingMore = false;
    _notify();

    final result = _mode == FavoritePageMode.local
        ? await _loadLocalFavoritesPage(page: 1, folderId: folderId)
        : await _loadCloudFavoritesPage(
            page: 1,
            folderId: folderId,
            timeoutMessage: timeoutMessage,
          );
    if (_disposed || requestVersion != _listRequestVersion) {
      return;
    }

    if (result.errorMessage == null) {
      _comics = result.comics;
      _currentPage = 1;
      if (result.maxPage != null) {
        _hasMore = _currentPage < result.maxPage!;
      } else {
        _hasMore = result.comics.isNotEmpty;
      }
    } else {
      _errorMessage = result.errorMessage;
    }
    _initialLoading = false;
    _notify();
  }

  Future<String?> createFolder(
    String name, {
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    try {
      if (_mode == FavoritePageMode.local) {
        await _localFavoritesService.addFavoriteFolder(name);
        await _reloadLocalFolders();
      } else {
        await _sourceService.addFavoriteFolder(name);
        await reloadFolders(onError: onFolderLoadError);
      }
      if (_disposed) {
        return null;
      }
      final created = _folders.where((folder) => folder.name == name).toList();
      if (created.isNotEmpty) {
        await selectFolder(created.first.id, timeoutMessage: timeoutMessage);
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> renameLocalFolder(String folderId, String name) async {
    if (_mode != FavoritePageMode.local) {
      return null;
    }

    final normalizedFolderId = folderId.trim();
    if (normalizedFolderId.isEmpty) {
      return null;
    }

    try {
      await _localFavoritesService.renameFavoriteFolder(
        folderId: normalizedFolderId,
        name: name,
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
    final normalized = order == 'mp' ? 'mp' : 'mr';
    if (normalized == _favoriteSortOrder) {
      return null;
    }

    try {
      if (_mode == FavoritePageMode.local) {
        await _localFavoritesService.saveSortOrder(normalized);
      } else {
        await _sourceService.setFavoriteSortOrder(normalized);
      }
      if (_disposed) {
        return null;
      }
      _favoriteSortOrder = normalized;
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
    if (_mode == FavoritePageMode.local && currentId.isEmpty) {
      return null;
    }
    if (_mode == FavoritePageMode.cloud && currentId == '0') {
      return null;
    }

    try {
      if (_mode == FavoritePageMode.local) {
        await _localFavoritesService.deleteFavoriteFolder(currentId);
        _selectedLocalFolderId = '';
        await _reloadLocalFolders();
      } else {
        await _sourceService.deleteFavoriteFolder(currentId);
        final updatedFolders = _folders
            .where((folder) => folder.id != currentId)
            .toList();
        _folders = updatedFolders.isEmpty
            ? const [defaultCloudFavoriteFolder]
            : updatedFolders;
        _selectedCloudFolderId = '0';
        _notify();
        unawaited(reloadFolders());
      }

      await selectFolder(
        _mode == FavoritePageMode.local ? _selectedLocalFolderId : '0',
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
    super.dispose();
  }

  Future<void> _loadInitialLocal() async {
    final requestVersion = ++_listRequestVersion;
    _favoriteSortOrder = await _localFavoritesService.loadSortOrder();
    await _reloadLocalFolders();
    if (_selectedLocalFolderId.isEmpty) {
      if (_disposed || requestVersion != _listRequestVersion) {
        return;
      }
      _comics = const [];
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = false;
      _initialLoading = false;
      _notify();
      return;
    }
    final result = await _loadLocalFavoritesPage(
      page: 1,
      folderId: _selectedLocalFolderId,
    );
    if (_disposed || requestVersion != _listRequestVersion) {
      return;
    }

    _applyFirstPageResult(result);
    _initialLoading = false;
    _notify();
  }

  Future<void> _reloadLocalFolders() async {
    _loadingFolders = true;
    _notify();

    final result = await _localFavoritesService.loadFavoriteFolders();
    if (_disposed) {
      return;
    }

    final folders = result.folders;
    final selectedExists = folders.any(
      (folder) => folder.id == _selectedLocalFolderId,
    );
    _folders = folders;
    if (!selectedExists) {
      _selectedLocalFolderId = folders.isEmpty ? '' : folders.first.id;
    }
    if (folders.isEmpty) {
      _comics = const [];
      _errorMessage = null;
      _currentPage = 1;
      _hasMore = false;
    }
    _loadingFolders = false;
    _notify();
  }

  void _applyFirstPageResult(FavoriteComicsResult result) {
    if (result.errorMessage == null) {
      _comics = result.comics;
      _errorMessage = null;
      _currentPage = 1;
      if (result.maxPage != null) {
        _hasMore = _currentPage < result.maxPage!;
      } else {
        _hasMore = result.comics.isNotEmpty;
      }
    } else {
      _errorMessage = result.errorMessage;
    }
  }

  Future<FavoriteComicsResult> _loadCloudFavoritesPage({
    required int page,
    required String timeoutMessage,
    String? folderId,
  }) {
    final targetFolderId = (folderId ?? _selectedCloudFolderId).trim();
    return _sourceService
        .loadFavoriteComics(page: page, folderId: targetFolderId)
        .timeout(
          favoriteLoadTimeout,
          onTimeout: () => FavoriteComicsResult.error(timeoutMessage),
        );
  }

  Future<FavoriteComicsResult> _loadLocalFavoritesPage({
    required int page,
    String? folderId,
  }) {
    return _localFavoritesService.loadFavoriteComics(
      page: page,
      folderId: (folderId ?? _selectedLocalFolderId).trim(),
      sortOrder: _favoriteSortOrder,
    );
  }

  List<ExploreComic> _mergeComics(
    List<ExploreComic> existing,
    List<ExploreComic> incoming,
  ) {
    final merged = <String, ExploreComic>{};
    for (final comic in existing) {
      if (comic.id.isNotEmpty) {
        merged[comic.id] = comic;
      }
    }
    for (final comic in incoming) {
      if (comic.id.isNotEmpty) {
        merged[comic.id] = comic;
      }
    }
    return merged.values.toList();
  }

  void _setSelectedFolderId(String folderId) {
    if (_mode == FavoritePageMode.local) {
      _selectedLocalFolderId = folderId;
    } else {
      _selectedCloudFolderId = folderId;
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
