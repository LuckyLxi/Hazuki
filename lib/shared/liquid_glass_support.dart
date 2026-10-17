import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class _HazukiLiquidGlassEnabledNotifier extends ValueNotifier<bool> {
  _HazukiLiquidGlassEnabledNotifier(super.value);

  void notifyAvailabilityChanged() => notifyListeners();
}

/// Keeps the experimental liquid-glass integration optional and recoverable.
abstract final class HazukiLiquidGlass {
  static const double navigationControlHeight = 58;

  static bool _rendererReady = false;
  static final _enabled = _HazukiLiquidGlassEnabledNotifier(true);

  static final bool _isFlutterTest = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  static bool get isAvailable => _rendererReady && _enabled.value;
  static Listenable get changes => _enabled;

  /// Host-app tests cannot resolve the package's premium shader asset paths.
  /// Production uses premium where shader filters are supported. Tests and
  /// other renderers use standard so the same controls remain usable.
  static GlassQuality get navigationQuality =>
      !_isFlutterTest &&
          !Platform.isWindows &&
          !Platform.isLinux &&
          ui.ImageFilter.isShaderFilterSupported
      ? GlassQuality.premium
      : GlassQuality.standard;

  static bool _usesPremiumRenderer(BuildContext context, GlassQuality quality) {
    final ceiling = GlassAdaptiveScopeData.maybeOf(context)?.effectiveQuality;
    return quality == GlassQuality.premium &&
        navigationQuality == GlassQuality.premium &&
        (ceiling == null || ceiling == GlassQuality.premium);
  }

  /// A broad circular-arc lens, following the compose-miuix navigation material.
  /// The premium engine expresses bevel width in 3x baseline pixels: 72 gives
  /// a 24 logical-pixel transition at every device pixel ratio.
  static LiquidGlassSettings surfaceSettings(
    BuildContext context, {
    double visibility = 1,
    GlassQuality quality = GlassQuality.standard,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final premium = _usesPremiumRenderer(context, quality);
    return LiquidGlassSettings(
      visibility: visibility,
      thickness: premium ? 72 : 10,
      blur: 2,
      refractiveIndex: 1.18,
      lensModel: premium
          ? GlassLensModel.circularArc
          : GlassLensModel.spherical,
      refractionAmount: premium ? 24 : 0,
      chromaticAberration: 0,
      lightAngle: 2.356194490192345,
      lightIntensity: premium ? 0.65 : 0.9,
      fresnelStrength: 1.2,
      // Pair the bright lip with a subtle shaded bevel so the edge has depth.
      // Standard uses thickness/absorption; premium also supports inset rims.
      edgeAbsorption: isDark ? 0.14 : 0.12,
      rimShade: premium ? (isDark ? 0.45 : 0.65) : 0,
      rimShadeEnds: isDark ? 0 : 0.2,
      rimLight: premium ? (isDark ? 1.05 : 0.85) : 0,
      ambientStrength: 0,
      saturation: 1.15,
      glassColor: isDark ? const Color(0x20141820) : const Color(0x14FFFFFF),
      bodyMode: GlassBodyMode.clear,
      glowIntensity: 0,
      shadowElevation: 0.35,
    );
  }

  /// The bar owns the moving lens; do not add another glass control inside it.
  static const indicatorSettings = LiquidGlassSettings(
    thickness: 30,
    blur: 0,
    refractiveIndex: 1.15,
    lensModel: GlassLensModel.circularArcWithDepth,
    refractionAmount: 14,
    chromaticAberration: 0.3,
    lightIntensity: 0.75,
    fresnelStrength: 1,
    edgeAbsorption: 0.05,
    rimShade: 0.35,
    rimLight: 0.75,
    ambientStrength: 0,
    saturation: 1,
    bodyMode: GlassBodyMode.clear,
    glowIntensity: 0,
    shadowElevation: 0,
  );

  /// Keep the theme tint light so artwork remains visible through the lens.
  static LiquidGlassSettings navigationSettings(BuildContext context) {
    return surfaceSettings(context, quality: navigationQuality).copyWith(
      glassColor: Theme.of(
        context,
      ).colorScheme.surfaceContainer.withValues(alpha: 0.16),
    );
  }

  /// Reader navigation shares the home bar's theme tint and lens renderer.
  static LiquidGlassSettings readerSettings(BuildContext context) {
    return navigationSettings(context).copyWith(shadowElevation: 0);
  }

  /// Popovers share the navigation lens and tint without a second shadow.
  static LiquidGlassSettings popoverSettings(
    BuildContext context, {
    double visibility = 1,
  }) {
    return readerSettings(context).copyWith(visibility: visibility);
  }

  static Future<void> initialize({bool enabled = true}) async {
    _enabled.value = enabled;
    if (!enabled) {
      return;
    }
    await _initializeRenderer();
  }

  static Future<void> setEnabled(bool enabled) async {
    if (_enabled.value != enabled) {
      _enabled.value = enabled;
    }
    if (!enabled || _rendererReady) {
      return;
    }
    await _initializeRenderer();
  }

  static Future<void> _initializeRenderer() async {
    if (_rendererReady) {
      return;
    }
    try {
      if (_isFlutterTest) {
        await LightweightLiquidGlass.preWarm();
      } else {
        await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
      }
      _rendererReady = true;
      _enabled.notifyAvailabilityChanged();
    } catch (error, stackTrace) {
      debugPrint('Liquid glass initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _rendererReady = false;
    }
  }

  static Widget wrap({required Widget child}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _enabled,
      child: child,
      builder: (context, _, child) {
        // Keep the theme wrapper mounted when glass is disabled or not ready.
        // Removing it remounts the app and discards its navigation/state. The
        // wrapper only provides configuration; surfaces use isAvailable to
        // decide whether to render glass.
        return LiquidGlassWidgets.wrap(
          brightnessResolver: Theme.maybeBrightnessOf,
          respectSystemAccessibility: true,
          // Keep the supported renderer stable for the session. The adaptive
          // benchmark counts unrelated image decoding/scroll frames and can
          // replace the lens with shader-free frosted glass during reading.
          // Accessibility fallbacks still apply independently of this setting.
          adaptiveQuality: false,
          theme: GlassThemeData.simple(quality: GlassQuality.standard),
          child: child!,
        );
      },
    );
  }
}
