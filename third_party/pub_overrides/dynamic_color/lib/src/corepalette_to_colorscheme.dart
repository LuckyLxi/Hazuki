// TODO(guidezpl): remove ignore after migration to new color roles
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

extension CorePaletteToColorScheme on CorePalette {
  /// Create a [ColorScheme] from the given `palette` obtained from the Android OS.
  ColorScheme toColorScheme({
    Brightness brightness = Brightness.light,
  }) {
    final Scheme scheme;

    switch (brightness) {
      case Brightness.light:
        scheme = Scheme.lightFromCorePalette(this);
        break;
      case Brightness.dark:
        scheme = Scheme.darkFromCorePalette(this);
        break;
    }
    if (brightness == Brightness.dark) {
      return _darkColorScheme(scheme);
    }
    return ColorScheme(
      primary: Color(scheme.primary),
      onPrimary: Color(scheme.onPrimary),
      primaryContainer: Color(scheme.primaryContainer),
      onPrimaryContainer: Color(scheme.onPrimaryContainer),
      secondary: Color(scheme.secondary),
      onSecondary: Color(scheme.onSecondary),
      secondaryContainer: Color(scheme.secondaryContainer),
      onSecondaryContainer: Color(scheme.onSecondaryContainer),
      tertiary: Color(scheme.tertiary),
      onTertiary: Color(scheme.onTertiary),
      tertiaryContainer: Color(scheme.tertiaryContainer),
      onTertiaryContainer: Color(scheme.onTertiaryContainer),
      error: Color(scheme.error),
      onError: Color(scheme.onError),
      errorContainer: Color(scheme.errorContainer),
      onErrorContainer: Color(scheme.onErrorContainer),
      outline: Color(scheme.outline),
      outlineVariant: Color(scheme.outlineVariant),
      background: Color(scheme.background),
      onBackground: Color(scheme.onBackground),
      surface: Color(scheme.surface),
      onSurface: Color(scheme.onSurface),
      surfaceVariant: Color(scheme.surfaceVariant),
      onSurfaceVariant: Color(scheme.onSurfaceVariant),
      inverseSurface: Color(scheme.inverseSurface),
      onInverseSurface: Color(scheme.inverseOnSurface),
      inversePrimary: Color(scheme.inversePrimary),
      shadow: Color(scheme.shadow),
      scrim: Color(scheme.scrim),
      brightness: brightness,
    );
  }

  /// 深色方案的 surface 系列按 M3 新规范色调取值。
  ///
  /// 旧版 [Scheme] 的深色 surface 为 Tone 10，且不提供 surfaceContainer*，
  /// Flutter 会回退为 surface / surfaceVariant（Tone 30），导致动态取色时
  /// 整体背景与占位色明显偏亮，与 `ColorScheme.fromSeed` 的层级不一致。
  ColorScheme _darkColorScheme(Scheme scheme) {
    final surface = Color(neutral.get(6));
    return ColorScheme(
      primary: Color(scheme.primary),
      onPrimary: Color(scheme.onPrimary),
      primaryContainer: Color(scheme.primaryContainer),
      onPrimaryContainer: Color(scheme.onPrimaryContainer),
      secondary: Color(scheme.secondary),
      onSecondary: Color(scheme.onSecondary),
      secondaryContainer: Color(scheme.secondaryContainer),
      onSecondaryContainer: Color(scheme.onSecondaryContainer),
      tertiary: Color(scheme.tertiary),
      onTertiary: Color(scheme.onTertiary),
      tertiaryContainer: Color(scheme.tertiaryContainer),
      onTertiaryContainer: Color(scheme.onTertiaryContainer),
      error: Color(scheme.error),
      onError: Color(scheme.onError),
      errorContainer: Color(scheme.errorContainer),
      onErrorContainer: Color(scheme.onErrorContainer),
      outline: Color(scheme.outline),
      outlineVariant: Color(scheme.outlineVariant),
      background: surface,
      onBackground: Color(scheme.onBackground),
      surface: surface,
      onSurface: Color(scheme.onSurface),
      surfaceDim: surface,
      surfaceBright: Color(neutral.get(24)),
      surfaceContainerLowest: Color(neutral.get(4)),
      surfaceContainerLow: Color(neutral.get(10)),
      surfaceContainer: Color(neutral.get(12)),
      surfaceContainerHigh: Color(neutral.get(17)),
      surfaceContainerHighest: Color(neutral.get(22)),
      surfaceVariant: Color(scheme.surfaceVariant),
      onSurfaceVariant: Color(scheme.onSurfaceVariant),
      inverseSurface: Color(scheme.inverseSurface),
      onInverseSurface: Color(scheme.inverseOnSurface),
      inversePrimary: Color(scheme.inversePrimary),
      shadow: Color(scheme.shadow),
      scrim: Color(scheme.scrim),
      brightness: Brightness.dark,
    );
  }
}
