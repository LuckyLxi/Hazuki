import 'package:flutter/widgets.dart';

import '../services/cloud_sync_service.dart';
import '../shared/cloud_sync/cloud_sync_restore_handler.dart';
export '../shared/cloud_sync/cloud_sync_restore_handler.dart';

import 'app_settings_store.dart';
import 'appearance_settings.dart';
import 'theme/hazuki_theme_controller.dart';
import 'windows/windows_title_bar_controller.dart';

class HazukiAppController implements CloudSyncRestoreHandler {
  HazukiAppController({
    required HazukiAppSettingsStore settingsStore,
    required HazukiThemeController themeController,
    required HazukiWindowsTitleBarController windowsTitleBarController,
    required Future<void> Function(AppearanceSettingsData appearance)
    applyAppearanceRuntime,
    required Future<void> Function() reloadLocale,
    required VoidCallback refreshHome,
  }) : _settingsStore = settingsStore,
       _themeController = themeController,
       _windowsTitleBarController = windowsTitleBarController,
       _applyAppearanceRuntime = applyAppearanceRuntime,
       _reloadLocale = reloadLocale,
       _refreshHome = refreshHome;

  final HazukiAppSettingsStore _settingsStore;
  final HazukiThemeController _themeController;
  final HazukiWindowsTitleBarController _windowsTitleBarController;
  final Future<void> Function(AppearanceSettingsData appearance)
  _applyAppearanceRuntime;
  final Future<void> Function() _reloadLocale;
  final VoidCallback _refreshHome;

  @override
  Future<void> applyCloudSyncRestore(CloudSyncRestoreResult result) async {
    if (result.restoredSettings) {
      final appearance = await _settingsStore.loadAppearance();
      await _themeController.applyRestoredSettings(appearance);
      await _applyAppearanceRuntime(appearance);
      await _reloadLocale();
      await _windowsTitleBarController.reloadFromStore();
    }

    _refreshHome();
  }
}
