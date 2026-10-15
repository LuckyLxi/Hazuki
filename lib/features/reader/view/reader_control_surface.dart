import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/shared/liquid_glass_support.dart';

class ReaderControlSurface extends StatelessWidget {
  const ReaderControlSurface({
    super.key,
    required this.borderRadius,
    required this.fallbackColor,
    required this.child,
    this.width,
    this.height,
    this.padding,
  });

  final double borderRadius;
  final Color fallbackColor;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  /// Opaque fallback surfaces retain their white controls. Glass controls use
  /// the reader theme so light surfaces have a matching dark foreground.
  static Color foregroundColor(BuildContext context) =>
      HazukiLiquidGlass.isAvailable
      ? Theme.of(context).colorScheme.onSurface
      : Colors.white;

  static const _foregroundShadows = [
    Shadow(color: Color(0xCC000000), blurRadius: 1, offset: Offset(0, 1)),
    Shadow(color: Color(0xCC000000), blurRadius: 1, offset: Offset(0, -1)),
    Shadow(color: Color(0x99000000), blurRadius: 3),
  ];

  @override
  Widget build(BuildContext context) {
    if (!HazukiLiquidGlass.isAvailable) {
      return SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      );
    }

    return GlassContainer(
      width: width,
      height: height,
      padding: padding,
      useOwnLayer: true,
      quality: HazukiLiquidGlass.navigationQuality,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      settings: HazukiLiquidGlass.readerSettings(context),
      clipBehavior: Clip.antiAlias,
      child: IconTheme.merge(
        data: IconThemeData(
          color: foregroundColor(context),
          shadows: Theme.of(context).brightness == Brightness.dark
              ? _foregroundShadows
              : const [],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: foregroundColor(context),
            shadows: Theme.of(context).brightness == Brightness.dark
                ? _foregroundShadows
                : const [],
          ),
          child: child,
        ),
      ),
    );
  }
}
