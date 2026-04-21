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
  });

  final TabController tabController;
  final bool selectionMode;
  final int selectedCount;

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
    );
  }
}

class DownloadsScanButton extends StatelessWidget {
  const DownloadsScanButton({
    super.key,
    required this.scanning,
    required this.onPressed,
  });

  final bool scanning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'downloads_scan_button',
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
            selectionMode ? 'selection_$selectedCount' : 'title_default',
          ),
        ),
      ),
    );
  }
}
