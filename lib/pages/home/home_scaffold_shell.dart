import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/l10n.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import '../discover/discover.dart';
import '../favorite/favorite.dart';
import '../favorite_page.dart';
import 'home_app_bar_actions.dart';
import 'home_bottom_navigation.dart';
import 'home_content_stack.dart';
import 'home_drawer.dart';

class HomeScaffoldShell extends StatelessWidget {
  const HomeScaffoldShell({
    super.key,
    required this.scaffoldKey,
    required this.currentIndex,
    required this.discoverSearchMorphProgress,
    required this.favoriteAppBarActions,
    required this.isLogged,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.checkInBusy,
    required this.checkedInToday,
    required this.favoritePageKey,
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
    required this.onDiscoverSearchMorphProgressChanged,
    required this.onFavoriteAppBarActionsChanged,
    required this.onRequestLogin,
    required this.onDestinationSelected,
    required this.comicDetailPageBuilder,
    required this.favoriteDetailRouteBuilder,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final int currentIndex;
  final double discoverSearchMorphProgress;
  final FavoriteAppBarActionsState favoriteAppBarActions;
  final bool isLogged;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool checkInBusy;
  final bool checkedInToday;
  final GlobalKey<FavoritePageState> favoritePageKey;
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
  final ValueChanged<double> onDiscoverSearchMorphProgressChanged;
  final ValueChanged<FavoriteAppBarActionsState> onFavoriteAppBarActionsChanged;
  final Future<void> Function() onRequestLogin;
  final ValueChanged<int> onDestinationSelected;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final FavoriteDetailRouteBuilder favoriteDetailRouteBuilder;

  @override
  Widget build(BuildContext context) {
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
      child: Scaffold(
        key: scaffoldKey,
        appBar: hazukiFrostedAppBar(
          context: context,
          title: const Text('Hazuki'),
          actions: [
            HomeAppBarActions(
              currentIndex: currentIndex,
              discoverSearchMorphProgress: discoverSearchMorphProgress,
              favoriteAppBarActions: favoriteAppBarActions,
              onOpenSearch: onOpenSearch,
              onFavoriteSortSelected: onFavoriteSortSelected,
              onFavoriteCreateFolderPressed: onFavoriteCreateFolderPressed,
              onFavoriteModeTogglePressed: onFavoriteModeTogglePressed,
            ),
          ],
        ),
        drawer: HomeDrawer(
          isLogged: isLogged,
          avatarUrl: avatarUrl,
          username: username,
          autoCheckInEnabled: autoCheckInEnabled,
          checkInBusy: checkInBusy,
          checkedInToday: checkedInToday,
          onProfileTap:
              HazukiSourceService.instance.sourceMeta?.supportsAccount == true
              ? onProfileTap
              : null,
          onCheckInPressed: onCheckInPressed,
          onOpenHistory: onOpenHistory,
          onOpenCategories: onOpenCategories,
          onOpenRanking: onOpenRanking,
          onOpenDownloads: onOpenDownloads,
          onOpenSettings: onOpenSettings,
          onOpenLines: onOpenLines,
        ),
        body: HazukiDesktopPageContainer(
          child: HomeContentStack(
            currentIndex: currentIndex,
            discoverChild: DiscoverPage(
              comicDetailPageBuilder: comicDetailPageBuilder,
              allowInitialLoad: allowDiscoverInitialLoad,
              hideLoadingUntilInitialLoadAllowed:
                  hideDiscoverLoadingUntilAllowed,
              onSearchMorphProgressChanged:
                  onDiscoverSearchMorphProgressChanged,
            ),
            favoriteChild: FavoritePage(
              key: favoritePageKey,
              authVersion: authVersion,
              onAppBarActionsChanged: onFavoriteAppBarActionsChanged,
              onRequestLogin: onRequestLogin,
              detailRouteBuilder: favoriteDetailRouteBuilder,
            ),
          ),
        ),
        bottomNavigationBar: HomeBottomNavigation(
          currentIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          discoverLabel: l10n(context).homeTabDiscover,
          favoriteLabel: l10n(context).homeTabFavorite,
        ),
      ),
    );
  }
}
