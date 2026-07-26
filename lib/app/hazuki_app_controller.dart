import 'package:flutter/widgets.dart';

import '../services/cloud_sync_service.dart';
import 'app_settings_store.dart';
import 'theme/hazuki_theme_controller.dart';
import 'windows/windows_title_bar_controller.dart';

class HazukiAppController {
  HazukiAppController({
    required HazukiAppSettingsStore settingsStore,
    required HazukiThemeController themeController,
    required HazukiWindowsTitleBarController windowsTitleBarController,
    required Future<void> Function() reloadLocale,
    required VoidCallback refreshHome,
  }) : _settingsStore = settingsStore,
       _themeController = themeController,
       _windowsTitleBarController = windowsTitleBarController,
       _reloadLocale = reloadLocale,
       _refreshHome = refreshHome;

  final HazukiAppSettingsStore _settingsStore;
  final HazukiThemeController _themeController;
  final HazukiWindowsTitleBarController _windowsTitleBarController;
  final Future<void> Function() _reloadLocale;
  final VoidCallback _refreshHome;

  Future<void> applyCloudSyncRestore(CloudSyncRestoreResult result) async {
    if (result.restoredSettings) {
      final appearance = await _settingsStore.loadAppearance();
      await _themeController.applyRestoredSettings(appearance);
      await _reloadLocale();
      await _windowsTitleBarController.reloadFromStore();
    }

    _refreshHome();
  }
}

class HazukiAppControllerScope extends InheritedWidget {
  const HazukiAppControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final HazukiAppController controller;

  static HazukiAppController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HazukiAppControllerScope>();
    assert(scope != null, 'HazukiAppControllerScope is missing.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(HazukiAppControllerScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
