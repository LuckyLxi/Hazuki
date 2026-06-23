import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/features/home/view/home_source_switch_pill_button.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

class HomeDrawerContent extends StatelessWidget {
  const HomeDrawerContent({
    super.key,
    required this.profile,
    required this.actions,
    this.selectedDestination,
  });

  final HomeSidebarProfileState profile;
  final HomeSidebarActions actions;
  final HomeDrawerDestination? selectedDestination;

  Widget _buildMenuItem(BuildContext context, HomeSidebarItem item) {
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
    final displayUsername = profile.profileLoading
        ? l10n(context).commonLoading
        : profile.username;
    final resolvedAvatarUrl = (profile.avatarUrl ?? '').trim();
    final visualStateKey =
        '${sl<SourceImageGateway>().activeSourceKey}|$resolvedAvatarUrl|'
        '${profile.profileLoading}|$displayUsername';
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
                          child:
                              profile.profileLoading ||
                                  resolvedAvatarUrl.isEmpty
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
                        onTap: actions.onProfileTap,
                        borderRadius: BorderRadius.circular(40),
                        child: HomeProfileAvatar(
                          key: ValueKey('drawer-avatar-$visualStateKey'),
                          avatarUrl: profile.avatarUrl,
                          loading: profile.profileLoading,
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
                            child: HomeSourceSwitchPillButton(
                              onPressed: actions.onSwitchSourcePressed,
                            ),
                          ),
                        ],
                      ),
                      if (profile.showCheckInActions &&
                          profile.isLogged &&
                          !profile.profileLoading &&
                          !profile.autoCheckInEnabled) ...[
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
                              'checkin-${profile.checkInBusy
                                  ? 'busy'
                                  : profile.checkedInToday
                                  ? 'done'
                                  : 'idle'}',
                            ),
                            onPressed:
                                (profile.checkInBusy || profile.checkedInToday)
                                ? null
                                : actions.onCheckInPressed,
                            icon: profile.checkInBusy
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  )
                                : Icon(
                                    profile.checkedInToday
                                        ? Icons.check_circle_outline
                                        : Icons.event_available_outlined,
                                  ),
                            label: Text(
                              profile.checkInBusy
                                  ? l10n(context).homeCheckInInProgress
                                  : profile.checkedInToday
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
                for (final item in homeSidebarPrimaryItems)
                  _buildMenuItem(context, item),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                for (final item in homeSidebarSecondaryItems)
                  _buildMenuItem(context, item),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
