import 'package:flutter/material.dart';

import 'package:hazuki/features/favorite/favorite.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

class FavoriteAppBarActions extends StatelessWidget {
  const FavoriteAppBarActions({
    super.key,
    required this.state,
    required this.onSortSelected,
    required this.onCreateFolderPressed,
    required this.onModeTogglePressed,
  });

  final FavoriteAppBarActionsState state;
  final ValueChanged<String> onSortSelected;
  final VoidCallback onCreateFolderPressed;
  final VoidCallback onModeTogglePressed;

  @override
  Widget build(BuildContext context) {
    final isLocalMode = state.currentMode == FavoritePageMode.local;
    return Row(
      key: const ValueKey<String>('favorite-appbar-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.showModeToggle)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: TextButton.icon(
                key: ValueKey<FavoritePageMode>(state.currentMode),
                onPressed: onModeTogglePressed,
                icon: Icon(
                  isLocalMode
                      ? Icons.folder_copy_outlined
                      : Icons.cloud_outlined,
                  size: 18,
                ),
                label: Text(
                  isLocalMode
                      ? l10n(context).favoriteModeLocal
                      : l10n(context).favoriteModeCloud,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        if (state.showSort)
          PopupMenuButton<String>(
            tooltip: l10n(context).homeSortTooltip,
            initialValue: state.currentSortOrder,
            onSelected: onSortSelected,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'mr',
                checked: state.currentSortOrder == 'mr',
                child: Text(l10n(context).homeFavoriteSortByFavoriteTime),
              ),
              CheckedPopupMenuItem<String>(
                value: 'mp',
                checked: state.currentSortOrder == 'mp',
                child: Text(l10n(context).homeFavoriteSortByUpdateTime),
              ),
            ],
            icon: const Icon(Icons.sort_rounded),
          ),
        if (state.showCreateFolder)
          IconButton(
            tooltip: l10n(context).homeCreateFavoriteFolder,
            onPressed: onCreateFolderPressed,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
      ],
    );
  }
}
