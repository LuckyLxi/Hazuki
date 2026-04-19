import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/home/home.dart';

class HazukiHomePage extends StatefulWidget {
  const HazukiHomePage({
    super.key,
    this.initialTabIndex = 0,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
    this.allowDiscoverInitialLoad = true,
    this.hideDiscoverLoadingUntilAllowed = false,
    this.refreshTick = 0,
  });

  final int initialTabIndex;
  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;
  final bool allowDiscoverInitialLoad;
  final bool hideDiscoverLoadingUntilAllowed;
  final int refreshTick;

  @override
  State<HazukiHomePage> createState() => _HazukiHomePageState();
}

class _HazukiHomePageState extends State<HazukiHomePage> {
  late final HomeCoordinator _coordinator;
  HomeDrawerDestination? _selectedDrawerDestination;

  @override
  void initState() {
    super.initState();
    _coordinator = HomeCoordinator(initialTabIndex: widget.initialTabIndex);
    _coordinator.start(context);
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HazukiHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _coordinator.handleWidgetUpdate(
      context,
      oldLocale: oldWidget.locale,
      newLocale: widget.locale,
      oldRefreshTick: oldWidget.refreshTick,
      newRefreshTick: widget.refreshTick,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _coordinator,
      builder: (context, _) {
        final isLogged = _coordinator.isLogged;
        final profileFlow = _coordinator.createProfileFlow(
          context,
          isMounted: () => mounted,
        );
        final navigation = HomeNavigationActions(
          context: context,
          scaffoldKey: _coordinator.scaffoldKey,
          drawerTransitionContent: HomeDrawerContent(
            isLogged: isLogged,
            avatarUrl: _coordinator.avatarUrl,
            username: _coordinator.username,
            autoCheckInEnabled: _coordinator.autoCheckInEnabled,
            checkInBusy: _coordinator.checkInBusy,
            checkedInToday: _coordinator.checkedInToday,
            selectedDestination: _selectedDrawerDestination,
          ),
          appearanceSettings: widget.appearanceSettings,
          onAppearanceChanged: widget.onAppearanceChanged,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        );

        return HomeScaffoldShell(
          scaffoldKey: _coordinator.scaffoldKey,
          currentIndex: _coordinator.currentIndex,
          discoverSearchMorphProgress: _coordinator.discoverSearchMorphProgress,
          usePinnedDiscoverSearch:
              _coordinator.dailyRecommendationState.hasRecommendations,
          dailyRecommendationState: _coordinator.dailyRecommendationState,
          favoriteAppBarActions: _coordinator.favoriteAppBarActions,
          isLogged: isLogged,
          avatarUrl: _coordinator.avatarUrl,
          username: _coordinator.username,
          autoCheckInEnabled: _coordinator.autoCheckInEnabled,
          checkInBusy: _coordinator.checkInBusy,
          checkedInToday: _coordinator.checkedInToday,
          favoritePageKey: _coordinator.favoritePageKey,
          authVersion: _coordinator.authVersion,
          allowDiscoverInitialLoad: widget.allowDiscoverInitialLoad,
          hideDiscoverLoadingUntilAllowed:
              widget.hideDiscoverLoadingUntilAllowed,
          onWillPop: () => _coordinator.handleWillPop(context),
          onOpenSearch: () {
            unawaited(navigation.openSearch());
          },
          onFavoriteSortSelected: (order) {
            unawaited(_coordinator.changeFavoriteSortOrder(order));
          },
          onFavoriteCreateFolderPressed: () {
            unawaited(_coordinator.createFavoriteFolder());
          },
          onFavoriteModeTogglePressed: () {
            unawaited(_coordinator.toggleFavoriteMode());
          },
          onProfileTap: () {
            if (isLogged) {
              unawaited(profileFlow.showAvatarCard());
            } else {
              unawaited(profileFlow.showLoginDialog());
            }
          },
          onCheckInPressed: () {
            unawaited(
              _coordinator.performCheckIn(
                context,
                triggeredAutomatically: false,
              ),
            );
          },
          onOpenHistory: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.history;
            });
            unawaited(navigation.openHistory());
          },
          onOpenCategories: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.categories;
            });
            unawaited(navigation.openCategories());
          },
          onOpenRanking: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.ranking;
            });
            unawaited(navigation.openRanking());
          },
          onOpenDownloads: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.downloads;
            });
            unawaited(navigation.openDownloads());
          },
          onOpenSettings: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.settings;
            });
            unawaited(() async {
              await navigation.openSettings();
              if (!context.mounted) {
                return;
              }
              await _coordinator.loadOtherSettings(context);
            }());
          },
          onOpenLines: () {
            setState(() {
              _selectedDrawerDestination = HomeDrawerDestination.lines;
            });
            unawaited(navigation.openLines());
          },
          selectedDrawerDestination: _selectedDrawerDestination,
          onDiscoverSearchMorphProgressChanged:
              _coordinator.handleDiscoverSearchMorphProgressChanged,
          onFavoriteAppBarActionsChanged:
              _coordinator.handleFavoriteAppBarActionsChanged,
          onRequestLogin: profileFlow.showLoginDialog,
          onDestinationSelected: (index) {
            unawaited(_coordinator.handleDestinationSelected(index));
          },
          comicDetailPageBuilder: navigation.buildComicDetailPage,
          favoriteComicTapHandler: navigation.openFavoriteDetail,
        );
      },
    );
  }
}
