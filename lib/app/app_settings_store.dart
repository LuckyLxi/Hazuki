import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_settings.dart';
import 'display_mode.dart';

class HazukiAppSettingsStore {
  const HazukiAppSettingsStore();

  static const String _themeModeKey = 'appearance_theme_mode';
  static const String _oledPureBlackKey = 'appearance_oled_pure_black';
  static const String _dynamicColorKey = 'appearance_dynamic_color';
  static const String _presetIndexKey = 'appearance_preset_index';
  static const String _displayModeKey = 'appearance_display_mode';
  static const String _comicDetailDynamicColorKey =
      'appearance_comic_detail_dynamic_color';
  static const String _localeKey = 'app_locale';

  Future<AppearanceSettingsData> loadAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = AppearanceSettingsData.decodeThemeMode(
      prefs.getString(_themeModeKey),
    );
    var presetIndex =
        prefs.getInt(_presetIndexKey) ?? hazukiDefaultAppearancePresetIndex;
    if (presetIndex < 0 || presetIndex >= kHazukiColorPresets.length) {
      presetIndex = hazukiDefaultAppearancePresetIndex;
    }
    final displayModeRaw = prefs.getString(_displayModeKey) ?? 'native:auto';
    await applyHazukiPreferredDisplayMode(displayModeRaw);

    return AppearanceSettingsData(
      themeMode: mode,
      oledPureBlack: prefs.getBool(_oledPureBlackKey) ?? false,
      dynamicColor:
          prefs.getBool(_dynamicColorKey) ?? hazukiDefaultDynamicColorEnabled,
      presetIndex: presetIndex,
      displayModeRaw: displayModeRaw,
      comicDetailDynamicColor:
          prefs.getBool(_comicDetailDynamicColorKey) ?? false,
    );
  }

  Future<void> saveAppearance(AppearanceSettingsData next) async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = AppearanceSettingsData.encodeThemeMode(next.themeMode);
    await prefs.setString(_themeModeKey, modeRaw);
    await prefs.setBool(_oledPureBlackKey, next.oledPureBlack);
    await prefs.setBool(_dynamicColorKey, next.dynamicColor);
    await prefs.setInt(_presetIndexKey, next.presetIndex);
    await prefs.setString(_displayModeKey, next.displayModeRaw);
    await prefs.setBool(
      _comicDetailDynamicColorKey,
      next.comicDetailDynamicColor,
    );
  }

  Future<Locale?> loadLocalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final localeTag = prefs.getString(_localeKey);
    return _localeFromTag(localeTag);
  }

  Future<Locale?> saveLocalePreference(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    final localeTag = switch (locale?.languageCode) {
      'zh' => 'zh',
      'en' => 'en',
      _ => 'system',
    };
    await prefs.setString(_localeKey, localeTag);
    return localeTag == 'system' ? null : locale;
  }

  Locale? _localeFromTag(String? localeTag) {
    return switch (localeTag) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null,
    };
  }
}
