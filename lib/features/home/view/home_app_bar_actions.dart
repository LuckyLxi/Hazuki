import 'package:flutter/material.dart';

import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';

import 'favorite_app_bar_actions.dart';

class HomeAppBarActions extends StatelessWidget {
  const HomeAppBarActions({
    super.key,
    required this.currentIndex,
    required this.discoverSearchMorphProgress,
    required this.forceDiscoverSearchInAppBar,
    required this.favoriteAppBarActions,
    this.sourcePlugins,
    required this.onOpenSearch,
    required this.onFavoriteSortSelected,
    required this.onFavoriteCreateFolderPressed,
    required this.onFavoriteModeTogglePressed,
  });

  final int currentIndex;
  final double discoverSearchMorphProgress;
  final bool forceDiscoverSearchInAppBar;
  final FavoriteAppBarActionsState favoriteAppBarActions;
  final SourcePluginGateway? sourcePlugins;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onFavoriteSortSelected;
  final VoidCallback onFavoriteCreateFolderPressed;
  final VoidCallback onFavoriteModeTogglePressed;

  @override
  Widget build(BuildContext context) {
    if (currentIndex == 1) {
      return FavoriteAppBarActions(
        state: favoriteAppBarActions,
        sourcePlugins: sourcePlugins,
        onSortSelected: onFavoriteSortSelected,
        onCreateFolderPressed: onFavoriteCreateFolderPressed,
        onModeTogglePressed: onFavoriteModeTogglePressed,
      );
    }
    return const SizedBox.shrink();
  }
}
