import 'package:flutter/foundation.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../appearance_settings.dart';

class HazukiThemeFactory {
  const HazukiThemeFactory._();

  static ThemeData buildLight(
    AppearanceSettingsData settings, [
    ColorScheme? dynamicColorScheme,
  ]) {
    return ThemeData(
      colorScheme: _resolveColorScheme(
        settings,
        Brightness.light,
        dynamicColorScheme,
      ),
      fontFamily: _resolveFontFamily(settings),
      useMaterial3: true,
    );
  }

  static ThemeData buildDark(
    AppearanceSettingsData settings, [
    ColorScheme? dynamicColorScheme,
  ]) {
    final colorScheme = _resolveColorScheme(
      settings,
      Brightness.dark,
      dynamicColorScheme,
    );
    final base = ThemeData(
      colorScheme: colorScheme,
      fontFamily: _resolveFontFamily(settings),
      useMaterial3: true,
      dialogTheme: _darkDialogTheme(colorScheme),
    );

    if (!settings.oledPureBlack) {
      return base;
    }

    final pureBlackScheme = base.colorScheme.copyWith(
      surface: Colors.black,
      surfaceContainer: Colors.black,
      surfaceContainerLow: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerHigh: Colors.black,
      surfaceContainerHighest: Colors.black,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      colorScheme: pureBlackScheme,
      cardColor: Colors.black,
      dialogTheme: _darkDialogTheme(pureBlackScheme),
    );
  }

  /// 深色弹窗统一使用 surfaceContainerLow。
  ///
  /// M3 默认的 surfaceContainerHigh 在深色下与页面背景反差过大，显得发灰偏亮。
  static DialogThemeData _darkDialogTheme(ColorScheme colorScheme) {
    return DialogThemeData(backgroundColor: colorScheme.surfaceContainerLow);
  }

  static ColorScheme _resolveColorScheme(
    AppearanceSettingsData settings,
    Brightness brightness,
    ColorScheme? dynamicColorScheme,
  ) {
    if (settings.dynamicColor && dynamicColorScheme != null) {
      return dynamicColorScheme.harmonized();
    }

    final presetIndex = settings.presetIndex.clamp(
      0,
      kHazukiColorPresets.length - 1,
    );
    final preset = kHazukiColorPresets[presetIndex];
    return ColorScheme.fromSeed(
      seedColor: preset.seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
  }

  static String? _resolveFontFamily(AppearanceSettingsData settings) {
    if (!settings.useSystemFont) {
      return 'NotoSansSC';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Microsoft YaHei UI',
      _ => null,
    };
  }
}
