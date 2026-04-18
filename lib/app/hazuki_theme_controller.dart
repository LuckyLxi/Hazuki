import 'package:flutter/material.dart';

import '../services/hazuki_source_service.dart';
import 'app_settings_store.dart';
import 'appearance_settings.dart';

class HazukiThemeControllerScope
    extends InheritedNotifier<HazukiThemeController> {
  const HazukiThemeControllerScope({
    super.key,
    required HazukiThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static HazukiThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HazukiThemeControllerScope>()
        ?.notifier;
  }

  static HazukiThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'HazukiThemeControllerScope not found');
    return controller!;
  }
}

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
      HazukiSourceService.instance.addApplicationLog(
        level: 'info',
        title: 'Theme controller update skipped',
        source: 'theme_controller',
        content: {
          'themeMode': _settings.themeMode.name,
          'reason': persist ? 'settings_equal' : 'restored_settings_equal',
        },
      );
      return;
    }

    final previous = _settings;
    _settings = next;
    HazukiSourceService.instance.addApplicationLog(
      level: 'info',
      title: 'Theme controller state updated',
      source: 'theme_controller',
      content: {
        'fromThemeMode': previous.themeMode.name,
        'toThemeMode': next.themeMode.name,
        'dynamicColor': next.dynamicColor,
        'oledPureBlack': next.oledPureBlack,
        'presetIndex': next.presetIndex,
      },
    );
    notifyListeners();
    if (persist) {
      await _settingsStore.saveAppearance(next);
      HazukiSourceService.instance.addApplicationLog(
        level: 'info',
        title: 'Theme controller settings persisted',
        source: 'theme_controller',
        content: {'themeMode': next.themeMode.name},
      );
    }
  }
}
