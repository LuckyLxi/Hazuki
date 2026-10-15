import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';

import '../support/comic_detail_scope.dart';

class ComicDetailFavoriteButton extends StatefulWidget {
  const ComicDetailFavoriteButton({super.key, required this.details});

  final ComicDetailsData? details;

  @override
  State<ComicDetailFavoriteButton> createState() =>
      _ComicDetailFavoriteButtonState();
}

class _ComicDetailFavoriteButtonState extends State<ComicDetailFavoriteButton> {
  bool _dialogOpen = false;

  void _restoreButton() {
    if (mounted && _dialogOpen) setState(() => _dialogOpen = false);
  }

  Future<void> _showDialog() async {
    if (_dialogOpen || widget.details == null) return;
    final box = context.findRenderObject() as RenderBox;
    final scope = ComicDetailScope.of(context);
    final theme = scope.theme.buildDetailTheme(Theme.of(context));
    final colors = theme.colorScheme;
    final active =
        scope.favorite.favoriteOverride ?? widget.details!.isFavorite;
    final origin = FavoriteFoldersMorphOrigin(
      rect: box.localToGlobal(Offset.zero) & box.size,
      backgroundColor: active
          ? colors.primaryContainer
          : colors.primary.withValues(alpha: 0.08),
      foregroundColor: active ? colors.onPrimaryContainer : colors.primary,
      icon: active ? Icons.favorite : Icons.favorite_border,
    );
    setState(() => _dialogOpen = true);
    try {
      await scope.favorite.showFoldersDialog(
        context,
        widget.details!,
        (vm) => Theme(
          data: theme,
          child: FavoriteFoldersMorphDialog(viewModel: vm),
        ),
        morphOrigin: origin,
        onDialogClosed: _restoreButton,
      );
    } finally {
      _restoreButton();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final favorite = scope.favorite;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active =
        favorite.favoriteOverride ?? widget.details?.isFavorite ?? false;

    return IgnorePointer(
      ignoring: _dialogOpen,
      child: Opacity(
        opacity: _dialogOpen ? 0 : 1,
        child: IconButton(
          tooltip: active
              ? l10n(context).comicDetailUnfavorite
              : l10n(context).comicDetailFavorite,
          isSelected: active,
          // IgnorePointer and _showDialog's guard block repeat activation
          // without animating the hidden button through its disabled colors.
          onPressed: widget.details != null && !favorite.isBusy
              ? () => unawaited(_showDialog())
              : null,
          style: IconButton.styleFrom(
            fixedSize: const Size(48, 48),
            backgroundColor: active
                ? colors.primaryContainer
                : colors.primary.withValues(alpha: 0.08),
            foregroundColor: active
                ? colors.onPrimaryContainer
                : colors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: const Icon(Icons.favorite_border, size: 22),
          selectedIcon: const Icon(Icons.favorite, size: 22),
        ),
      ),
    );
  }
}
