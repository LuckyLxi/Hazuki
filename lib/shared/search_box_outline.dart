import 'package:flutter/material.dart';

Color hazukiSearchBoxBackgroundColor(
  BuildContext context, {
  double focusProgress = 0,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final clampedProgress = focusProgress.clamp(0.0, 1.0);
  final baseColor = theme.brightness == Brightness.dark
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.10),
          colorScheme.surface,
        )
      : colorScheme.surfaceContainerHighest;
  final focusedColor = Color.alphaBlend(
    colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.10,
    ),
    baseColor,
  );
  return Color.alphaBlend(
    Color.lerp(baseColor, focusedColor, clampedProgress) ?? baseColor,
    Colors.transparent,
  );
}

Color hazukiSearchBoxOutlineColor(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark ? Colors.grey.shade600 : Colors.black;
}

BorderSide hazukiSearchBoxOutlineSide(
  BuildContext context, {
  double focusProgress = 0,
}) {
  final clampedProgress = focusProgress.clamp(0.0, 1.0);
  final baseColor = hazukiSearchBoxOutlineColor(context);
  final focusedColor = Theme.of(context).colorScheme.primary;
  return BorderSide(
    color: Color.lerp(baseColor, focusedColor, clampedProgress) ?? baseColor,
    width: 0.8 + (0.8 * clampedProgress),
  );
}
