import 'package:flutter/widgets.dart';

import '../services/cloud_sync_service.dart';
import '../services/hazuki_source_service.dart';
import 'app_settings_store.dart';
import 'hazuki_theme_controller.dart';
import 'windows_title_bar_controller.dart';

class CloudSyncRestoreApplyResult {
  const CloudSyncRestoreApplyResult({
    required this.sourceReloaded,
    required this.sourceNeedsRestart,
  });

  final bool sourceReloaded;
  final bool sourceNeedsRestart;
}

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

  Future<CloudSyncRestoreApplyResult> applyCloudSyncRestore(
    CloudSyncRestoreResult result,
  ) async {
    if (result.restoredSettings) {
      final appearance = await _settingsStore.loadAppearance();
      await _themeController.applyRestoredSettings(appearance);
      await _reloadLocale();
      await _windowsTitleBarController.reloadFromStore();
    }

    var sourceReloaded = false;
    var sourceNeedsRestart = false;
    if (result.restoredSourceFile) {
      try {
        await HazukiSourceService.instance.reloadFromLocalSourceFiles();
        sourceReloaded = true;
      } catch (_) {
        sourceNeedsRestart = true;
      }
    }

    _refreshHome();
    return CloudSyncRestoreApplyResult(
      sourceReloaded: sourceReloaded,
      sourceNeedsRestart: sourceNeedsRestart,
    );
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
