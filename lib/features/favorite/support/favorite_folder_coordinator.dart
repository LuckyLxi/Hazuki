import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../state/favorite_folder_state.dart';
import 'favorite_cloud_flow.dart';
import 'favorite_local_flow.dart';
import 'favorite_selection_store.dart';

typedef _FolderRequest = ({
  int generation,
  String sourceKey,
  FavoritePageMode mode,
});

/// Owns directory requests separately from comic-list requests.
class FavoriteFolderCoordinator {
  FavoriteFolderCoordinator({
    required FavoriteFolderState state,
    required FavoriteCloudFlow cloudFlow,
    required FavoriteLocalFlow localFlow,
    required FavoriteSelectionStore selectionStore,
    required String Function() readSourceKey,
    required bool Function() isDisposed,
    required VoidCallback notify,
    required Future<void> Function(
      String folderId, {
      required String timeoutMessage,
    })
    selectFolder,
  }) : _state = state,
       _cloudFlow = cloudFlow,
       _localFlow = localFlow,
       _selectionStore = selectionStore,
       _readSourceKey = readSourceKey,
       _isDisposed = isDisposed,
       _notify = notify,
       _selectFolder = selectFolder;

  final FavoriteFolderState _state;
  final FavoriteCloudFlow _cloudFlow;
  final FavoriteLocalFlow _localFlow;
  final FavoriteSelectionStore _selectionStore;
  final String Function() _readSourceKey;
  final bool Function() _isDisposed;
  final VoidCallback _notify;
  final Future<void> Function(String folderId, {required String timeoutMessage})
  _selectFolder;
  int _folderRequestVersion = 0;

  _FolderRequest _captureFolderRequest() => (
    generation: ++_folderRequestVersion,
    sourceKey: _readSourceKey(),
    mode: _state.mode,
  );

  bool _isCurrentFolderRequest(_FolderRequest request) =>
      !_isDisposed() &&
      request.generation == _folderRequestVersion &&
      request.sourceKey == _readSourceKey() &&
      request.mode == _state.mode;

  void invalidate() {
    _folderRequestVersion++;
    _state.loadingFolders = false;
  }

  Future<void> reloadFolders({ValueChanged<String>? onError}) async {
    if (_state.mode == FavoritePageMode.local) {
      await reloadLocalFolders();
      return;
    }

    final request = _captureFolderRequest();
    if (!_cloudFlow.supportsFolderLoad) {
      _state.folders = const <FavoriteFolder>[defaultCloudFavoriteFolder];
      _state.selectedCloudFolderId = '0';
      await saveSelectedFolderId(FavoritePageMode.cloud, '0');
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
      await saveSelectedFolderId(
        FavoritePageMode.cloud,
        _state.selectedCloudFolderId,
      );
    }
    if (!_isCurrentFolderRequest(request)) return;
    _state.loadingFolders = false;
    _notify();
  }

  Future<String?> createFolder(
    String name, {
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.addFolder(name, sourceKey: _readSourceKey());
        await reloadLocalFolders();
      } else {
        await _cloudFlow.addFolder(name);
        await reloadFolders(onError: onFolderLoadError);
      }
      if (_isDisposed()) {
        return null;
      }
      final created = _state.folders
          .where((folder) => folder.name == name)
          .toList();
      if (created.isNotEmpty) {
        await _selectFolder(created.first.id, timeoutMessage: timeoutMessage);
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
      if (_isDisposed()) {
        return null;
      }
      await reloadLocalFolders();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> deleteCurrentFolder({required String timeoutMessage}) async {
    final currentId = _state.selectedFolderId;
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
        await saveSelectedFolderId(FavoritePageMode.local, '');
        await reloadLocalFolders();
      } else {
        await _cloudFlow.deleteFolder(currentId);
        final updatedFolders = _state.folders
            .where((folder) => folder.id != currentId)
            .toList();
        _state.folders = updatedFolders.isEmpty
            ? const [defaultCloudFavoriteFolder]
            : updatedFolders;
        _state.selectedCloudFolderId = '0';
        await saveSelectedFolderId(FavoritePageMode.cloud, '0');
        _notify();
        unawaited(reloadFolders());
      }

      await _selectFolder(
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

  Future<void> reloadLocalFolders({bool notifyChanges = true}) async {
    final request = _captureFolderRequest();
    _state.loadingFolders = true;
    if (notifyChanges) {
      _notify();
    }

    final result = await _localFlow.loadFolders();
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
      await saveSelectedFolderId(
        FavoritePageMode.local,
        _state.selectedLocalFolderId,
      );
    }
    if (!_isCurrentFolderRequest(request)) return;
    if (folders.isEmpty) {
      _state.clearComicsForEmptyFolders();
    }
    _state.loadingFolders = false;
    if (notifyChanges) {
      _notify();
    }
  }

  Future<void> saveSelectedFolderId(
    FavoritePageMode mode,
    String folderId,
  ) async {
    await _selectionStore.saveFolder(mode, folderId, _readSourceKey());
  }
}
