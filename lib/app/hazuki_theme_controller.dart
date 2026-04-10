import 'package:flutter/material.dart';

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
    if (_settings == next) {
      return;
    }

    _settings = next;
    notifyListeners();
    await _settingsStore.saveAppearance(next);
  }
}
