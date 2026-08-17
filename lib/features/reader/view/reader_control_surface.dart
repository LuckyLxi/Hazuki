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
      settings: LiquidGlassSettings(
        thickness: 28,
        blur: 4,
        chromaticAberration: 0.08,
        lightIntensity: 0.64,
        ambientStrength: 0.18,
        saturation: 1.1,
        glowIntensity: 0.6,
        shadowElevation: 0,
        glassColor: Colors.white.withValues(alpha: 0.12),
        backerColor: Colors.black.withValues(alpha: 0.34),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
