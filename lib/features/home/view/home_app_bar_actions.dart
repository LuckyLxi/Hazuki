import 'package:flutter/material.dart';

import 'package:hazuki/features/favorite/favorite.dart';

import 'discover_app_bar_actions.dart';
import 'favorite_app_bar_actions.dart';

class HomeAppBarActions extends StatelessWidget {
  const HomeAppBarActions({
    super.key,
    required this.currentIndex,
    required this.discoverSearchMorphProgress,
    required this.forceDiscoverSearchInAppBar,
    required this.favoriteAppBarActions,
    required this.onOpenSearch,
    required this.onFavoriteSortSelected,
    required this.onFavoriteCreateFolderPressed,
    required this.onFavoriteModeTogglePressed,
  });

  final int currentIndex;
  final double discoverSearchMorphProgress;
  final bool forceDiscoverSearchInAppBar;
  final FavoriteAppBarActionsState favoriteAppBarActions;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onFavoriteSortSelected;
  final VoidCallback onFavoriteCreateFolderPressed;
  final VoidCallback onFavoriteModeTogglePressed;

  @override
  Widget build(BuildContext context) {
    if (currentIndex == 1) {
      return FavoriteAppBarActions(
        state: favoriteAppBarActions,
        onSortSelected: onFavoriteSortSelected,
        onCreateFolderPressed: onFavoriteCreateFolderPressed,
        onModeTogglePressed: onFavoriteModeTogglePressed,
      );
    }
    return DiscoverAppBarActions(
      isActiveTab: currentIndex == 0,
      morphProgress: discoverSearchMorphProgress,
      forceInAppBar: forceDiscoverSearchInAppBar,
      onOpenSearch: onOpenSearch,
    );
  }
}
