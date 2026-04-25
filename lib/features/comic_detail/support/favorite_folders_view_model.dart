import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/models/hazuki_models.dart';

import '../repository/comic_detail_repository.dart';

class FavoriteFoldersViewModel extends ChangeNotifier {
  FavoriteFoldersViewModel({
    required ComicDetailRepository repository,
    required ComicDetailsData details,
    required bool? cloudFavoriteOverride,
    required bool initialIsFavorite,
    required bool singleFolderOnly,
  }) : _repository = repository,
       _details = details,
       _cloudFavoriteOverride = cloudFavoriteOverride,
       _initialIsFavorite = initialIsFavorite,
       _singleFolderOnly = singleFolderOnly;

  final ComicDetailRepository _repository;
  final ComicDetailsData _details;
  final bool? _cloudFavoriteOverride;
  final bool _initialIsFavorite;
  final bool _singleFolderOnly;

  bool _disposed = false;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  List<FavoriteFolder> _cloudFolders = <FavoriteFolder>[];
  List<FavoriteFolder> _localFolders = <FavoriteFolder>[];
  Set<String> _selected = <String>{};
  Set<String> _initialFavorited = <String>{};

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get loadError => _loadError;
  List<FavoriteFolder> get cloudFolders => _cloudFolders;
  List<FavoriteFolder> get localFolders => _localFolders;
  Set<String> get selected => Set<String>.unmodifiable(_selected);
  Set<String> get initialFavorited =>
      Set<String>.unmodifiable(_initialFavorited);
  bool get singleFolderOnly => _singleFolderOnly;

  bool get canCreateCloudFolder =>
      _repository.isLogged && _repository.supportFavoriteFolderAdd;
  bool get canDeleteCloudFolder =>
      _repository.isLogged && _repository.supportFavoriteFolderDelete;
  bool get _canLoadCloudFolders =>
      _repository.isLogged && _repository.supportFavoriteFolderLoad;
  bool get _canUseCloudDefaultFavoriteFallback =>
      _repository.isLogged && _repository.supportFavoriteToggle;

  Future<void> load({
    bool initialLoad = false,
    bool preserveSelection = false,
  }) async {
    if (_disposed) return;

    final previousSelected = Set<String>.from(_selected);
    final previousInitialFavorited = Set<String>.from(_initialFavorited);

    if (initialLoad) {
      _isLoading = true;
    } else {
      _isBusy = true;
    }
    _loadError = null;
    notifyListeners();

    try {
      final localResult = await _repository.loadLocalFavoriteFolders(
        comicId: _details.id,
      );
      final cloudResult = _canLoadCloudFolders
          ? await _repository.loadCloudFavoriteFolders(comicId: _details.id)
          : const FavoriteFoldersResult.success(
              folders: <FavoriteFolder>[],
              favoritedFolderIds: <String>{},
            );

      if (_disposed) return;

      final cloudFolders = List<FavoriteFolder>.from(cloudResult.folders);
      if (cloudFolders.isEmpty && _canUseCloudDefaultFavoriteFallback) {
        cloudFolders.add(
          const FavoriteFolder(
            id: '0',
            name: '__favorite_all__',
            source: FavoriteFolderSource.cloud,
          ),
        );
      }
      final localFolders = List<FavoriteFolder>.from(localResult.folders);
      final nextInitialFavorited = <String>{
        ..._toStorageKeys(
          favoritedFolderIds: cloudResult.favoritedFolderIds,
          source: FavoriteFolderSource.cloud,
        ),
        ..._toStorageKeys(
          favoritedFolderIds: localResult.favoritedFolderIds,
          source: FavoriteFolderSource.local,
        ),
      };
      final hasCloudSelection = nextInitialFavorited.any((storageKey) {
        final handle = favoriteFolderHandleFromStorageKey(storageKey);
        return handle?.source == FavoriteFolderSource.cloud;
      });

      if (!hasCloudSelection &&
          _singleFolderOnly &&
          (_cloudFavoriteOverride ?? _initialIsFavorite) &&
          _canUseCloudDefaultFavoriteFallback &&
          cloudFolders.isNotEmpty) {
        nextInitialFavorited.add(
          const FavoriteFolderHandle(
            source: FavoriteFolderSource.cloud,
            id: '0',
          ).storageKey,
        );
      }

      final availableKeys = <String>{
        ...cloudFolders.map((folder) => folder.storageKey),
        ...localFolders.map((folder) => folder.storageKey),
      };

      _isLoading = false;
      _isBusy = false;
      _cloudFolders = cloudFolders;
      _localFolders = localFolders;

      if (preserveSelection) {
        _initialFavorited = previousInitialFavorited.intersection(
          availableKeys,
        );
        _selected = previousSelected.intersection(availableKeys);
      } else {
        _initialFavorited = nextInitialFavorited;
        _selected = Set<String>.from(nextInitialFavorited);
      }

      _loadError =
          (cloudResult.errorMessage != null &&
              _cloudFolders.isEmpty &&
              _localFolders.length <= 1)
          ? cloudResult.errorMessage
          : null;

      notifyListeners();
      if (initialLoad) {
        unawaited(HapticFeedback.selectionClick());
      }
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      _isBusy = false;
      _loadError = e.toString();
      notifyListeners();
      if (initialLoad) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  void toggleFolder(FavoriteFolder folder, {bool? value}) {
    if (_isBusy) return;
    final folderKey = folder.storageKey;
    final checked = _selected.contains(folderKey);
    final enable = value ?? !checked;
    final nextSelected = Set<String>.from(_selected);
    if (enable) {
      if (folder.source == FavoriteFolderSource.cloud && _singleFolderOnly) {
        nextSelected.removeWhere((storageKey) {
          final handle = favoriteFolderHandleFromStorageKey(storageKey);
          return handle?.source == FavoriteFolderSource.cloud;
        });
      }
      nextSelected.add(folderKey);
    } else {
      nextSelected.remove(folderKey);
    }
    _selected = nextSelected;
    notifyListeners();
  }

  Future<void> createFolder(String name, FavoriteFolderSource target) async {
    if (_disposed) return;
    _isBusy = true;
    notifyListeners();
    try {
      if (target == FavoriteFolderSource.local) {
        await _repository.addLocalFavoriteFolder(name);
      } else {
        await _repository.addCloudFavoriteFolder(name);
      }
      if (_disposed) return;
      await load(preserveSelection: true);
    } catch (e) {
      if (_disposed) return;
      _isBusy = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteFolder(FavoriteFolder folder) async {
    if (_disposed) return;
    _isBusy = true;
    notifyListeners();
    try {
      if (folder.source == FavoriteFolderSource.local) {
        await _repository.deleteLocalFavoriteFolder(folder.id);
      } else {
        await _repository.deleteCloudFavoriteFolder(folder.id);
      }
      if (_disposed) return;
      await load(preserveSelection: true);
    } catch (e) {
      if (_disposed) return;
      _isBusy = false;
      notifyListeners();
      rethrow;
    }
  }

  Map<String, Set<String>> buildSaveResult() {
    return {
      'selected': Set<String>.from(_selected),
      'initial': Set<String>.from(_initialFavorited),
    };
  }

  Set<String> _toStorageKeys({
    required Set<String> favoritedFolderIds,
    required FavoriteFolderSource source,
  }) {
    return favoritedFolderIds
        .map((id) => FavoriteFolderHandle(source: source, id: id).storageKey)
        .toSet();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
