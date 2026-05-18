import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:hazuki/features/favorite/favorite.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/search_box_outline.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'package:hazuki/features/discover/discover.dart';

import 'home_app_bar_actions.dart';
import 'home_bottom_navigation.dart';
import 'home_content_stack.dart';
import 'package:hazuki/features/home/view/home_drawer.dart';

class HomeScaffoldShell extends StatelessWidget {
  const HomeScaffoldShell({
    super.key,
    required this.scaffoldKey,
    required this.currentIndex,
    required this.discoverSearchMorphProgress,
    required this.usePinnedDiscoverSearch,
    required this.dailyRecommendationState,
    required this.favoriteAppBarActions,
    required this.isLogged,
    required this.profileLoading,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.showCheckInActions,
    required this.checkInBusy,
    required this.checkedInToday,
    required this.favoriteActionsBinding,
    required this.authVersion,
    required this.allowDiscoverInitialLoad,
    required this.hideDiscoverLoadingUntilAllowed,
    required this.onWillPop,
    required this.onOpenSearch,
    required this.onFavoriteSortSelected,
    required this.onFavoriteCreateFolderPressed,
    required this.onFavoriteModeTogglePressed,
    required this.onProfileTap,
    required this.onCheckInPressed,
    required this.onOpenHistory,
    required this.onOpenCategories,
    required this.onOpenRanking,
    required this.onOpenDownloads,
    required this.onOpenSettings,
    required this.onOpenLines,
    this.selectedDrawerDestination,
    required this.onDiscoverSearchMorphProgressChanged,
    required this.onFavoriteAppBarActionsChanged,
    required this.onRequestLogin,
    required this.onDestinationSelected,
    required this.comicDetailPageBuilder,
    required this.favoriteComicTapHandler,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final int currentIndex;
  final double discoverSearchMorphProgress;
  final bool usePinnedDiscoverSearch;
  final DiscoverDailyRecommendationState dailyRecommendationState;
  final FavoriteAppBarActionsState favoriteAppBarActions;
  final bool isLogged;
  final bool profileLoading;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool showCheckInActions;
  final bool checkInBusy;
  final bool checkedInToday;
  final FavoritePageActionsBinding favoriteActionsBinding;
  final int authVersion;
  final bool allowDiscoverInitialLoad;
  final bool hideDiscoverLoadingUntilAllowed;
  final Future<bool> Function() onWillPop;
  final VoidCallback onOpenSearch;
  final ValueChanged<String> onFavoriteSortSelected;
  final VoidCallback onFavoriteCreateFolderPressed;
  final VoidCallback onFavoriteModeTogglePressed;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLines;
  final HomeDrawerDestination? selectedDrawerDestination;
  final ValueChanged<double> onDiscoverSearchMorphProgressChanged;
  final ValueChanged<FavoriteAppBarActionsState> onFavoriteAppBarActionsChanged;
  final Future<void> Function() onRequestLogin;
  final ValueChanged<int> onDestinationSelected;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final FavoriteComicTapHandler favoriteComicTapHandler;

  @override
  Widget build(BuildContext context) {
    final homeContent = HomeContentStack(
      currentIndex: currentIndex,
      discoverChild: DiscoverPage(
        comicDetailPageBuilder: comicDetailPageBuilder,
        usePinnedSearchInAppBar: true,
        dailyRecommendationState: dailyRecommendationState,
        allowInitialLoad: allowDiscoverInitialLoad,
        hideLoadingUntilInitialLoadAllowed: hideDiscoverLoadingUntilAllowed,
        onSearchMorphProgressChanged: onDiscoverSearchMorphProgressChanged,
        onSearchTap: onOpenSearch,
      ),
      favoriteChild: FavoritePage(
        actionsBinding: favoriteActionsBinding,
        authVersion: authVersion,
        onAppBarActionsChanged: onFavoriteAppBarActionsChanged,
        onRequestLogin: onRequestLogin,
        onComicTap: favoriteComicTapHandler,
      ),
    );
    final mobileDrawerContent = HomeDrawerContent(
      isLogged: isLogged,
      profileLoading: profileLoading,
      avatarUrl: avatarUrl,
      username: username,
      autoCheckInEnabled: autoCheckInEnabled,
      showCheckInActions: showCheckInActions,
      checkInBusy: checkInBusy,
      checkedInToday: checkedInToday,
      onProfileTap:
          sl<HazukiSourceService>().sourceMeta?.supportsAccount == true
          ? _closeDrawerRouteThen(context, onProfileTap)
          : null,
      onCheckInPressed: _closeDrawerRouteThen(context, onCheckInPressed),
      onOpenHistory: onOpenHistory,
      onOpenCategories: onOpenCategories,
      onOpenRanking: onOpenRanking,
      onOpenDownloads: onOpenDownloads,
      onOpenSettings: onOpenSettings,
      onOpenLines: onOpenLines,
      selectedDestination: selectedDrawerDestination,
    );
    final body = Platform.isWindows
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: resolveHomeWindowsSidebarWidth(context),
                child: HomeWindowsSidebar(
                  isLogged: isLogged,
                  profileLoading: profileLoading,
                  avatarUrl: avatarUrl,
                  username: username,
                  currentIndex: currentIndex,
                  selectedDestination: selectedDrawerDestination,
                  onProfileTap:
                      sl<HazukiSourceService>().sourceMeta?.supportsAccount ==
                          true
                      ? onProfileTap
                      : null,
                  onSelectDiscover: () => onDestinationSelected(0),
                  onSelectFavorite: () => onDestinationSelected(1),
                  onOpenHistory: onOpenHistory,
                  onOpenCategories: onOpenCategories,
                  onOpenRanking: onOpenRanking,
                  onOpenDownloads: onOpenDownloads,
                  onOpenLines: onOpenLines,
                  onOpenSettings: onOpenSettings,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(22),
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: HazukiDesktopPageContainer(child: homeContent),
                  ),
                ),
              ),
            ],
          )
        : HazukiDesktopPageContainer(child: homeContent);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(
          onWillPop().then((shouldPop) {
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          }),
        );
      },
      child: WindowsComicDetailHost(
        child: Scaffold(
          key: scaffoldKey,
          extendBody: true,
          appBar: hazukiFrostedAppBar(
            context: context,
            leading: Platform.isWindows
                ? null
                : _HomeAppBarProfileButton(
                    avatarUrl: avatarUrl,
                    profileLoading: profileLoading,
                    username: username,
                    onPressed: () {
                      _openProfileDrawer(context, mobileDrawerContent);
                    },
                  ),
            automaticallyImplyLeading: false,
            title: _HomeAppBarSearchBox(
              onOpenSearch: onOpenSearch,
              maxWidth: Platform.isWindows ? 320 : null,
            ),
            titleSpacing: Platform.isWindows ? null : 4,
            centerTitle: Platform.isWindows,
            enableBlur: currentIndex != 0 && currentIndex != 1,
            actions: [
              HomeAppBarActions(
                currentIndex: currentIndex,
                discoverSearchMorphProgress: discoverSearchMorphProgress,
                forceDiscoverSearchInAppBar: usePinnedDiscoverSearch,
                favoriteAppBarActions: favoriteAppBarActions,
                onOpenSearch: onOpenSearch,
                onFavoriteSortSelected: onFavoriteSortSelected,
                onFavoriteCreateFolderPressed: onFavoriteCreateFolderPressed,
                onFavoriteModeTogglePressed: onFavoriteModeTogglePressed,
              ),
            ],
          ),
          drawerEnableOpenDragGesture: false,
          drawer: null,
          body: body,
          bottomNavigationBar: Platform.isWindows
              ? null
              : HomeBottomNavigation(
                  currentIndex: currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  discoverLabel: l10n(context).homeTabDiscover,
                  favoriteLabel: l10n(context).homeTabFavorite,
                ),
        ),
      ),
    );
  }

  VoidCallback? _closeDrawerRouteThen(
    BuildContext context,
    VoidCallback? next,
  ) {
    if (next == null) {
      return null;
    }
    return () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 240));
        if (!context.mounted) {
          return;
        }
        next();
      }());
    };
  }

  void _openProfileDrawer(BuildContext context, Widget drawerContent) {
    Navigator.of(context).push(
      _HomeProfileDrawerRoute(
        drawerWidth: resolveHomeDrawerWidth(context),
        drawerColor:
            DrawerTheme.of(context).backgroundColor ??
            Theme.of(context).drawerTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        drawerContent: drawerContent,
      ),
    );
  }
}

class _HomeAppBarProfileButton extends StatelessWidget {
  const _HomeAppBarProfileButton({
    required this.avatarUrl,
    required this.profileLoading,
    required this.username,
    required this.onPressed,
  });

  final String? avatarUrl;
  final bool profileLoading;
  final String username;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: profileLoading ? l10n(context).commonLoading : username,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: HomeProfileAvatar(
            avatarUrl: avatarUrl,
            loading: profileLoading,
            size: 38,
            borderWidth: 2,
            borderColor: colorScheme.primary.withValues(alpha: 0.72),
            backgroundColor: colorScheme.surfaceContainerHigh,
            heroEnabled: true,
          ),
        ),
      ),
    );
  }
}

class _HomeAppBarSearchBox extends StatelessWidget {
  const _HomeAppBarSearchBox({required this.onOpenSearch, this.maxWidth});

  final VoidCallback onOpenSearch;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchBox = Material(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: hazukiSearchBoxOutlineSide(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpenSearch,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n(context).homeSearchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (maxWidth == null) {
      return searchBox;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: searchBox,
    );
  }
}

class _HomeProfileDrawerRoute extends PageRoute<void> {
  _HomeProfileDrawerRoute({
    required this.drawerWidth,
    required this.drawerColor,
    required this.drawerContent,
  });

  final double drawerWidth;
  final Color drawerColor;
  final Widget drawerContent;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.28);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator?.removeRoute(this);
    });
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Drawer(
        width: drawerWidth,
        backgroundColor: drawerColor,
        child: drawerContent,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
