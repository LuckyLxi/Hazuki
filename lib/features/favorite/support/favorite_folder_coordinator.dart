import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../state/favorite_folder_state.dart';
import 'favorite_cloud_flow.dart';
import 'favorite_local_flow.dart';
import 'favorite_selection_store.dart';

typedef _FolderContext = ({
  int generation,
  String sourceKey,
  FavoritePageMode mode,
});

typedef _FolderRequest = ({int generation, _FolderContext context});

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
      bool forceReload,
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
  final Future<void> Function(
    String folderId, {
    required String timeoutMessage,
    bool forceReload,
  })
  _selectFolder;
  int _folderRequestVersion = 0;
  int _contextVersion = 0;

  _FolderContext _captureContext() => (
    generation: _contextVersion,
    sourceKey: _readSourceKey(),
    mode: _state.mode,
  );

  bool _isCurrentContext(_FolderContext context) =>
      !_isDisposed() &&
      context.generation == _contextVersion &&
      context.sourceKey == _readSourceKey() &&
      context.mode == _state.mode;

  _FolderRequest _captureFolderRequest() =>
      (generation: ++_folderRequestVersion, context: _captureContext());

  bool _isCurrentFolderRequest(_FolderRequest request) =>
      request.generation == _folderRequestVersion &&
      _isCurrentContext(request.context);

  void invalidate() {
    _contextVersion++;
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
    final context = _captureContext();
    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.addFolder(name, sourceKey: context.sourceKey);
        if (!_isCurrentContext(context)) return null;
        await reloadLocalFolders();
      } else {
        await _cloudFlow.addFolder(name);
        if (!_isCurrentContext(context)) return null;
        await reloadFolders(onError: onFolderLoadError);
      }
      if (!_isCurrentContext(context)) {
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

    final context = _captureContext();
    try {
      await _localFlow.renameFolder(
        folderId: normalizedFolderId,
        name: name,
        sourceKey: context.sourceKey,
      );
      if (!_isCurrentContext(context)) {
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

    final context = _captureContext();
    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.deleteFolder(currentId, sourceKey: context.sourceKey);
        if (!_isCurrentContext(context)) return null;
        _state.selectedLocalFolderId = '';
        await saveSelectedFolderId(FavoritePageMode.local, '');
        if (!_isCurrentContext(context)) return null;
        await reloadLocalFolders();
      } else {
        // Ordinary directory reads must not invalidate a successful mutation.
        await _cloudFlow.deleteFolder(currentId);
        if (!_isCurrentContext(context)) return null;
        // Reads started before deletion completed may still contain this folder.
        _folderRequestVersion++;
        _state.loadingFolders = false;
        final updatedFolders = _state.folders
            .where((folder) => folder.id != currentId)
            .toList();
        _state.folders = updatedFolders.isEmpty
            ? const [defaultCloudFavoriteFolder]
            : updatedFolders;
        final targetId = _state.folders.any((folder) => folder.id == '0')
            ? '0'
            : _state.folders.first.id;
        // Let selection persist the ID and load its comics before refreshing
        // folders, which may otherwise preselect it and skip the comic load.
        await _selectFolder(
          targetId,
          timeoutMessage: timeoutMessage,
          forceReload: true,
        );
        if (!_isCurrentContext(context)) return null;
        unawaited(reloadFolders());
        return null;
      }

      if (!_isCurrentContext(context)) return null;
      await _selectFolder(
        _state.selectedLocalFolderId,
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

    final result = await _localFlow.loadFoldersForSource(
      request.context.sourceKey,
    );
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
