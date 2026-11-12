import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:hazuki/shared/favorites/favorite_folders_view_model.dart';
import 'package:hazuki/shared/favorites/favorite_selection_applier.dart';
import 'package:hazuki/shared/favorites/favorite_selection_result.dart';
import 'package:hazuki/shared/favorites/source_favorite_folders_repository.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';
import 'package:hazuki/shared/source_presentation.dart';

Future<void> showHistoryFavoriteDialog(
  BuildContext context,
  ExploreComic comic, {
  required SourceComicDetailGateway source,
  required LocalFavoritesRepository localFavorites,
}) async {
  final strings = AppLocalizations.of(context)!;

  try {
    final details = await source.loadComicDetails(
      comic.id,
      sourceKey: comic.sourceKey,
    );
    if (!context.mounted) {
      return;
    }

    await _showFavoriteFoldersPanelFromHistory(
      context,
      details,
      source: source,
      localFavorites: localFavorites,
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        strings.historyFavoriteFailed('$e'),
        isError: true,
      ),
    );
  }
}

Future<void> _showFavoriteFoldersPanelFromHistory(
  BuildContext context,
  ComicDetailsData details, {
  required SourceComicDetailGateway source,
  required LocalFavoritesRepository localFavorites,
}) async {
  final repository = SourceFavoriteFoldersRepository(
    source: source,
    local: localFavorites,
    sourceKey: details.sourceKey,
  );
  final singleFolderOnly = repository.favoriteSingleFolderForSingleComic;
  final viewModel = FavoriteFoldersViewModel(
    sourceUiService: SourcePresentationScope.uiOf(context),
    repository: repository,
    details: details,
    cloudFavoriteOverride: null,
    initialIsFavorite: details.isFavorite,
    singleFolderOnly: singleFolderOnly,
  );

  final FavoriteFolderSelectionResult? changed;
  try {
    changed = await showGeneralDialog<FavoriteFolderSelectionResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return FavoriteFoldersMorphDialog(viewModel: viewModel);
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
  } finally {
    viewModel.dispose();
  }

  if (changed == null || !context.mounted) {
    return;
  }

  if (!changed.hasChanges) {
    return;
  }

  try {
    await applyFavoriteFolderSelectionChanges(
      repository: repository,
      details: details,
      selection: changed,
      singleFolderOnly: singleFolderOnly,
    );

    if (!context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        AppLocalizations.of(context)!.comicDetailFavoriteSettingsUpdated,
      ),
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        AppLocalizations.of(
          context,
        )!.comicDetailFavoriteSettingsUpdateFailed('$e'),
        isError: true,
      ),
    );
  }
}
