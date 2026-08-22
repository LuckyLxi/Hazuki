import 'dart:io';

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

  // The package's global renderer scope prevents Flutter from painting on
  // Windows. Keep it enabled in widget tests so the glass-specific widgets can
  // still be exercised there, but use each feature's standard fallback in the
  // shipped Windows application.
  static bool get _isSupported => _isFlutterTest || !Platform.isWindows;

  static bool get isAvailable => _rendererReady && _enabled.value;
  static Listenable get changes => _enabled;

  /// Host-app tests cannot resolve the package's premium shader asset paths.
  /// Production uses the full renderer; tests retain the standard renderer so
  /// the navigation structure and interactions can still be exercised.
  static GlassQuality get navigationQuality =>
      _isFlutterTest ? GlassQuality.standard : GlassQuality.premium;

  static Future<void> initialize({bool enabled = true}) async {
    _enabled.value = enabled;
    if (!_isSupported || !enabled) {
      return;
    }
    await _initializeRenderer();
  }

  static Future<void> setEnabled(bool enabled) async {
    if (_enabled.value != enabled) {
      _enabled.value = enabled;
    }
    if (!_isSupported || !enabled || _rendererReady) {
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
        if (!isAvailable) {
          return child!;
        }
        return LiquidGlassWidgets.wrap(
          brightnessResolver: Theme.maybeBrightnessOf,
          child: child!,
        );
      },
    );
  }
}
