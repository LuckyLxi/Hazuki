import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

import 'home_source_switch_pill_button.dart';
import 'home_windows_source_picker.dart';

/// 侧栏内容宽度达到该值时切换为带文字标签的展开布局。
const homeWindowsSidebarExpandedMinWidth = 160.0;

class HomeWindowsSidebar extends StatefulWidget {
  const HomeWindowsSidebar({
    super.key,
    required this.profile,
    required this.actions,
    required this.currentIndex,
    required this.selectedDestination,
    this.unreadAnnouncementCount = 0,
    this.sourceSwitchService,
    this.onSourceSwitched,
  });

  final HomeSidebarProfileState profile;
  final HomeSidebarActions actions;
  final int currentIndex;
  final HomeDrawerDestination? selectedDestination;
  final int unreadAnnouncementCount;
  final SourceRuntimeGateway? sourceSwitchService;
  final Future<void> Function()? onSourceSwitched;

  @override
  State<HomeWindowsSidebar> createState() => _HomeWindowsSidebarState();
}

class _HomeWindowsSidebarState extends State<HomeWindowsSidebar> {
  bool _sourcePickerOpen = false;

  HomeSidebarProfileState get profile => widget.profile;
  HomeSidebarActions get actions => widget.actions;
  int get currentIndex => widget.currentIndex;
  HomeDrawerDestination? get selectedDestination => widget.selectedDestination;
  int get unreadAnnouncementCount => widget.unreadAnnouncementCount;

  Future<void> _openSourcePicker(BuildContext buttonContext) async {
    if (_sourcePickerOpen) return;
    _sourcePickerOpen = true;
    try {
      final sidebarBox = context.findRenderObject()! as RenderBox;
      final buttonBox = buttonContext.findRenderObject()! as RenderBox;
      await showHomeWindowsSourcePicker(
        context,
        sidebarBounds: sidebarBox.localToGlobal(Offset.zero) & sidebarBox.size,
        anchorBounds: buttonBox.localToGlobal(Offset.zero) & buttonBox.size,
        sourceService: widget.sourceSwitchService!,
        onSourceSwitched: widget.onSourceSwitched,
      );
    } catch (error) {
      if (mounted) {
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).labSourceAccountSwitchFailed('$error'),
            isError: true,
          ),
        );
      }
    } finally {
      _sourcePickerOpen = false;
    }
  }

  String _activeSourceName() {
    final gateway = widget.sourceSwitchService;
    final key = gateway?.activeSourceKey ?? '';
    if (gateway == null || key.isEmpty) return key;
    for (final source in gateway.allowedSources) {
      if (source.normalizedKey == key) return source.name;
    }
    return key;
  }

  // 展开态顶部的当前源卡片，点击行为与窄轨道的切换按钮一致。
  Widget _buildSourceCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = _activeSourceName().trim();
    final badge = name.isEmpty
        ? '?'
        : name.characters.take(2).toString().toUpperCase();
    return Builder(
      builder: (buttonContext) => Material(
        key: const ValueKey('windows-sidebar-source-switch'),
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.sourceSwitchService == null
              ? actions.onSwitchSourcePressed
              : () => unawaited(_openSourcePicker(buttonContext)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    badge,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n(context).homeSourceSwitchCurrent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 展开态底部的账号行：头像、用户名与签到状态。
  Widget _buildProfileRow(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.profileLoading
        ? l10n(context).commonLoading
        : profile.username;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: actions.onProfileTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              HomeProfileAvatar(
                avatarUrl: profile.avatarUrl,
                loading: profile.profileLoading,
                size: 36,
                borderRadius: BorderRadius.circular(18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (profile.isLogged && profile.checkedInToday)
                      Text(
                        l10n(context).homeCheckInDone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 展开态导航项：图标加文字的胶囊行，选中配色与窄轨道一致。
  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    VoidCallback? onTap,
    int badgeCount = 0,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.86)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, color: foreground, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? foreground : colorScheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Badge(label: Text(badgeCount > 99 ? '99+' : '$badgeCount')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, HomeSidebarItem item) {
    return _buildNavTile(
      context,
      icon: item.icon,
      label: item.title(context),
      selected: item.isSelected(selectedDestination),
      onTap: item.resolveTap(actions),
      badgeCount: item.destination == HomeDrawerDestination.announcements
          ? unreadAnnouncementCount
          : 0,
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSourceCard(context),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNavTile(
                  context,
                  icon: Icons.explore_outlined,
                  label: l10n(context).homeTabDiscover,
                  selected: selectedDestination == null && currentIndex == 0,
                  onTap: actions.onSelectDiscover,
                ),
                _buildNavTile(
                  context,
                  icon: Icons.favorite_border,
                  label: l10n(context).homeTabFavorite,
                  selected: selectedDestination == null && currentIndex == 1,
                  onTap: actions.onSelectFavorite,
                ),
                for (final item in homeSidebarPrimaryItems)
                  _buildItemTile(context, item),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    l10n(context).homeSidebarMoreGroup,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                for (final item in homeSidebarSecondaryItems)
                  _buildItemTile(context, item),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildProfileRow(context),
      ],
    );
  }

  Widget _buildSourceSwitchButton(BuildContext context) => Builder(
    builder: (buttonContext) => HomeSourceSwitchPillButton(
      key: const ValueKey('windows-sidebar-source-switch'),
      useLiquidGlass: false,
      onPressed: widget.sourceSwitchService == null
          ? actions.onSwitchSourcePressed
          : () => unawaited(_openSourcePicker(buttonContext)),
    ),
  );

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
    final button = _buildButton(
      context,
      icon: item.icon,
      tooltip: item.title(context),
      selected: item.isSelected(selectedDestination),
      onTap: item.resolveTap(actions),
    );
    if (item.destination != HomeDrawerDestination.announcements ||
        unreadAnnouncementCount <= 0) {
      return button;
    }
    return Badge(
      alignment: const AlignmentDirectional(0.58, -0.52),
      label: Text(
        unreadAnnouncementCount > 99 ? '99+' : '$unreadAnnouncementCount',
      ),
      child: button,
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
            // 宽度足够时展开为带文字的导航，否则保留原有的图标轨道。
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= homeWindowsSidebarExpandedMinWidth
                  ? _buildExpanded(context)
                  : _buildRail(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAvatar(context),
          const SizedBox(height: 10),
          _buildSourceSwitchButton(context),
          const SizedBox(height: 18),
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
    );
  }
}
