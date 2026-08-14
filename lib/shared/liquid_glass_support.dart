import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Keeps the experimental liquid-glass integration optional and recoverable.
abstract final class HazukiLiquidGlass {
  static bool _available = false;

  static final bool _isFlutterTest = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  static bool get isAvailable => _available;

  /// Host-app tests cannot resolve the package's premium shader asset paths.
  /// Production uses the full renderer; tests retain the standard renderer so
  /// the navigation structure and interactions can still be exercised.
  static GlassQuality get navigationQuality =>
      _isFlutterTest ? GlassQuality.standard : GlassQuality.premium;

  static Future<void> initialize() async {
    try {
      if (_isFlutterTest) {
        await LightweightLiquidGlass.preWarm();
      } else {
        await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
      }
      _available = true;
    } catch (error, stackTrace) {
      debugPrint('Liquid glass initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _available = false;
    }
  }

  static Widget wrap({required Widget child}) {
    if (!_available) {
      return child;
    }
    return LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: child,
    );
  }
}
