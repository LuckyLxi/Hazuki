import 'package:flutter/material.dart';

import 'app_settings_store.dart';
import 'appearance_settings.dart';

class HazukiThemeController extends ChangeNotifier {
  HazukiThemeController({
    required HazukiAppSettingsStore settingsStore,
    required AppearanceSettingsData initialSettings,
  }) : _settingsStore = settingsStore,
       _settings = initialSettings;

  final HazukiAppSettingsStore _settingsStore;
  AppearanceSettingsData _settings;

  AppearanceSettingsData get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;

  Future<void> update(AppearanceSettingsData next) async {
    if (_settings == next) {
      return;
    }

    _settings = next;
    notifyListeners();
    await _settingsStore.saveAppearance(next);
  }
}
