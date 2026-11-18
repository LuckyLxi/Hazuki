import 'package:flutter/foundation.dart';
import 'package:dynamic_color/dynamic_color.dart';
// dynamic_color 仍返回 flutter/material 的 ColorScheme，需在此转换为 material_ui 类型。
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';

import '../../shared/appearance/appearance_settings.dart';

class HazukiThemeFactory {
  const HazukiThemeFactory._();

  static ThemeData buildLight(
    AppearanceSettingsData settings, [
    legacy.ColorScheme? dynamicColorScheme,
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
    legacy.ColorScheme? dynamicColorScheme,
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
    legacy.ColorScheme? dynamicColorScheme,
  ) {
    if (settings.dynamicColor && dynamicColorScheme != null) {
      return _fromLegacyColorScheme(dynamicColorScheme.harmonized());
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

  /// 逐字段复制旧版 ColorScheme，保证动态取色结果与迁移前一致。
  static ColorScheme _fromLegacyColorScheme(legacy.ColorScheme scheme) {
    return ColorScheme(
      brightness: scheme.brightness,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      primaryFixed: scheme.primaryFixed,
      primaryFixedDim: scheme.primaryFixedDim,
      onPrimaryFixed: scheme.onPrimaryFixed,
      onPrimaryFixedVariant: scheme.onPrimaryFixedVariant,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      secondaryContainer: scheme.secondaryContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
      secondaryFixed: scheme.secondaryFixed,
      secondaryFixedDim: scheme.secondaryFixedDim,
      onSecondaryFixed: scheme.onSecondaryFixed,
      onSecondaryFixedVariant: scheme.onSecondaryFixedVariant,
      tertiary: scheme.tertiary,
      onTertiary: scheme.onTertiary,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
      tertiaryFixed: scheme.tertiaryFixed,
      tertiaryFixedDim: scheme.tertiaryFixedDim,
      onTertiaryFixed: scheme.onTertiaryFixed,
      onTertiaryFixedVariant: scheme.onTertiaryFixedVariant,
      error: scheme.error,
      onError: scheme.onError,
      errorContainer: scheme.errorContainer,
      onErrorContainer: scheme.onErrorContainer,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      surfaceDim: scheme.surfaceDim,
      surfaceBright: scheme.surfaceBright,
      surfaceContainerLowest: scheme.surfaceContainerLowest,
      surfaceContainerLow: scheme.surfaceContainerLow,
      surfaceContainer: scheme.surfaceContainer,
      surfaceContainerHigh: scheme.surfaceContainerHigh,
      surfaceContainerHighest: scheme.surfaceContainerHighest,
      onSurfaceVariant: scheme.onSurfaceVariant,
      outline: scheme.outline,
      outlineVariant: scheme.outlineVariant,
      shadow: scheme.shadow,
      scrim: scheme.scrim,
      inverseSurface: scheme.inverseSurface,
      onInverseSurface: scheme.onInverseSurface,
      inversePrimary: scheme.inversePrimary,
      surfaceTint: scheme.surfaceTint,
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
