// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import '../repository/comic_detail_repository.dart';
import 'favorite_folders_view_model.dart';

typedef ComicDetailFavoriteDialogBuilder =
    Widget Function(FavoriteFoldersViewModel viewModel);

class ComicDetailFavoriteController extends ChangeNotifier {
  ComicDetailFavoriteController({required ComicDetailRepository repository})
    : _repository = repository;

  final ComicDetailRepository _repository;
  bool _disposed = false;

  bool _busy = false;
  bool? _favoriteOverride;
  bool? _cloudFavoriteOverride;

  bool get isBusy => _busy;
  bool? get favoriteOverride => _favoriteOverride;
  bool? get cloudFavoriteOverride => _cloudFavoriteOverride;

  void applyInitialOverrides({
    required bool favoriteOverride,
    required bool cloudFavoriteOverride,
  }) {
    if (_disposed) return;
    _favoriteOverride = favoriteOverride;
    _cloudFavoriteOverride = cloudFavoriteOverride;
    notifyListeners();
  }

  Future<void> showFoldersDialog(
    BuildContext context,
    ComicDetailsData details,
    ComicDetailFavoriteDialogBuilder dialogBuilder,
  ) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final singleFolderOnly = _repository.favoriteSingleFolderForSingleComic;
    final viewModel = FavoriteFoldersViewModel(
      repository: _repository,
      details: details,
      cloudFavoriteOverride: _cloudFavoriteOverride,
      initialIsFavorite: details.isFavorite,
      singleFolderOnly: singleFolderOnly,
    );

    final changed = await showGeneralDialog<Map<String, Set<String>>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return dialogBuilder(viewModel);
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final opacity = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
              child: child,
            ),
          ),
        );
      },
    );

    viewModel.dispose();

    if (changed == null || _disposed) return;

    final selectedResult = Set<String>.from(changed['selected'] ?? <String>{});
    final initialFavoritedResult = Set<String>.from(
      changed['initial'] ?? <String>{},
    );

    final addTargets = selectedResult.difference(initialFavoritedResult);
    final removeTargets = initialFavoritedResult.difference(selectedResult);
    if (addTargets.isEmpty && removeTargets.isEmpty) return;

    _busy = true;
    notifyListeners();

    try {
      await _applyFavoriteSelectionChanges(
        details: details,
        selectedResult: selectedResult,
        initialFavoritedResult: initialFavoritedResult,
        singleFolderOnly: singleFolderOnly,
      );

      if (_disposed) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdated,
        ),
      );
    } catch (e) {
      if (_disposed) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdateFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _applyFavoriteSelectionChanges({
    required ComicDetailsData details,
    required Set<String> selectedResult,
    required Set<String> initialFavoritedResult,
    required bool singleFolderOnly,
  }) async {
    final selectedHandles = _favoriteHandlesFromStorageKeys(selectedResult);
    final initialHandles = _favoriteHandlesFromStorageKeys(
      initialFavoritedResult,
    );

    final selectedCloudIds = _folderIdsForSource(
      selectedHandles,
      FavoriteFolderSource.cloud,
    );
    final initialCloudIds = _folderIdsForSource(
      initialHandles,
      FavoriteFolderSource.cloud,
    );
    final selectedLocalIds = _folderIdsForSource(
      selectedHandles,
      FavoriteFolderSource.local,
    );
    final initialLocalIds = _folderIdsForSource(
      initialHandles,
      FavoriteFolderSource.local,
    );

    if (singleFolderOnly &&
        _repository.isLogged &&
        _repository.supportFavoriteToggle) {
      if (selectedCloudIds.isEmpty && initialCloudIds.isNotEmpty) {
        await _repository.toggleCloudFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: initialCloudIds.first,
        );
      } else if (selectedCloudIds.isNotEmpty &&
          !_setContentsEqual(selectedCloudIds, initialCloudIds)) {
        await _repository.toggleCloudFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: selectedCloudIds.first,
        );
      }
    } else if (_repository.isLogged && _repository.supportFavoriteToggle) {
      for (final folderId in selectedCloudIds.difference(initialCloudIds)) {
        await _repository.toggleCloudFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: folderId,
        );
      }
      for (final folderId in initialCloudIds.difference(selectedCloudIds)) {
        await _repository.toggleCloudFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: folderId,
        );
      }
    }

    for (final folderId in selectedLocalIds.difference(initialLocalIds)) {
      await _repository.toggleLocalFavorite(
        details: details,
        isAdding: true,
        folderId: folderId,
      );
    }
    for (final folderId in initialLocalIds.difference(selectedLocalIds)) {
      await _repository.toggleLocalFavorite(
        details: details,
        isAdding: false,
        folderId: folderId,
      );
    }

    if (!_disposed) {
      _favoriteOverride = selectedResult.isNotEmpty;
      _cloudFavoriteOverride = selectedCloudIds.isNotEmpty;
    }
  }

  Set<FavoriteFolderHandle> _favoriteHandlesFromStorageKeys(Set<String> keys) {
    final handles = <FavoriteFolderHandle>{};
    for (final key in keys) {
      final handle = favoriteFolderHandleFromStorageKey(key);
      if (handle != null) handles.add(handle);
    }
    return handles;
  }

  Set<String> _folderIdsForSource(
    Set<FavoriteFolderHandle> handles,
    FavoriteFolderSource source,
  ) {
    return handles
        .where((h) => h.source == source)
        .map((h) => h.id)
        .toSet();
  }

  bool _setContentsEqual(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
