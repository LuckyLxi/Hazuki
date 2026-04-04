part of '../comic_detail_page.dart';

extension _ComicDetailFavoriteActionsExtension on _ComicDetailPageState {
  Future<void> _toggleFavorite(ComicDetailsData details) async {
    if (_favoriteBusy) {
      return;
    }
    await _showFavoriteFoldersPanel(details);
  }

  Future<void> _showFavoriteFoldersPanel(ComicDetailsData details) async {
    final service = HazukiSourceService.instance;
    final singleFolderOnly = service.favoriteSingleFolderForSingleComic;

    final changed = await showGeneralDialog<Map<String, Set<String>>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final themedData = _buildDetailTheme(Theme.of(context));
        return Theme(
          data: themedData,
          child: FavoriteFoldersMorphDialog(
            details: details,
            singleFolderOnly: singleFolderOnly,
            favoriteOverride: _favoriteOverride,
            initialIsFavorite: details.isFavorite,
          ),
        );
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
        final slide =
            Tween<Offset>(
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

    if (changed == null || !mounted) {
      return;
    }

    final selectedResult = Set<String>.from(changed['selected'] ?? <String>{});
    final initialFavoritedResult = Set<String>.from(
      changed['initial'] ?? <String>{},
    );

    final addTargets = selectedResult.difference(initialFavoritedResult);
    final removeTargets = initialFavoritedResult.difference(selectedResult);

    if (addTargets.isEmpty && removeTargets.isEmpty) {
      return;
    }

    _updateComicDetailState(() {
      _favoriteBusy = true;
    });

    try {
      await _applyFavoriteSelectionChanges(
        details: details,
        selectedResult: selectedResult,
        initialFavoritedResult: initialFavoritedResult,
        singleFolderOnly: singleFolderOnly,
      );

      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdated,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdateFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        _updateComicDetailState(() {
          _favoriteBusy = false;
        });
      }
    }
  }

  Future<void> _applyFavoriteSelectionChanges({
    required ComicDetailsData details,
    required Set<String> selectedResult,
    required Set<String> initialFavoritedResult,
    required bool singleFolderOnly,
  }) async {
    final service = HazukiSourceService.instance;
    final localService = LocalFavoritesService.instance;
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

    if (singleFolderOnly && service.isLogged && service.supportFavoriteToggle) {
      if (selectedCloudIds.isEmpty && initialCloudIds.isNotEmpty) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: initialCloudIds.first,
        );
      } else if (selectedCloudIds.isNotEmpty &&
          !_setContentsEqual(selectedCloudIds, initialCloudIds)) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: selectedCloudIds.first,
        );
      }
    } else if (service.isLogged && service.supportFavoriteToggle) {
      final addCloudIds = selectedCloudIds.difference(initialCloudIds);
      final removeCloudIds = initialCloudIds.difference(selectedCloudIds);
      for (final folderId in addCloudIds) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: folderId,
        );
      }
      for (final folderId in removeCloudIds) {
        await service.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: folderId,
        );
      }
    }

    final addLocalIds = selectedLocalIds.difference(initialLocalIds);
    final removeLocalIds = initialLocalIds.difference(selectedLocalIds);
    for (final folderId in addLocalIds) {
      await localService.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folderId,
      );
    }
    for (final folderId in removeLocalIds) {
      await localService.toggleFavorite(
        details: details,
        isAdding: false,
        folderId: folderId,
      );
    }

    _favoriteOverride = selectedResult.isNotEmpty;
  }

  Set<FavoriteFolderHandle> _favoriteHandlesFromStorageKeys(Set<String> keys) {
    final handles = <FavoriteFolderHandle>{};
    for (final key in keys) {
      final handle = favoriteFolderHandleFromStorageKey(key);
      if (handle != null) {
        handles.add(handle);
      }
    }
    return handles;
  }

  Set<String> _folderIdsForSource(
    Set<FavoriteFolderHandle> handles,
    FavoriteFolderSource source,
  ) {
    return handles
        .where((handle) => handle.source == source)
        .map((handle) => handle.id)
        .toSet();
  }

  bool _setContentsEqual(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }
}
