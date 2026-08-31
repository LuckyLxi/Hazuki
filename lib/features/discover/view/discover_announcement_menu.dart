import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';

enum DiscoverAnnouncementMenuAction { hideCurrent, hideAll }

Future<DiscoverAnnouncementMenuAction?> showDiscoverAnnouncementMenu({
  required BuildContext context,
  required BuildContext cardContext,
  required Offset globalPosition,
}) async {
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  final cardBox = cardContext.findRenderObject() as RenderBox?;
  if (overlay == null || cardBox == null) {
    return null;
  }

  final fingerOffset = overlay.globalToLocal(globalPosition);
  final cardOffset = cardBox.localToGlobal(Offset.zero, ancestor: overlay);
  const menuWidth = 212.0;
  const menuHeight = 97.0;
  const gap = 8.0;
  const screenPadding = 8.0;
  final mediaPadding = MediaQuery.of(context).padding;
  final minX = screenPadding;
  final maxX = overlay.size.width - menuWidth - screenPadding;
  final minY = screenPadding + mediaPadding.top;
  final maxY =
      overlay.size.height - mediaPadding.bottom - menuHeight - screenPadding;
  final cardBottom = cardOffset.dy + cardBox.size.height;
  var dx = (fingerOffset.dx - menuWidth / 2).clamp(minX, maxX);
  final showBelow =
      cardBottom + gap + menuHeight <=
      overlay.size.height - mediaPadding.bottom - screenPadding;
  final dy = showBelow
      ? (cardBottom + gap).clamp(minY, maxY)
      : (cardOffset.dy - gap - menuHeight).clamp(minY, maxY);
  final originX = ((fingerOffset.dx - dx) / menuWidth * 2 - 1).clamp(-1.0, 1.0);
  final strings = AppLocalizations.of(context)!;

  return showGeneralDialog<DiscoverAnnouncementMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final scheme = Theme.of(context).colorScheme;
      return Stack(
        children: [
          Positioned(
            left: dx,
            top: dy,
            width: menuWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withValues(
                        alpha: 0.75,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnnouncementMenuItem(
                          key: const ValueKey<String>(
                            'announcement_menu_hide_current',
                          ),
                          icon: Icons.visibility_off_outlined,
                          label: strings.announcementHideCurrent,
                          onTap: () => Navigator.of(
                            dialogContext,
                          ).pop(DiscoverAnnouncementMenuAction.hideCurrent),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        _AnnouncementMenuItem(
                          key: const ValueKey<String>(
                            'announcement_menu_hide_all',
                          ),
                          icon: Icons.layers_clear_outlined,
                          label: strings.announcementHideAll,
                          danger: true,
                          onTap: () => Navigator.of(
                            dialogContext,
                          ).pop(DiscoverAnnouncementMenuAction.hideAll),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final opacity = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.82,
            end: 1.04,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 68,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.04,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 32,
        ),
      ]).animate(animation);
      return FadeTransition(
        opacity: opacity,
        child: ScaleTransition(
          alignment: Alignment(originX, showBelow ? -1 : 1),
          scale: scale,
          child: child,
        ),
      );
    },
  );
}

class _AnnouncementMenuItem extends StatelessWidget {
  const _AnnouncementMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: danger ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
