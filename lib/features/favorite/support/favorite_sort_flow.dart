import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorite_sort.dart';

import '../state/favorite_sort_state.dart';
import 'favorite_cloud_flow.dart';
import 'favorite_local_flow.dart';
import 'favorite_source_policy.dart';

/// Applies sort policy and persistence, leaving comic loading with the page.
class FavoriteSortFlow {
  FavoriteSortFlow({
    required FavoriteSortState state,
    required FavoriteCloudFlow cloudFlow,
    required FavoriteLocalFlow localFlow,
    required FavoriteSourcePolicy sourcePolicy,
    required String Function() readSourceKey,
    required bool Function() isDisposed,
    required Future<String?> Function() reloadLocalComicsAfterSort,
    required VoidCallback resetForReload,
    required Future<void> Function({
      required String timeoutMessage,
      ValueChanged<String>? onFolderLoadError,
    })
    loadInitial,
  }) : _state = state,
       _cloudFlow = cloudFlow,
       _localFlow = localFlow,
       _sourcePolicy = sourcePolicy,
       _readSourceKey = readSourceKey,
       _isDisposed = isDisposed,
       _reloadLocalComicsAfterSort = reloadLocalComicsAfterSort,
       _resetForReload = resetForReload,
       _loadInitial = loadInitial;

  final FavoriteSortState _state;
  final FavoriteCloudFlow _cloudFlow;
  final FavoriteLocalFlow _localFlow;
  final FavoriteSourcePolicy _sourcePolicy;
  final String Function() _readSourceKey;
  final bool Function() _isDisposed;
  final Future<String?> Function() _reloadLocalComicsAfterSort;
  final VoidCallback _resetForReload;
  final Future<void> Function({
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  })
  _loadInitial;

  Future<String?> changeSortOrder(
    String order, {
    required String timeoutMessage,
    ValueChanged<String>? onFolderLoadError,
  }) async {
    final normalized = _state.mode == FavoritePageMode.local
        ? normalizeLocalFavoriteSort(order)
        : _sourcePolicy.normalizeSortOrder(
            order,
            allowedOrders: _cloudFlow.sortOrders,
            sourceKey: _readSourceKey(),
          );
    if (normalized == _state.favoriteSortOrder) {
      return null;
    }

    try {
      if (_state.mode == FavoritePageMode.local) {
        await _localFlow.saveSortOrder(normalized);
        if (_isDisposed()) {
          return null;
        }
        _state.favoriteSortOrder = normalized;
        return await _reloadLocalComicsAfterSort();
      } else {
        await _cloudFlow.setSortOrder(normalized);
      }
      if (_isDisposed()) {
        return null;
      }
      _state.favoriteSortOrder = normalized;
      _resetForReload();
      await _loadInitial(
        timeoutMessage: timeoutMessage,
        onFolderLoadError: onFolderLoadError,
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }
}
