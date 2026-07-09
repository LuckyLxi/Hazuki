// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import 'package:hazuki/shared/favorites/favorite_folders_view_model.dart';
import 'package:hazuki/shared/favorites/favorite_selection_applier.dart';
import 'package:hazuki/shared/favorites/favorite_selection_result.dart';

import '../repository/comic_detail_repository.dart';

typedef ComicDetailFavoriteDialogBuilder =
    Widget Function(FavoriteFoldersViewModel viewModel);

class ComicDetailFavoriteController extends ChangeNotifier {
  ComicDetailFavoriteController({required ComicDetailFeatureFacade repository})
    : _repository = repository;

  final ComicDetailFeatureFacade _repository;
  bool _disposed = false;

  bool _busy = false;
  bool _likeBusy = false;
  bool? _favoriteOverride;
  bool? _cloudFavoriteOverride;
  bool? _likedOverride;

  bool get isBusy => _busy;
  bool get isLikeBusy => _likeBusy;
  bool? get favoriteOverride => _favoriteOverride;
  bool? get cloudFavoriteOverride => _cloudFavoriteOverride;
  bool? get likedOverride => _likedOverride;

  void applyInitialOverrides({
    required bool favoriteOverride,
    required bool cloudFavoriteOverride,
  }) {
    if (_disposed) return;
    _favoriteOverride = favoriteOverride;
    _cloudFavoriteOverride = cloudFavoriteOverride;
    notifyListeners();
  }

  Future<void> toggleLike(
    BuildContext context,
    ComicDetailsData details,
  ) async {
    if (_likeBusy) return;
    if (!_repository.supportComicLike) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailLikeActionFailed('not_supported'),
          isError: true,
        ),
      );
      return;
    }

    final nextLiked = !(_likedOverride ?? details.isLiked);
    _likeBusy = true;
    notifyListeners();

    try {
      await _repository.toggleComicLike(
        comicId: details.id,
        isLike: nextLiked,
        sourceKey: details.sourceKey,
      );
      if (_disposed) return;
      _likedOverride = nextLiked;
      unawaited(
        showHazukiPrompt(
          context,
          nextLiked
              ? l10n(context).comicDetailLiked
              : l10n(context).comicDetailUnliked,
        ),
      );
    } catch (e) {
      if (_disposed) return;
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailLikeActionFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (!_disposed) {
        _likeBusy = false;
        notifyListeners();
      }
    }
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

    final changed = await showGeneralDialog<FavoriteFolderSelectionResult>(
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

    viewModel.dispose();

    if (changed == null || _disposed) return;

    if (!changed.hasChanges) return;

    _busy = true;
    notifyListeners();

    try {
      final result = await applyFavoriteFolderSelectionChanges(
        repository: _repository,
        details: details,
        selection: changed,
        singleFolderOnly: singleFolderOnly,
      );
      if (_disposed) return;
      _favoriteOverride = result.hasSelection;
      _cloudFavoriteOverride = result.hasCloudSelection;

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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
