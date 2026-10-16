import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';

Color _pillBorderColor(bool isDark) => (isDark ? Colors.white : Colors.black)
    .withValues(alpha: isDark ? 0.13 : 0.10);

class HomeSourceSwitchMorphButton extends StatelessWidget {
  const HomeSourceSwitchMorphButton({
    super.key,
    required this.onPressed,
    required this.dialogOpen,
  });

  final Future<void> Function(FavoriteFoldersMorphOrigin) onPressed;
  final bool dialogOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      ignoring: dialogOpen,
      child: Opacity(
        opacity: dialogOpen ? 0 : 1,
        child: Builder(
          builder: (buttonContext) => HomeSourceSwitchPillButton(
            onPressed: () {
              if (dialogOpen) return;
              final box = buttonContext.findRenderObject()! as RenderBox;
              unawaited(
                onPressed(
                  FavoriteFoldersMorphOrigin(
                    rect: box.localToGlobal(Offset.zero) & box.size,
                    backgroundColor: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: isDark ? 0.10 : 0.08),
                    foregroundColor: colors.onSurfaceVariant,
                    icon: Icons.swap_horiz_rounded,
                    borderRadius: 11,
                    iconSize: 16,
                    borderColor: _pillBorderColor(isDark),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomeSourceSwitchPillButton extends StatelessWidget {
  const HomeSourceSwitchPillButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.10 : 0.08,
    );
    final borderColor = _pillBorderColor(isDark);

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
