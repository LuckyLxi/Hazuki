import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import 'favorite_app_bar_actions_state.dart';

const defaultFavoriteFolder = FavoriteFolder(id: '0', name: '__favorite_all__');

class FavoritePageController extends ChangeNotifier {
  FavoritePageController({HazukiSourceService? sourceService})
    : _sourceService = sourceService ?? HazukiSourceService.instance;

  static const favoriteLoadTimeout = Duration(seconds: 90);

  final HazukiSourceService _sourceService;

  bool _disposed = false;
  List<ExploreComic> _comics = const [];
  List<FavoriteFolder> _folders = const [defaultFavoriteFolder];
  String _selectedFolderId = '0';
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
  String get selectedFolderId => _selectedFolderId;
  String? get errorMessage => _errorMessage;
  bool get initialLoading => _initialLoading;
  bool get refreshing => _refreshing;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get loadingFolders => _loadingFolders;
  bool get isLogged => _sourceService.isLogged;
  bool get supportsFolderLoad => _sourceService.supportFavoriteFolderLoad;
  bool get supportsFolderDelete => _sourceService.supportFavoriteFolderDelete;

  FavoriteAppBarActionsState get appBarActionsState {
    final canOperate = _sourceService.isLogged;
    return FavoriteAppBarActionsState(
      showSort: canOperate && _sourceService.supportFavoriteSortOrder,
      showCreateFolder: canOperate && _sourceService.supportFavoriteFolderAdd,
      currentSortOrder: _favoriteSortOrder,
    );
  }

  void resetForReload() {
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
    _comics = const [];
    _folders = const [defaultFavoriteFolder];
    _selectedFolderId = '0';
    _errorMessage = null;
    _initialLoading = false;
    _refreshing = false;
    _loadingMore = false;
    _hasMore = true;
    _currentPage = 1;
    _loadingFolders = false;
    _notify();
  }

  Future<void> loadInitial({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
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
    final targetFolderId = _selectedFolderId;

    await reloadFolders(onError: onFolderLoadError);

    final result = await _loadFavoritesPage(
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

  Future<void> reloadFolders({ValueChanged<String>? onError}) async {
    if (!_sourceService.supportFavoriteFolderLoad) {
      _folders = const [defaultFavoriteFolder];
      _selectedFolderId = '0';
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
        ? const [defaultFavoriteFolder]
        : result.folders;
    final selectedExists = folders.any((folder) => folder.id == _selectedFolderId);

    _folders = folders;
    if (!selectedExists) {
      _selectedFolderId = folders.first.id;
    }
    _loadingFolders = false;
    _notify();
  }

  Future<String?> loadMore({required String timeoutMessage}) async {
    if (_initialLoading ||
        _refreshing ||
        _loadingMore ||
        !_hasMore ||
        !_sourceService.isLogged) {
      return null;
    }

    final requestVersion = _listRequestVersion;
    final targetFolderId = _selectedFolderId;

    _loadingMore = true;
    _notify();

    try {
      final nextPage = _currentPage + 1;
      final result = await _loadFavoritesPage(
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
    if (!_sourceService.isLogged || _refreshing) {
      return;
    }

    final requestVersion = ++_listRequestVersion;
    final targetFolderId = _selectedFolderId;

    _refreshing = true;
    _loadingMore = false;
    _notify();

    try {
      await reloadFolders(onError: onFolderLoadError);
      final result = await _loadFavoritesPage(
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
    if (_selectedFolderId == folderId || _initialLoading || _refreshing) {
      return;
    }

    final requestVersion = ++_listRequestVersion;

    _selectedFolderId = folderId;
    _initialLoading = true;
    _errorMessage = null;
    _comics = const [];
    _currentPage = 1;
    _hasMore = true;
    _loadingMore = false;
    _notify();

    final result = await _loadFavoritesPage(
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
      await _sourceService.addFavoriteFolder(name);
      await reloadFolders(onError: onFolderLoadError);
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
      await _sourceService.setFavoriteSortOrder(normalized);
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

  Future<String?> deleteCurrentFolder({
    required String timeoutMessage,
  }) async {
    final currentId = _selectedFolderId;
    if (currentId == '0') {
      return null;
    }

    try {
      await _sourceService.deleteFavoriteFolder(currentId);
      if (_disposed) {
        return null;
      }

      final updatedFolders = _folders.where((folder) => folder.id != currentId).toList();
      _folders = updatedFolders.isEmpty
          ? const [defaultFavoriteFolder]
          : updatedFolders;
      _notify();

      await selectFolder('0', timeoutMessage: timeoutMessage);
      unawaited(reloadFolders());
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

  Future<FavoriteComicsResult> _loadFavoritesPage({
    required int page,
    required String timeoutMessage,
    String? folderId,
  }) {
    final targetFolderId = (folderId ?? _selectedFolderId).trim();
    return _sourceService
        .loadFavoriteComics(page: page, folderId: targetFolderId)
        .timeout(
          favoriteLoadTimeout,
          onTimeout: () => FavoriteComicsResult.error(timeoutMessage),
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

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
