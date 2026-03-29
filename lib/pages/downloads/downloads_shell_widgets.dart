import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/widgets.dart';

class DownloadsPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DownloadsPageAppBar({
    super.key,
    required this.tabController,
    required this.selectionMode,
    required this.selectedCount,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
  });

  final TabController tabController;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 46);

  @override
  Widget build(BuildContext context) {
    return hazukiFrostedAppBar(
      context: context,
      title: _DownloadsAnimatedAppBarTitle(
        selectionMode: selectionMode,
        selectedCount: selectedCount,
        tabIndex: tabController.index,
      ),
      bottom: TabBar(
        controller: tabController,
        tabs: [
          Tab(text: l10n(context).downloadsTabOngoing),
          Tab(text: l10n(context).downloadsTabDownloaded),
        ],
      ),
      actions: [
        _DownloadsSelectionActions(
          tabIndex: tabController.index,
          selectionMode: selectionMode,
          onToggleSelectionMode: onToggleSelectionMode,
          onDeleteSelected: onDeleteSelected,
        ),
      ],
    );
  }
}

class DownloadsScanButton extends StatelessWidget {
  const DownloadsScanButton({
    super.key,
    required this.ready,
    required this.visible,
    required this.scanning,
    required this.onPressed,
  });

  final bool ready;
  final bool visible;
  final bool scanning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!ready || !visible) {
      return const SizedBox.shrink(key: ValueKey<String>('scan_hidden'));
    }
    return FloatingActionButton(
      tooltip: l10n(context).downloadsScanTooltip,
      onPressed: scanning ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: scanning
            ? SizedBox(
                key: const ValueKey<String>('scan_loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              )
            : const Icon(
                Icons.manage_search_rounded,
                key: ValueKey<String>('scan_icon'),
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
            selectionMode
                ? 'selection_${selectedCount}_$tabIndex'
                : 'title_$tabIndex',
          ),
        ),
      ),
    );
  }
}

class _DownloadsSelectionActions extends StatelessWidget {
  const _DownloadsSelectionActions({
    required this.tabIndex,
    required this.selectionMode,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
  });

  final int tabIndex;
  final bool selectionMode;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            axis: Axis.horizontal,
            axisAlignment: 1,
            sizeFactor: animation,
            child: child,
          ),
        );
      },
      child: tabIndex == 1
          ? Padding(
              key: const ValueKey<String>('download_actions_visible'),
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: kMinInteractiveDimension,
                    child: IconButton(
                      tooltip: selectionMode
                          ? l10n(context).commonClose
                          : l10n(context).downloadsActionSelect,
                      onPressed: onToggleSelectionMode,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.86,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          selectionMode ? Icons.close : Icons.checklist_rounded,
                          key: ValueKey<String>(
                            selectionMode
                                ? 'selection_close_icon'
                                : 'selection_checklist_icon',
                          ),
                        ),
                      ),
                    ),
                  ),
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.centerRight,
                      widthFactor: selectionMode ? 1 : 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOutCubic,
                        opacity: selectionMode ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !selectionMode,
                          child: SizedBox.square(
                            dimension: kMinInteractiveDimension,
                            child: IconButton(
                              tooltip: l10n(context).comicDetailDelete,
                              onPressed: onDeleteSelected,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(
              key: ValueKey<String>('download_actions_hidden'),
            ),
    );
  }
}
