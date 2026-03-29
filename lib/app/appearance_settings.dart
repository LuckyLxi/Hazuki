import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

const int hazukiDefaultAppearancePresetIndex = 0;
const bool hazukiDefaultDynamicColorEnabled = false;

class AppearanceSettingsData {
  const AppearanceSettingsData({
    required this.themeMode,
    required this.oledPureBlack,
    required this.dynamicColor,
    required this.presetIndex,
    required this.displayModeRaw,
    required this.comicDetailDynamicColor,
  });

  final ThemeMode themeMode;
  final bool oledPureBlack;
  final bool dynamicColor;
  final int presetIndex;
  final String displayModeRaw;
  final bool comicDetailDynamicColor;

  static ThemeMode decodeThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String encodeThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
  }

  AppearanceSettingsData copyWith({
    ThemeMode? themeMode,
    bool? oledPureBlack,
    bool? dynamicColor,
    int? presetIndex,
    String? displayModeRaw,
    bool? comicDetailDynamicColor,
  }) {
    return AppearanceSettingsData(
      themeMode: themeMode ?? this.themeMode,
      oledPureBlack: oledPureBlack ?? this.oledPureBlack,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      presetIndex: presetIndex ?? this.presetIndex,
      displayModeRaw: displayModeRaw ?? this.displayModeRaw,
      comicDetailDynamicColor:
          comicDetailDynamicColor ?? this.comicDetailDynamicColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppearanceSettingsData &&
        other.themeMode == themeMode &&
        other.oledPureBlack == oledPureBlack &&
        other.dynamicColor == dynamicColor &&
        other.presetIndex == presetIndex &&
        other.displayModeRaw == displayModeRaw &&
        other.comicDetailDynamicColor == comicDetailDynamicColor;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    oledPureBlack,
    dynamicColor,
    presetIndex,
    displayModeRaw,
    comicDetailDynamicColor,
  );
}

class HazukiColorPreset {
  const HazukiColorPreset({
    required this.labelBuilder,
    required this.seedColor,
  });

  final String Function(AppLocalizations strings) labelBuilder;
  final Color seedColor;
}

const List<HazukiColorPreset> kHazukiColorPresets = [
  HazukiColorPreset(
    labelBuilder: _displayPresetMintGreen,
    seedColor: Color(0xFF009688),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetSeaSaltBlue,
    seedColor: Color(0xFF0288D1),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetTwilightPurple,
    seedColor: Color(0xFF7E57C2),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetCherryBlossomPink,
    seedColor: Color(0xFFEC407A),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetCoralOrange,
    seedColor: Color(0xFFFF7043),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetAmberYellow,
    seedColor: Color(0xFFFFB300),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetLimeGreen,
    seedColor: Color(0xFF7CB342),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetGraphiteGray,
    seedColor: Color(0xFF546E7A),
  ),
  HazukiColorPreset(
    labelBuilder: _displayPresetBerryRed,
    seedColor: Color(0xFFC62828),
  ),
];

String _displayPresetMintGreen(AppLocalizations strings) =>
    strings.displayPresetMintGreen;
String _displayPresetSeaSaltBlue(AppLocalizations strings) =>
    strings.displayPresetSeaSaltBlue;
String _displayPresetTwilightPurple(AppLocalizations strings) =>
    strings.displayPresetTwilightPurple;
String _displayPresetCherryBlossomPink(AppLocalizations strings) =>
    strings.displayPresetCherryBlossomPink;
String _displayPresetCoralOrange(AppLocalizations strings) =>
    strings.displayPresetCoralOrange;
String _displayPresetAmberYellow(AppLocalizations strings) =>
    strings.displayPresetAmberYellow;
String _displayPresetLimeGreen(AppLocalizations strings) =>
    strings.displayPresetLimeGreen;
String _displayPresetGraphiteGray(AppLocalizations strings) =>
    strings.displayPresetGraphiteGray;
String _displayPresetBerryRed(AppLocalizations strings) =>
    strings.displayPresetBerryRed;
