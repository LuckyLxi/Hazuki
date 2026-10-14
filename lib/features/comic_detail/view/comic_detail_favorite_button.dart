import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';

import '../support/comic_detail_scope.dart';

class ComicDetailFavoriteButton extends StatelessWidget {
  const ComicDetailFavoriteButton({super.key, required this.details});

  final ComicDetailsData? details;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final favorite = scope.favorite;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = favorite.favoriteOverride ?? details?.isFavorite ?? false;

    return IconButton(
      tooltip: active
          ? l10n(context).comicDetailUnfavorite
          : l10n(context).comicDetailFavorite,
      isSelected: active,
      onPressed: details != null && !favorite.isBusy
          ? () => unawaited(
              favorite.showFoldersDialog(
                context,
                details!,
                (vm) => Theme(
                  data: scope.theme.buildDetailTheme(theme),
                  child: FavoriteFoldersMorphDialog(viewModel: vm),
                ),
              ),
            )
          : null,
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        backgroundColor: active
            ? colors.primaryContainer
            : colors.primary.withValues(alpha: 0.08),
        foregroundColor: active ? colors.onPrimaryContainer : colors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: const Icon(Icons.favorite_border, size: 22),
      selectedIcon: const Icon(Icons.favorite, size: 22),
    );
  }
}
