import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

Color _pillBorderColor(bool isDark) => (isDark ? Colors.white : Colors.black)
    .withValues(alpha: isDark ? 0.13 : 0.10);

class HomeSourceSwitchMorphButton extends StatelessWidget {
  const HomeSourceSwitchMorphButton({
    super.key,
    required this.onPressed,
    required this.dialogOpen,
    this.dialogOpenListenable,
    this.buttonKey,
  });

  final Future<void> Function(FavoriteFoldersMorphOrigin) onPressed;
  final bool dialogOpen;
  final ValueListenable<bool>? dialogOpenListenable;
  final GlobalKey? buttonKey;

  @override
  Widget build(BuildContext context) {
    final listenable = dialogOpenListenable;
    if (listenable == null) return _buildButton(context, dialogOpen);
    // Drawer content is forwarded after the frame. Observe visibility directly
    // so the pill reappears in the same frame that the morph route is removed.
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, open, _) => _buildButton(context, open),
    );
  }

  Widget _buildButton(BuildContext context, bool dialogOpen) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      ignoring: dialogOpen,
      child: Opacity(
        opacity: dialogOpen ? 0 : 1,
        child: Builder(
          builder: (buttonContext) => HomeSourceSwitchPillButton(
            key: buttonKey,
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
                    borderColor: HazukiLiquidGlass.isAvailable
                        ? Colors.transparent
                        : _pillBorderColor(isDark),
                    resolveReturnRect: () {
                      // The source/profile key can replace the entire header.
                      // Use the shell-owned key to find its current button.
                      final currentContext =
                          buttonKey?.currentContext ??
                          (buttonContext.mounted ? buttonContext : null);
                      final currentBox = currentContext?.findRenderObject();
                      if (currentBox is! RenderBox ||
                          !currentBox.attached ||
                          !currentBox.hasSize) {
                        return null;
                      }
                      return currentBox.localToGlobal(Offset.zero) &
                          currentBox.size;
                    },
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
  const HomeSourceSwitchPillButton({
    super.key,
    required this.onPressed,
    this.useLiquidGlass = true,
  });

  final VoidCallback? onPressed;
  final bool useLiquidGlass;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HazukiLiquidGlass.changes,
      builder: (context, _) => _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.10 : 0.08,
    );
    final borderColor = _pillBorderColor(isDark);
    final glass = useLiquidGlass && HazukiLiquidGlass.isAvailable;
    final content = Material(
      color: glass ? Colors.transparent : background,
      shape: StadiumBorder(
        side: BorderSide(color: glass ? Colors.transparent : borderColor),
      ),
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
    );

    return Tooltip(
      message: l10n(context).homeSourceSwitchTooltip,
      child: glass
          ? GlassContainer(
              key: const ValueKey('home-source-switch-liquid-glass-button'),
              useOwnLayer: true,
              quality: HazukiLiquidGlass.navigationQuality,
              shape: const LiquidRoundedRectangle(borderRadius: 11),
              settings: HazukiLiquidGlass.navigationSettings(context),
              child: content,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: content,
              ),
            ),
    );
  }
}
