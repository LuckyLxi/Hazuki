import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/widgets.dart';

enum HomeDrawerDestination {
  history,
  categories,
  ranking,
  downloads,
  lines,
  settings,
}

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
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.checkInBusy,
    required this.checkedInToday,
    required this.onProfileTap,
    required this.onCheckInPressed,
    required this.onOpenHistory,
    required this.onOpenCategories,
    required this.onOpenRanking,
    required this.onOpenDownloads,
    required this.onOpenSettings,
    required this.onOpenLines,
    this.selectedDestination,
  });

  final bool isLogged;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool checkInBusy;
  final bool checkedInToday;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLines;
  final HomeDrawerDestination? selectedDestination;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: resolveHomeDrawerWidth(context),
      // 移除原有的 SafeArea，让头部背景延伸到状态栏
      child: HomeDrawerContent(
        isLogged: isLogged,
        avatarUrl: avatarUrl,
        username: username,
        autoCheckInEnabled: autoCheckInEnabled,
        checkInBusy: checkInBusy,
        checkedInToday: checkedInToday,
        onProfileTap: onProfileTap,
        onCheckInPressed: onCheckInPressed,
        onOpenHistory: onOpenHistory,
        onOpenCategories: onOpenCategories,
        onOpenRanking: onOpenRanking,
        onOpenDownloads: onOpenDownloads,
        onOpenSettings: onOpenSettings,
        onOpenLines: onOpenLines,
        selectedDestination: selectedDestination,
      ),
    );
  }
}

class HomeWindowsSidebar extends StatelessWidget {
  const HomeWindowsSidebar({
    super.key,
    required this.isLogged,
    required this.avatarUrl,
    required this.username,
    required this.currentIndex,
    required this.selectedDestination,
    this.onProfileTap,
    this.onSelectDiscover,
    this.onSelectFavorite,
    this.onOpenHistory,
    this.onOpenCategories,
    this.onOpenRanking,
    this.onOpenDownloads,
    this.onOpenLines,
    this.onOpenSettings,
  });

  final bool isLogged;
  final String? avatarUrl;
  final String username;
  final int currentIndex;
  final HomeDrawerDestination? selectedDestination;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSelectDiscover;
  final VoidCallback? onSelectFavorite;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenRanking;
  final VoidCallback? onOpenDownloads;
  final VoidCallback? onOpenLines;
  final VoidCallback? onOpenSettings;

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: username,
      child: InkWell(
        onTap: onProfileTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
          ),
          child: (!isLogged && (avatarUrl ?? '').trim().isEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/avatars/guest_avatar.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: HazukiCachedImage(
                    url: avatarUrl ?? '',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    error: Icon(
                      Icons.person,
                      size: 28,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    loading: Icon(
                      Icons.person,
                      size: 28,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    ignoreNoImageMode: true,
                  ),
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
                  onTap: onSelectDiscover,
                ),
                _buildButton(
                  context,
                  icon: Icons.favorite_border,
                  tooltip: l10n(context).homeTabFavorite,
                  selected: selectedDestination == null && currentIndex == 1,
                  onTap: onSelectFavorite,
                ),
                const SizedBox(height: 16),
                _buildButton(
                  context,
                  icon: Icons.history_outlined,
                  tooltip: l10n(context).homeMenuHistory,
                  selected:
                      selectedDestination == HomeDrawerDestination.history,
                  onTap: onOpenHistory,
                ),
                _buildButton(
                  context,
                  icon: Icons.category_outlined,
                  tooltip: l10n(context).homeMenuCategories,
                  selected:
                      selectedDestination == HomeDrawerDestination.categories,
                  onTap: onOpenCategories,
                ),
                _buildButton(
                  context,
                  icon: Icons.leaderboard_outlined,
                  tooltip: l10n(context).homeMenuRanking,
                  selected:
                      selectedDestination == HomeDrawerDestination.ranking,
                  onTap: onOpenRanking,
                ),
                _buildButton(
                  context,
                  icon: Icons.download_outlined,
                  tooltip: l10n(context).homeMenuDownloads,
                  selected:
                      selectedDestination == HomeDrawerDestination.downloads,
                  onTap: onOpenDownloads,
                ),
                const SizedBox(height: 16),
                _buildButton(
                  context,
                  icon: Icons.alt_route_outlined,
                  tooltip: l10n(context).homeMenuLines,
                  selected: selectedDestination == HomeDrawerDestination.lines,
                  onTap: onOpenLines,
                ),
                _buildButton(
                  context,
                  icon: Icons.settings_outlined,
                  tooltip: l10n(context).settingsTitle,
                  selected:
                      selectedDestination == HomeDrawerDestination.settings,
                  onTap: onOpenSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeDrawerContent extends StatelessWidget {
  const HomeDrawerContent({
    super.key,
    required this.isLogged,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.checkInBusy,
    required this.checkedInToday,
    this.onProfileTap,
    this.onCheckInPressed,
    this.onOpenHistory,
    this.onOpenCategories,
    this.onOpenRanking,
    this.onOpenDownloads,
    this.onOpenSettings,
    this.onOpenLines,
    this.selectedDestination,
  });

  final bool isLogged;
  final String? avatarUrl;
  final String username;
  final bool autoCheckInEnabled;
  final bool checkInBusy;
  final bool checkedInToday;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCheckInPressed;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenRanking;
  final VoidCallback? onOpenDownloads;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenLines;
  final HomeDrawerDestination? selectedDestination;

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool selected,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedForeground = colorScheme.onSecondaryContainer;

    // 移除所有背景效果，仅保留文字和图标的变色反馈
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? selectedForeground : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? selectedForeground : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        selected: selected,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final drawerBackground =
        DrawerTheme.of(context).backgroundColor ??
        Theme.of(context).drawerTheme.backgroundColor ??
        colorScheme.surface;
    final textTheme = Theme.of(context).textTheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topScrim = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.22);
    final midScrim = isDark
        ? colorScheme.surface.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.12);
    final bottomScrim = isDark
        ? drawerBackground.withValues(alpha: 0.55)
        : colorScheme.surface.withValues(alpha: 0.7);
    final darkModeDim = isDark
        ? Colors.black.withValues(alpha: 0.30)
        : Colors.transparent;
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.34);
    final transparentHighlightColor = highlightColor.withValues(alpha: 0);
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.white.withValues(alpha: 0.42);

    return ColoredBox(
      color: drawerBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: drawerBackground)),
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                    child: (!isLogged && (avatarUrl ?? '').trim().isEmpty)
                        ? Image.asset(
                            'assets/avatars/guest_avatar.png',
                            fit: BoxFit.cover,
                          )
                        : HazukiCachedImage(
                            url: avatarUrl ?? '',
                            fit: BoxFit.cover,
                            ignoreNoImageMode: true,
                          ),
                  ),
                ),
                Positioned.fill(child: ColoredBox(color: darkModeDim)),
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          topScrim,
                          midScrim,
                          bottomScrim.withValues(alpha: isDark ? 0.58 : 0.8),
                          bottomScrim,
                        ],
                        stops: const [0.0, 0.3, 0.76, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.78, -0.92),
                        radius: 1.18,
                        colors: [highlightColor, transparentHighlightColor],
                        stops: const [0.0, 0.62],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: outlineColor, width: 1),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            drawerBackground.withValues(alpha: 0.06),
                            drawerBackground.withValues(
                              alpha: isDark ? 0.22 : 0.18,
                            ),
                            drawerBackground.withValues(
                              alpha: isDark ? 0.52 : 0.46,
                            ),
                            drawerBackground,
                          ],
                          stops: const [0.0, 0.48, 0.64, 0.78, 0.90, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: onProfileTap,
                        borderRadius: BorderRadius.circular(40),
                        child: (!isLogged && (avatarUrl ?? '').trim().isEmpty)
                            ? const CircleAvatar(
                                radius: 36,
                                backgroundImage: AssetImage(
                                  'assets/avatars/guest_avatar.png',
                                ),
                              )
                            : HazukiCachedCircleAvatar(
                                radius: 36,
                                url: avatarUrl ?? '',
                                fallbackIcon: const Icon(
                                  Icons.person,
                                  size: 36,
                                ),
                                ignoreNoImageMode: true,
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isLogged && !autoCheckInEnabled) ...[
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.92,
                                end: 1,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: FilledButton.tonalIcon(
                            key: ValueKey(
                              'checkin-${checkInBusy
                                  ? 'busy'
                                  : checkedInToday
                                  ? 'done'
                                  : 'idle'}',
                            ),
                            onPressed: (checkInBusy || checkedInToday)
                                ? null
                                : onCheckInPressed,
                            icon: checkInBusy
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  )
                                : Icon(
                                    checkedInToday
                                        ? Icons.check_circle_outline
                                        : Icons.event_available_outlined,
                                  ),
                            label: Text(
                              checkInBusy
                                  ? l10n(context).homeCheckInInProgress
                                  : checkedInToday
                                  ? l10n(context).homeCheckInDone
                                  : l10n(context).homeCheckInAction,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 40),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 0,
                bottom: bottomPadding + 12,
              ),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.history_outlined,
                  title: l10n(context).homeMenuHistory,
                  selected:
                      selectedDestination == HomeDrawerDestination.history,
                  onTap: onOpenHistory,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.category_outlined,
                  title: l10n(context).homeMenuCategories,
                  selected:
                      selectedDestination == HomeDrawerDestination.categories,
                  onTap: onOpenCategories,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.leaderboard_outlined,
                  title: l10n(context).homeMenuRanking,
                  selected:
                      selectedDestination == HomeDrawerDestination.ranking,
                  onTap: onOpenRanking,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.download_outlined,
                  title: l10n(context).homeMenuDownloads,
                  selected:
                      selectedDestination == HomeDrawerDestination.downloads,
                  onTap: onOpenDownloads,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.alt_route_outlined,
                  title: l10n(context).homeMenuLines,
                  selected: selectedDestination == HomeDrawerDestination.lines,
                  onTap: onOpenLines,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: l10n(context).settingsTitle,
                  selected:
                      selectedDestination == HomeDrawerDestination.settings,
                  onTap: onOpenSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
