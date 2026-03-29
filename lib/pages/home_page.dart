import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app.dart';
import 'home/home.dart';

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
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;
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
    final navigation = HomeNavigationActions(
      context: context,
      appearanceSettings: widget.appearanceSettings,
      onAppearanceChanged: widget.onAppearanceChanged,
      locale: widget.locale,
      onLocaleChanged: widget.onLocaleChanged,
    );

    return AnimatedBuilder(
      animation: _coordinator,
      builder: (context, _) {
        final isLogged = _coordinator.isLogged;
        final profileFlow = _coordinator.createProfileFlow(
          context,
          isMounted: () => mounted,
        );

        return HomeScaffoldShell(
          scaffoldKey: _coordinator.scaffoldKey,
          currentIndex: _coordinator.currentIndex,
          discoverSearchMorphProgress: _coordinator.discoverSearchMorphProgress,
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
            unawaited(navigation.openHistory());
          },
          onOpenCategories: () {
            unawaited(navigation.openCategories());
          },
          onOpenRanking: () {
            unawaited(navigation.openRanking());
          },
          onOpenDownloads: () {
            unawaited(navigation.openDownloads());
          },
          onOpenSettings: () {
            unawaited(() async {
              await navigation.openSettings();
              if (!context.mounted) {
                return;
              }
              await _coordinator.loadOtherSettings(context);
            }());
          },
          onOpenLines: () {
            unawaited(navigation.openLines());
          },
          onDiscoverSearchMorphProgressChanged:
              _coordinator.handleDiscoverSearchMorphProgressChanged,
          onFavoriteAppBarActionsChanged:
              _coordinator.handleFavoriteAppBarActionsChanged,
          onRequestLogin: profileFlow.showLoginDialog,
          onDestinationSelected: (index) {
            unawaited(_coordinator.handleDestinationSelected(index));
          },
          comicDetailPageBuilder: navigation.buildComicDetailPage,
          favoriteDetailRouteBuilder: navigation.buildFavoriteDetailRoute,
        );
      },
    );
  }
}
