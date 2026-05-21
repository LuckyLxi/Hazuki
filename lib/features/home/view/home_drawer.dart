import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
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

class HomeProfileAvatar extends StatelessWidget {
  const HomeProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.loading,
    required this.size,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
    this.heroEnabled = false,
    this.borderRadius,
  });

  final String? avatarUrl;
  final bool loading;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool heroEnabled;
  final BorderRadius? borderRadius;

  bool get _useRoundedRectangle => borderRadius != null;

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = (avatarUrl ?? '').trim();
    final radius = size / 2;
    final contentSize = (size - borderWidth * 2).clamp(0.0, size).toDouble();
    final borderRadius = this.borderRadius;
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
        color:
            backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        border: borderWidth > 0
            ? Border.all(
                color:
                    borderColor ?? Theme.of(context).colorScheme.outlineVariant,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        child: loading || resolvedAvatarUrl.isEmpty
            ? HazukiShimmerLoading(width: contentSize, height: contentSize)
            : _useRoundedRectangle
            ? HazukiCachedImage(
                url: resolvedAvatarUrl,
                width: contentSize,
                height: contentSize,
                fit: BoxFit.cover,
                error: HazukiShimmerLoading(
                  width: contentSize,
                  height: contentSize,
                ),
                loading: HazukiShimmerLoading(
                  width: contentSize,
                  height: contentSize,
                ),
                ignoreNoImageMode: true,
              )
            : HazukiCachedCircleAvatar(
                radius: contentSize / 2,
                url: resolvedAvatarUrl,
                useShimmerFallback: true,
                ignoreNoImageMode: true,
              ),
      ),
    );

    return HeroMode(
      enabled: heroEnabled,
      child: Hero(
        tag: homeProfileAvatarHeroTag,
        child: Material(
          type: MaterialType.transparency,
          shape: borderRadius == null
              ? CircleBorder(side: _heroBorderSide(context))
              : RoundedRectangleBorder(
                  borderRadius: borderRadius,
                  side: _heroBorderSide(context),
                ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: radius * 2, height: radius * 2, child: avatar),
        ),
      ),
    );
  }

  BorderSide _heroBorderSide(BuildContext context) {
    if (borderWidth <= 0) {
      return BorderSide.none;
    }
    return BorderSide(
      color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
      width: borderWidth,
    );
  }
}

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
  final HomeDrawerDestination? selectedDestination;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: resolveHomeDrawerWidth(context),
      // 移除原有的 SafeArea，让头部背景延伸到状态栏
      child: HomeDrawerContent(
        isLogged: isLogged,
        profileLoading: profileLoading,
        avatarUrl: avatarUrl,
        username: username,
        autoCheckInEnabled: autoCheckInEnabled,
        showCheckInActions: showCheckInActions,
        checkInBusy: checkInBusy,
        checkedInToday: checkedInToday,
        onProfileTap: onProfileTap,
        onCheckInPressed: onCheckInPressed,
        onSwitchSourcePressed: onSwitchSourcePressed,
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
    required this.profileLoading,
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
  final bool profileLoading;
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
    final tooltip = profileLoading ? l10n(context).commonLoading : username;
    return Tooltip(
      message: tooltip,
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
          child: HomeProfileAvatar(
            avatarUrl: avatarUrl,
            loading: profileLoading,
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
    required this.profileLoading,
    required this.avatarUrl,
    required this.username,
    required this.autoCheckInEnabled,
    required this.showCheckInActions,
    required this.checkInBusy,
    required this.checkedInToday,
    this.onProfileTap,
    this.onCheckInPressed,
    this.onSwitchSourcePressed,
    this.onOpenHistory,
    this.onOpenCategories,
    this.onOpenRanking,
    this.onOpenDownloads,
    this.onOpenSettings,
    this.onOpenLines,
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
    final displayUsername = profileLoading
        ? l10n(context).commonLoading
        : username;
    final resolvedAvatarUrl = (avatarUrl ?? '').trim();
    final visualStateKey =
        '${sl<HazukiSourceService>().activeSourceKey}|$resolvedAvatarUrl|$profileLoading';
    final usernameStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    );

    final darkModeDim = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : Colors.transparent;
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
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.74, 1.0],
                      ).createShader(bounds);
                    },
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Transform.scale(
                          scale: 1.08,
                          child: profileLoading || resolvedAvatarUrl.isEmpty
                              ? ColoredBox(
                                  color: colorScheme.surfaceContainerHigh,
                                )
                              : HazukiCachedImage(
                                  key: ValueKey('drawer-bg-$visualStateKey'),
                                  url: resolvedAvatarUrl,
                                  fit: BoxFit.cover,
                                  ignoreNoImageMode: true,
                                ),
                        ),
                      ),
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
                          Colors.transparent,
                          Colors.transparent,
                          drawerBackground.withValues(
                            alpha: isDark ? 0.48 : 0.42,
                          ),
                          drawerBackground,
                        ],
                        stops: const [0.0, 0.56, 0.82, 1.0],
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
                            drawerBackground.withValues(alpha: 0.04),
                            drawerBackground.withValues(
                              alpha: isDark ? 0.18 : 0.14,
                            ),
                            drawerBackground.withValues(
                              alpha: isDark ? 0.48 : 0.42,
                            ),
                            drawerBackground,
                          ],
                          stops: const [0.0, 0.50, 0.66, 0.80, 0.91, 1.0],
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
                        child: HomeProfileAvatar(
                          key: ValueKey('drawer-avatar-$visualStateKey'),
                          avatarUrl: avatarUrl,
                          loading: profileLoading,
                          size: 72,
                          heroEnabled: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayUsername,
                              style: usernameStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Transform.translate(
                            offset: const Offset(0, 2),
                            child: _HomeSourceSwitchPillButton(
                              onPressed: onSwitchSourcePressed,
                            ),
                          ),
                        ],
                      ),
                      if (showCheckInActions &&
                          isLogged &&
                          !profileLoading &&
                          !autoCheckInEnabled) ...[
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
              physics: const NeverScrollableScrollPhysics(),
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

class _HomeSourceSwitchPillButton extends StatelessWidget {
  const _HomeSourceSwitchPillButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.10 : 0.08,
    );
    final borderColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.13 : 0.10,
    );

    return Tooltip(
      message: l10n(context).homeSourceSwitchTooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: background,
            shape: StadiumBorder(side: BorderSide(color: borderColor)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 32,
                height: 22,
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: onPressed == null
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
