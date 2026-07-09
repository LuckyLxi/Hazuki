import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_content.dart';

export 'package:hazuki/features/home/support/home_sidebar_models.dart';
export 'package:hazuki/features/home/view/home_drawer_content.dart';
export 'package:hazuki/features/home/view/home_profile_avatar.dart';
export 'package:hazuki/features/home/view/home_source_switch_pill_button.dart';
export 'package:hazuki/features/home/view/home_windows_sidebar.dart';

double resolveHomeDrawerWidth(BuildContext context) {
  final themedWidth = DrawerTheme.of(context).width;
  if (themedWidth != null) {
    return themedWidth;
  }
  final screenWidth = MediaQuery.sizeOf(context).width;
  return math.min(304.0, math.max(0.0, screenWidth - 56.0));
}

double resolveHomeWindowsSidebarWidth(BuildContext context) => 80.0;

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.isLogged,
    required this.profileLoading,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.showCheckInActions,
    required this.checkInBusy,
    required this.checkedInToday,
    required this.onProfileTap,
    required this.onCheckInPressed,
    required this.onSwitchSourcePressed,
    required this.onOpenHistory,
    required this.onOpenCategories,
    required this.onOpenRanking,
    required this.onOpenDownloads,
    required this.onOpenSettings,
    required this.onOpenLines,
    this.activeSourceKey = '',
    this.selectedDestination,
  });

  final bool isLogged;
  final bool profileLoading;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool showCheckInActions;
  final bool checkInBusy;
  final bool checkedInToday;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback? onSwitchSourcePressed;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLines;
  final String activeSourceKey;
  final HomeDrawerDestination? selectedDestination;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: resolveHomeDrawerWidth(context),
      child: HomeDrawerContent(
        profile: HomeSidebarProfileState(
          isLogged: isLogged,
          profileLoading: profileLoading,
          avatarUrl: avatarUrl,
          username: username,
          autoCheckInEnabled: autoCheckInEnabled,
          showCheckInActions: showCheckInActions,
          checkInBusy: checkInBusy,
          checkedInToday: checkedInToday,
        ),
        actions: HomeSidebarActions(
          onProfileTap: onProfileTap,
          onCheckInPressed: onCheckInPressed,
          onSwitchSourcePressed: onSwitchSourcePressed,
          onOpenHistory: onOpenHistory,
          onOpenCategories: onOpenCategories,
          onOpenRanking: onOpenRanking,
          onOpenDownloads: onOpenDownloads,
          onOpenSettings: onOpenSettings,
          onOpenLines: onOpenLines,
        ),
        activeSourceKey: activeSourceKey,
        selectedDestination: selectedDestination,
      ),
    );
  }
}
