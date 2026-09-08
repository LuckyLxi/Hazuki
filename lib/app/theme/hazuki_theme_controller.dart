import 'package:flutter/material.dart';

import '../../shared/appearance/appearance_settings_scope.dart';
export '../../shared/appearance/appearance_settings_scope.dart';

import '../app_settings_store.dart';
import '../appearance_settings.dart';

class HazukiThemeController extends ChangeNotifier
    implements AppearanceSettingsSource {
  HazukiThemeController({
    required HazukiAppSettingsStore settingsStore,
    required AppearanceSettingsData initialSettings,
  }) : _settingsStore = settingsStore,
       _settings = initialSettings;

  final HazukiAppSettingsStore _settingsStore;
  AppearanceSettingsData _settings;

  @override
  AppearanceSettingsData get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;

  Future<void> update(AppearanceSettingsData next) async {
    await _applySettings(next, persist: true);
  }

  Future<void> applyRestoredSettings(AppearanceSettingsData next) async {
    await _applySettings(next, persist: false);
  }

  Future<void> _applySettings(
    AppearanceSettingsData next, {
    required bool persist,
  }) async {
    if (_settings == next) {
      return;
    }

    _settings = next;
    notifyListeners();
    if (persist) {
      await _settingsStore.saveAppearance(next);
    }
  }
}
