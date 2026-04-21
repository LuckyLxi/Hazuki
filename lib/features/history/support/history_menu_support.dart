import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';

enum HistoryComicMenuAction { copy, favorite, delete }

Future<HistoryComicMenuAction?> showHistoryComicMenu({
  required BuildContext context,
  required BuildContext itemContext,
  required Offset globalPosition,
}) async {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
  final cardBox = itemContext.findRenderObject() as RenderBox?;
  if (overlay == null || cardBox == null) {
    return null;
  }

  final fingerOffset = overlay.globalToLocal(globalPosition);
  final cardOffset = cardBox.localToGlobal(Offset.zero, ancestor: overlay);
  final cardSize = cardBox.size;
  final cardTopDy = cardOffset.dy;
  final cardBottomDy = cardOffset.dy + cardSize.height;

  const menuWidth = 212.0;
  const menuHeight = 174.0;
  const gap = 8.0;
  const screenPadding = 8.0;

  final mediaPadding = MediaQuery.of(context).padding;
  final minX = screenPadding;
  final maxX = overlay.size.width - menuWidth - screenPadding;
  final minY = screenPadding + mediaPadding.top;
  final maxY =
      overlay.size.height - mediaPadding.bottom - menuHeight - screenPadding;

  var dx = fingerOffset.dx - menuWidth / 2;
  dx = dx.clamp(minX, maxX);

  final showBelow =
      cardBottomDy + gap + menuHeight <=
      overlay.size.height - mediaPadding.bottom - screenPadding;
  final dy = showBelow
      ? (cardBottomDy + gap).clamp(minY, maxY)
      : (cardTopDy - gap - menuHeight).clamp(minY, maxY);
  final upwardBottom = overlay.size.height - cardTopDy + gap;

  final originX = ((fingerOffset.dx - dx) / menuWidth * 2 - 1).clamp(-1.0, 1.0);
  final originY = showBelow ? -1.0 : 1.0;

  final strings = AppLocalizations.of(context)!;
  final action = await showGeneralDialog<HistoryComicMenuAction>(
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
            top: showBelow ? dy : null,
            bottom: showBelow ? null : upwardBottom,
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
                        _HistoryMenuItem(
                          icon: Icons.copy,
                          label: strings.historyMenuCopyComicId,
                          onTap: () => Navigator.of(
                            dialogContext,
                          ).pop(HistoryComicMenuAction.copy),
                        ),
                        _HistoryMenuItem(
                          icon: Icons.favorite_border,
                          label: strings.historyMenuToggleFavorite,
                          onTap: () => Navigator.of(
                            dialogContext,
                          ).pop(HistoryComicMenuAction.favorite),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        _HistoryMenuItem(
                          icon: Icons.delete_outline,
                          label: strings.historyMenuDeleteItem,
                          danger: true,
                          onTap: () => Navigator.of(
                            dialogContext,
                          ).pop(HistoryComicMenuAction.delete),
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
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final scaleCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      final opacityCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = Tween<double>(begin: 0.5, end: 1.0).animate(scaleCurve);
      final align = Alignment(originX, originY);
      return FadeTransition(
        opacity: opacityCurve,
        child: ScaleTransition(alignment: align, scale: scale, child: child),
      );
    },
  );

  return action;
}

class _HistoryMenuItem extends StatelessWidget {
  const _HistoryMenuItem({
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
