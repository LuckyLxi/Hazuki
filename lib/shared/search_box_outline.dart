import 'package:flutter/material.dart';

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
