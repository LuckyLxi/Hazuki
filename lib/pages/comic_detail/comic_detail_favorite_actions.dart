part of '../comic_detail_page.dart';

extension _ComicDetailFavoriteActionsExtension on _ComicDetailPageState {
  Future<void> _toggleFavorite(ComicDetailsData details) async {
    if (_favoriteBusy) {
      return;
    }

    if (!HazukiSourceService.instance.isLogged) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).historyLoginRequired,
          isError: true,
        ),
      );
      return;
    }

    final service = HazukiSourceService.instance;
    if (!service.supportFavoriteFolderLoad || !service.supportFavoriteToggle) {
      final currentFavorite = _favoriteOverride ?? details.isFavorite;
      await _toggleFavoriteSimple(
        details: details,
        isAdding: !currentFavorite,
        folderId: '0',
      );
      return;
    }

    await _showFavoriteFoldersPanel(details);
  }

  Future<void> _toggleFavoriteSimple({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  }) async {
    _updateComicDetailState(() {
      _favoriteBusy = true;
    });
    try {
      await HazukiSourceService.instance.toggleFavorite(
        comicId: details.id,
        isAdding: isAdding,
        folderId: folderId,
      );
      if (!mounted) {
        return;
      }
      _updateComicDetailState(() {
        _favoriteOverride = isAdding;
      });
      unawaited(
        showHazukiPrompt(
          context,
          isAdding
              ? l10n(context).comicDetailFavoriteAdded
              : l10n(context).comicDetailFavoriteRemoved,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteActionFailed('$e'),
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
      if (singleFolderOnly) {
        if (selectedResult.isEmpty) {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: false,
            folderId: initialFavoritedResult.firstOrNull ?? '0',
          );
          _favoriteOverride = false;
        } else {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: true,
            folderId: selectedResult.first,
          );
          _favoriteOverride = true;
        }
      } else {
        for (final folderId in addTargets) {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: true,
            folderId: folderId,
          );
        }
        for (final folderId in removeTargets) {
          await service.toggleFavorite(
            comicId: details.id,
            isAdding: false,
            folderId: folderId,
          );
        }
        _favoriteOverride = selectedResult.isNotEmpty;
      }

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
}
