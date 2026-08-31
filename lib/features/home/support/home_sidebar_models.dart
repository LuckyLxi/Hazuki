import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

enum HomeDrawerDestination {
  history,
  categories,
  ranking,
  downloads,
  announcements,
  lines,
  settings,
}

class HomeSidebarProfileState {
  const HomeSidebarProfileState({
    required this.isLogged,
    required this.profileLoading,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.showCheckInActions,
    required this.checkInBusy,
    required this.checkedInToday,
  });

  final bool isLogged;
  final bool profileLoading;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool showCheckInActions;
  final bool checkInBusy;
  final bool checkedInToday;
}

class HomeSidebarActions {
  const HomeSidebarActions({
    this.onProfileTap,
    this.onCheckInPressed,
    this.onSwitchSourcePressed,
    this.onSelectDiscover,
    this.onSelectFavorite,
    this.onOpenHistory,
    this.onOpenCategories,
    this.onOpenRanking,
    this.onOpenDownloads,
    this.onOpenAnnouncements,
    this.onOpenSettings,
    this.onOpenLines,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback? onSwitchSourcePressed;
  final VoidCallback? onSelectDiscover;
  final VoidCallback? onSelectFavorite;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenRanking;
  final VoidCallback? onOpenDownloads;
  final VoidCallback? onOpenAnnouncements;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenLines;

  VoidCallback? resolveDestinationTap(HomeDrawerDestination destination) {
    return switch (destination) {
      HomeDrawerDestination.history => onOpenHistory,
      HomeDrawerDestination.categories => onOpenCategories,
      HomeDrawerDestination.ranking => onOpenRanking,
      HomeDrawerDestination.downloads => onOpenDownloads,
      HomeDrawerDestination.announcements => onOpenAnnouncements,
      HomeDrawerDestination.lines => onOpenLines,
      HomeDrawerDestination.settings => onOpenSettings,
    };
  }
}

class HomeSidebarItem {
  const HomeSidebarItem({required this.destination, required this.icon});

  final HomeDrawerDestination destination;
  final IconData icon;

  String title(BuildContext context) {
    return switch (destination) {
      HomeDrawerDestination.history => l10n(context).homeMenuHistory,
      HomeDrawerDestination.categories => l10n(context).homeMenuCategories,
      HomeDrawerDestination.ranking => l10n(context).homeMenuRanking,
      HomeDrawerDestination.downloads => l10n(context).homeMenuDownloads,
      HomeDrawerDestination.announcements => l10n(context).announcementTitle,
      HomeDrawerDestination.lines => l10n(context).homeMenuLines,
      HomeDrawerDestination.settings => l10n(context).settingsTitle,
    };
  }

  bool isSelected(HomeDrawerDestination? selectedDestination) {
    return selectedDestination == destination;
  }

  VoidCallback? resolveTap(HomeSidebarActions actions) {
    return actions.resolveDestinationTap(destination);
  }
}

const homeSidebarPrimaryItems = <HomeSidebarItem>[
  HomeSidebarItem(
    destination: HomeDrawerDestination.history,
    icon: Icons.history_outlined,
  ),
  HomeSidebarItem(
    destination: HomeDrawerDestination.categories,
    icon: Icons.category_outlined,
  ),
  HomeSidebarItem(
    destination: HomeDrawerDestination.ranking,
    icon: Icons.leaderboard_outlined,
  ),
  HomeSidebarItem(
    destination: HomeDrawerDestination.downloads,
    icon: Icons.download_outlined,
  ),
];

const homeSidebarSecondaryItems = <HomeSidebarItem>[
  HomeSidebarItem(
    destination: HomeDrawerDestination.announcements,
    icon: Icons.notifications_none_rounded,
  ),
  HomeSidebarItem(
    destination: HomeDrawerDestination.lines,
    icon: Icons.alt_route_outlined,
  ),
  HomeSidebarItem(
    destination: HomeDrawerDestination.settings,
    icon: Icons.settings_outlined,
  ),
];
