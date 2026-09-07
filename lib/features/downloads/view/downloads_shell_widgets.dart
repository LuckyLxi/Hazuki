import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/widgets.dart';

class DownloadsPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DownloadsPageAppBar({
    super.key,
    required this.tabController,
    required this.selectionMode,
    required this.selectedCount,
    required this.allSelected,
    required this.onToggleSelectionMode,
    required this.onSelectAll,
    required this.onPauseAll,
    required this.onResumeAll,
  });

  final TabController tabController;
  final bool selectionMode;
  final int selectedCount;

  /// 当前筛选组内所有漫画是否已全选
  final bool allSelected;
  final VoidCallback onToggleSelectionMode;

  /// 全选回调
  final VoidCallback onSelectAll;

  /// 全部暂停回调
  final VoidCallback onPauseAll;

  /// 全部开始回调
  final VoidCallback onResumeAll;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 46);

  @override
  Widget build(BuildContext context) {
    return hazukiFrostedAppBar(
      context: context,
      enableBlur: false,
      title: _DownloadsAnimatedAppBarTitle(
        selectionMode: selectionMode,
        selectedCount: selectedCount,
        tabIndex: tabController.index,
      ),
      actions: [
        _DownloadsAnimatedAppBarActions(
          tabController: tabController,
          selectionMode: selectionMode,
          allSelected: allSelected,
          onToggleSelectionMode: onToggleSelectionMode,
          onSelectAll: onSelectAll,
          onPauseAll: onPauseAll,
          onResumeAll: onResumeAll,
        ),
      ],
      bottom: TabBar(
        controller: tabController,
        tabs: [
          Tab(text: l10n(context).downloadsTabOngoing),
          Tab(text: l10n(context).downloadsTabDownloaded),
        ],
      ),
    );
  }
}

class _DownloadsAnimatedAppBarActions extends StatelessWidget {
  const _DownloadsAnimatedAppBarActions({
    required this.tabController,
    required this.selectionMode,
    required this.allSelected,
    required this.onToggleSelectionMode,
    required this.onSelectAll,
    required this.onPauseAll,
    required this.onResumeAll,
  });

  final TabController tabController;
  final bool selectionMode;
  final bool allSelected;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController.animation!,
      builder: (context, child) {
        final downloadedVisibility = tabController.animation!.value.clamp(
          0.0,
          1.0,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DownloadsTabActionTransition(
              key: const ValueKey<String>(
                'downloads_ongoing_actions_transition',
              ),
              visibility: 1 - downloadedVisibility,
              interactive: downloadedVisibility < 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n(context).downloadsActionResumeAll,
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: onResumeAll,
                  ),
                  IconButton(
                    tooltip: l10n(context).downloadsActionPauseAll,
                    icon: const Icon(Icons.pause_rounded),
                    onPressed: onPauseAll,
                  ),
                ],
              ),
            ),
            _DownloadsTabActionTransition(
              key: const ValueKey<String>(
                'downloads_downloaded_actions_transition',
              ),
              visibility: downloadedVisibility,
              interactive: downloadedVisibility >= 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selectionMode ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: selectionMode ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: ExcludeSemantics(
                        excluding: !selectionMode,
                        child: ExcludeFocus(
                          excluding: !selectionMode,
                          child: IgnorePointer(
                            ignoring: !selectionMode,
                            child: IconButton(
                              key: const ValueKey<String>(
                                'downloads_select_all_button',
                              ),
                              tooltip: l10n(context).commonSelectAll,
                              icon: Icon(
                                allSelected ? Icons.done_all : Icons.select_all,
                              ),
                              onPressed: onSelectAll,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: selectionMode
                        ? l10n(context).commonClose
                        : l10n(context).downloadsActionSelect,
                    icon: Icon(
                      selectionMode
                          ? Icons.close_rounded
                          : Icons.checklist_rounded,
                    ),
                    onPressed: onToggleSelectionMode,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadsTabActionTransition extends StatelessWidget {
  const _DownloadsTabActionTransition({
    super.key,
    required this.visibility,
    required this.interactive,
    required this.child,
  });

  final double visibility;
  final bool interactive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerRight,
        widthFactor: visibility,
        child: Opacity(
          opacity: visibility,
          child: Transform.translate(
            offset: Offset(8 * (1 - visibility), 0),
            child: ExcludeSemantics(
              excluding: !interactive,
              child: ExcludeFocus(
                excluding: !interactive,
                child: IgnorePointer(ignoring: !interactive, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadsScanButton extends StatelessWidget {
  const DownloadsScanButton({
    super.key,
    required this.selectionMode,
    required this.scanning,
    required this.selectedCount,
    required this.onDeleteSelected,
    required this.onScanDownloaded,
  });

  final bool selectionMode;
  final bool scanning;
  final int selectedCount;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('downloads_action_button_animation'),
      tween: Tween<double>(end: selectionMode ? 1 : 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return FloatingActionButton(
          heroTag: 'downloads_scan_button',
          tooltip: selectionMode
              ? l10n(context).comicDetailDelete
              : l10n(context).downloadsScanTooltip,
          backgroundColor: Color.lerp(
            colorScheme.primaryContainer,
            colorScheme.errorContainer,
            value,
          ),
          foregroundColor: Color.lerp(
            colorScheme.onPrimaryContainer,
            colorScheme.onErrorContainer,
            value,
          ),
          onPressed: selectionMode
              ? (selectedCount > 0 ? onDeleteSelected : null)
              : (scanning ? null : onScanDownloaded),
          child: AnimatedSwitcher(
            key: const ValueKey<String>('downloads_action_icon_switcher'),
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.65,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: selectionMode
                ? const Icon(
                    Icons.delete_outline_rounded,
                    key: ValueKey<String>('delete_icon'),
                  )
                : scanning
                ? SizedBox(
                    key: const ValueKey<String>('scan_loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.manage_search_rounded,
                    key: ValueKey<String>('scan_icon'),
                  ),
          ),
        );
      },
    );
  }
}

class DownloadsBatchGroupButton extends StatelessWidget {
  const DownloadsBatchGroupButton({
    super.key,
    required this.visible,
    required this.enabled,
    required this.onPressed,
  });

  final bool visible;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      key: const ValueKey<String>('downloads_batch_group_button_animation'),
      offset: visible ? Offset.zero : const Offset(1.6, 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.82,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton(
              key: const ValueKey<String>('downloads_batch_group_button'),
              heroTag: 'downloads_batch_group_button',
              tooltip: l10n(context).downloadsBatchGroupAction,
              onPressed: enabled ? onPressed : null,
              child: const Icon(Icons.folder_copy_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadsAnimatedAppBarTitle extends StatelessWidget {
  const _DownloadsAnimatedAppBarTitle({
    required this.selectionMode,
    required this.selectedCount,
    required this.tabIndex,
  });

  final bool selectionMode;
  final int selectedCount;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          selectionMode
              ? l10n(context).downloadsSelectionTitle('$selectedCount')
              : l10n(context).downloadsTitle,
          key: ValueKey<String>(
            selectionMode ? 'selection_$selectedCount' : 'title_default',
          ),
        ),
      ),
    );
  }
}
