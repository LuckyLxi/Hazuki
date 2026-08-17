import 'package:flutter/material.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_profile_header.dart';

class HomeDrawerContent extends StatelessWidget {
  const HomeDrawerContent({
    super.key,
    required this.profile,
    required this.actions,
    required this.activeSourceKey,
    this.selectedDestination,
  });

  final HomeSidebarProfileState profile;
  final HomeSidebarActions actions;
  final String activeSourceKey;
  final HomeDrawerDestination? selectedDestination;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final drawerBackground =
        DrawerTheme.of(context).backgroundColor ??
        Theme.of(context).drawerTheme.backgroundColor ??
        colorScheme.surface;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: drawerBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeDrawerProfileHeader(
            profile: profile,
            actions: actions,
            activeSourceKey: activeSourceKey,
            backgroundColor: drawerBackground,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _HomeDrawerMenu(
              actions: actions,
              selectedDestination: selectedDestination,
              bottomPadding: bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeDrawerMenu extends StatelessWidget {
  const _HomeDrawerMenu({
    required this.actions,
    required this.selectedDestination,
    required this.bottomPadding,
  });

  final HomeSidebarActions actions;
  final HomeDrawerDestination? selectedDestination;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 0,
        bottom: bottomPadding + 12,
      ),
      children: [
        for (final item in homeSidebarPrimaryItems)
          _HomeDrawerMenuItem(
            item: item,
            actions: actions,
            selectedDestination: selectedDestination,
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(),
        ),
        for (final item in homeSidebarSecondaryItems)
          _HomeDrawerMenuItem(
            item: item,
            actions: actions,
            selectedDestination: selectedDestination,
          ),
      ],
    );
  }
}

class _HomeDrawerMenuItem extends StatelessWidget {
  const _HomeDrawerMenuItem({
    required this.item,
    required this.actions,
    required this.selectedDestination,
  });

  final HomeSidebarItem item;
  final HomeSidebarActions actions;
  final HomeDrawerDestination? selectedDestination;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedForeground = colorScheme.onSecondaryContainer;
    final selected = item.isSelected(selectedDestination);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: ListTile(
          leading: Icon(
            item.icon,
            color: selected ? selectedForeground : colorScheme.onSurfaceVariant,
          ),
          title: Text(
            item.title(context),
            style: TextStyle(
              color: selected ? selectedForeground : colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
          selected: selected,
          onTap: item.resolveTap(actions),
        ),
      ),
    );
  }
}
