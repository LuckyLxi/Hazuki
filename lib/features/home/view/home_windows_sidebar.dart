import 'package:flutter/material.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/l10n/l10n.dart';

class HomeWindowsSidebar extends StatelessWidget {
  const HomeWindowsSidebar({
    super.key,
    required this.profile,
    required this.actions,
    required this.currentIndex,
    required this.selectedDestination,
  });

  final HomeSidebarProfileState profile;
  final HomeSidebarActions actions;
  final int currentIndex;
  final HomeDrawerDestination? selectedDestination;

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tooltip = profile.profileLoading
        ? l10n(context).commonLoading
        : profile.username;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: actions.onProfileTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
          ),
          child: HomeProfileAvatar(
            avatarUrl: profile.avatarUrl,
            loading: profile.profileLoading,
            size: 52,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool selected,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final background = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.86)
        : Colors.transparent;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 44,
              child: Icon(icon, color: foreground, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationButton(BuildContext context, HomeSidebarItem item) {
    return _buildButton(
      context,
      icon: item.icon,
      tooltip: item.title(context),
      selected: item.isSelected(selectedDestination),
      onTap: item.resolveTap(actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final background = colorScheme.surface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.96 : 0.98,
    );

    return Material(
      color: background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.26),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              topPadding + 18,
              12,
              bottomPadding + 18,
            ),
            child: Column(
              children: [
                _buildAvatar(context),
                const SizedBox(height: 28),
                _buildButton(
                  context,
                  icon: Icons.explore_outlined,
                  tooltip: l10n(context).homeTabDiscover,
                  selected: selectedDestination == null && currentIndex == 0,
                  onTap: actions.onSelectDiscover,
                ),
                _buildButton(
                  context,
                  icon: Icons.favorite_border,
                  tooltip: l10n(context).homeTabFavorite,
                  selected: selectedDestination == null && currentIndex == 1,
                  onTap: actions.onSelectFavorite,
                ),
                const SizedBox(height: 16),
                for (final item in homeSidebarPrimaryItems)
                  _buildDestinationButton(context, item),
                const SizedBox(height: 16),
                for (final item in homeSidebarSecondaryItems)
                  _buildDestinationButton(context, item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
