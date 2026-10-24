import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/source_task_owner.dart';
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import 'package:hazuki/shared/favorites/favorite_folders_view_model.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/favorites/favorite_selection_applier.dart';
import 'package:hazuki/shared/favorites/favorite_selection_result.dart';

import '../repository/comic_detail_repository.dart';

typedef ComicDetailFavoriteDialogBuilder =
    Widget Function(FavoriteFoldersViewModel viewModel);

class ComicDetailFavoriteController extends ChangeNotifier {
  ComicDetailFavoriteController({
    required SourceTaskControlGateway taskControl,
    required ComicDetailFeatureFacade repository,
  }) : _readTasks = SourceTaskOwner(taskControl),
       _repository = repository;

  final ComicDetailFeatureFacade _repository;
  bool _disposed = false;
  final _sourceUi = SourceUiOwner();
  final SourceTaskOwner _readTasks;

  bool _busy = false;
  bool _likeBusy = false;
  bool? _favoriteOverride;
  bool? _cloudFavoriteOverride;
  bool? _likedOverride;

  bool get isBusy => _busy;
  bool get isLikeBusy => _likeBusy;
  bool get supportComicLike => _repository.supportComicLike;
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
    if (!supportComicLike) {
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
      await _sourceUi.run(
        () => _repository.toggleComicLike(
          comicId: details.id,
          isLike: nextLiked,
          sourceKey: details.sourceKey,
        ),
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
      if (_disposed || isSourceUiCancellation(e)) return;
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
    ComicDetailFavoriteDialogBuilder dialogBuilder, {
    FavoriteFoldersMorphOrigin? morphOrigin,
    VoidCallback? onDialogClosed,
  }) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final folders = _repository.favoriteFolders;
    final singleFolderOnly = folders.favoriteSingleFolderForSingleComic;
    _readTasks.restart();
    final viewModel = FavoriteFoldersViewModel(
      readTaskOrigin: _readTasks.origin(),
      repository: folders,
      details: details,
      cloudFavoriteOverride: _cloudFavoriteOverride,
      initialIsFavorite: details.isFavorite,
      singleFolderOnly: singleFolderOnly,
    );

    FavoriteFolderSelectionResult? changed;
    Future<void>? dialogCompleted;
    var buttonRestored = false;
    void restoreButton() {
      if (buttonRestored) return;
      buttonRestored = true;
      onDialogClosed?.call();
    }

    try {
      if (morphOrigin != null) {
        final route = RawDialogRoute<FavoriteFolderSelectionResult>(
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          barrierColor: Colors.black.withValues(alpha: 0.46),
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 560),
          pageBuilder: (context, animation, secondaryAnimation) =>
              FavoriteFoldersMorphScope(
                origin: morphOrigin,
                animation: animation,
                child: dialogBuilder(viewModel),
              ),
          transitionBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        );
        final popped = Navigator.of(context, rootNavigator: true).push(route);
        final animation = route.animation!;
        void handleStatus(AnimationStatus status) {
          if (status == AnimationStatus.dismissed) restoreButton();
        }

        animation.addStatusListener(handleStatus);
        dialogCompleted = route.completed.then((_) {
          animation.removeStatusListener(handleStatus);
        });
        // Save as soon as the result is confirmed. Only cleanup and the
        // caller's button restoration must wait for the overlay to unmount.
        changed = await popped;
      } else {
        changed = await showGeneralDialog<FavoriteFolderSelectionResult>(
          context: context,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          barrierColor: Colors.black.withValues(alpha: 0.46),
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (dialogContext, animation, secondaryAnimation) {
            return dialogBuilder(viewModel);
          },
          transitionBuilder:
              (dialogContext, animation, secondaryAnimation, child) {
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
      }
      if (changed == null || _disposed) return;

      if (!changed.hasChanges) return;
      final selection = changed;

      _busy = true;
      notifyListeners();

      try {
        final result = await _sourceUi.run(
          () => applyFavoriteFolderSelectionChanges(
            repository: folders,
            details: details,
            selection: selection,
            singleFolderOnly: singleFolderOnly,
          ),
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
        if (_disposed || isSourceUiCancellation(e)) return;
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
    } finally {
      if (dialogCompleted != null) await dialogCompleted;
      viewModel.dispose();
      restoreButton();
    }
  }

  @override
  void dispose() {
    _readTasks.dispose();
    _sourceUi.dispose();
    _disposed = true;
    super.dispose();
  }
}
