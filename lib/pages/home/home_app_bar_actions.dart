import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/l10n.dart';
import '../../models/hazuki_models.dart';
import '../favorite/favorite.dart';

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

  Widget _buildDiscoverSearchAction(BuildContext context) {
    final showCollapsedSearch =
        currentIndex == 0 &&
        (forceDiscoverSearchInAppBar || discoverSearchMorphProgress >= 0.96);
    return HeroMode(
      enabled: showCollapsedSearch,
      child: Hero(
        tag: discoverSearchHeroTag,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: showCollapsedSearch ? 180 : 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: showCollapsedSearch
                    ? Offset.zero
                    : const Offset(-0.08, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: showCollapsedSearch ? 1 : 0.94,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: showCollapsedSearch ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !showCollapsedSearch,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onOpenSearch,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n(context).homeSearchHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteActionGroup(BuildContext context) {
    final isLocalMode =
        favoriteAppBarActions.currentMode == FavoritePageMode.local;
    return Row(
      key: const ValueKey<String>('favorite-appbar-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (favoriteAppBarActions.showModeToggle)
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
                key: ValueKey<FavoritePageMode>(
                  favoriteAppBarActions.currentMode,
                ),
                onPressed: onFavoriteModeTogglePressed,
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
        if (favoriteAppBarActions.showSort)
          PopupMenuButton<String>(
            tooltip: l10n(context).homeSortTooltip,
            initialValue: favoriteAppBarActions.currentSortOrder,
            onSelected: onFavoriteSortSelected,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: 'mr',
                checked: favoriteAppBarActions.currentSortOrder == 'mr',
                child: Text(l10n(context).homeFavoriteSortByFavoriteTime),
              ),
              CheckedPopupMenuItem<String>(
                value: 'mp',
                checked: favoriteAppBarActions.currentSortOrder == 'mp',
                child: Text(l10n(context).homeFavoriteSortByUpdateTime),
              ),
            ],
            icon: const Icon(Icons.sort_rounded),
          ),
        if (favoriteAppBarActions.showCreateFolder)
          IconButton(
            tooltip: l10n(context).homeCreateFavoriteFolder,
            onPressed: onFavoriteCreateFolderPressed,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoverActions = Row(
      key: const ValueKey<String>('discover-appbar-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDiscoverSearchAction(context),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width:
              (forceDiscoverSearchInAppBar ||
                  discoverSearchMorphProgress >= 0.96)
              ? 12
              : 0,
        ),
      ],
    );

    final actionsChild = currentIndex == 1
        ? _buildFavoriteActionGroup(context)
        : discoverActions;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerRight,
          clipBehavior: Clip.none,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0.24, 0),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: actionsChild,
    );
  }
}
