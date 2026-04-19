import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class DownloadsActionDock extends StatelessWidget {
  const DownloadsActionDock({
    super.key,
    required this.selectionMode,
    required this.scanning,
    required this.selectedCount,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
    required this.onScanDownloaded,
  });

  final bool selectionMode;
  final bool scanning;
  final int selectedCount;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: selectionMode
                  ? _DownloadsActionButton(
                      key: const ValueKey<String>('downloads_delete_action'),
                      tooltip: l10n(context).comicDetailDelete,
                      icon: Icons.delete_outline_rounded,
                      accentColor: colorScheme.errorContainer,
                      iconColor: colorScheme.onErrorContainer,
                      onPressed: selectedCount > 0 ? onDeleteSelected : null,
                    )
                  : _DownloadsActionButton(
                      key: const ValueKey<String>('downloads_scan_action'),
                      tooltip: l10n(context).downloadsScanTooltip,
                      icon: Icons.manage_search_rounded,
                      accentColor: colorScheme.primaryContainer,
                      iconColor: colorScheme.onPrimaryContainer,
                      onPressed: scanning ? null : onScanDownloaded,
                      busy: scanning,
                    ),
            ),
            Container(
              width: 34,
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: colorScheme.outlineVariant,
            ),
            _DownloadsActionButton(
              tooltip: selectionMode
                  ? l10n(context).commonClose
                  : l10n(context).downloadsActionSelect,
              icon: selectionMode
                  ? Icons.close_rounded
                  : Icons.checklist_rounded,
              accentColor: selectionMode
                  ? colorScheme.secondaryContainer
                  : colorScheme.tertiaryContainer,
              iconColor: selectionMode
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onTertiaryContainer,
              onPressed: onToggleSelectionMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsActionButton extends StatelessWidget {
  const _DownloadsActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.accentColor,
    required this.iconColor,
    required this.onPressed,
    this.busy = false,
  });

  final String tooltip;
  final IconData icon;
  final Color accentColor;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: accentColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: busy
                  ? SizedBox(
                      key: const ValueKey<String>('downloads_action_busy'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(icon, key: ValueKey<IconData>(icon), color: iconColor),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: tooltip, child: button);
  }
}
