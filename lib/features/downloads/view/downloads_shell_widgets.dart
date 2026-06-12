import 'package:flutter/foundation.dart';
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
    required this.onToggleSelectionMode,
  });

  final TabController tabController;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onToggleSelectionMode;

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
        AnimatedBuilder(
          animation: tabController.animation!,
          builder: (context, child) {
            final animationValue = tabController.animation!.value;
            final downloadedTabIsActive = tabController.indexIsChanging
                ? tabController.index == 1
                : tabController.index == 1
                ? animationValue >= 1 - precisionErrorTolerance
                : animationValue > precisionErrorTolerance;
            return downloadedTabIsActive ? child! : const SizedBox.shrink();
          },
          child: IconButton(
            tooltip: selectionMode
                ? l10n(context).commonClose
                : l10n(context).downloadsActionSelect,
            icon: Icon(
              selectionMode ? Icons.close_rounded : Icons.checklist_rounded,
            ),
            onPressed: onToggleSelectionMode,
          ),
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
