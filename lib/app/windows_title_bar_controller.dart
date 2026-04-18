import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app_settings_store.dart';

class HazukiWindowsTitleBarController extends ChangeNotifier {
  HazukiWindowsTitleBarController({
    required HazukiAppSettingsStore settingsStore,
    required bool initialUseSystemTitleBar,
  }) : _settingsStore = settingsStore,
       _useSystemTitleBar = initialUseSystemTitleBar;

  final HazukiAppSettingsStore _settingsStore;

  bool _useSystemTitleBar;

  bool get useSystemTitleBar => _useSystemTitleBar;
  bool get shouldShowCustomTitleBar =>
      Platform.isWindows && !_useSystemTitleBar;

  Future<void> updateUseSystemTitleBar(bool value) async {
    await _applyUseSystemTitleBar(value, persist: true);
  }

  Future<void> reloadFromStore() async {
    final value = await _settingsStore.loadUseSystemTitleBar();
    await _applyUseSystemTitleBar(value, persist: false);
  }

  Future<void> _applyUseSystemTitleBar(
    bool value, {
    required bool persist,
  }) async {
    if (_useSystemTitleBar == value) {
      return;
    }
    _useSystemTitleBar = value;
    notifyListeners();
    if (persist) {
      await _settingsStore.saveUseSystemTitleBar(value);
    }
    if (!Platform.isWindows) {
      return;
    }
    await windowManager.setTitleBarStyle(
      value ? TitleBarStyle.normal : TitleBarStyle.hidden,
      windowButtonVisibility: value,
    );
  }
}

class HazukiWindowsTitleBarScope
    extends InheritedNotifier<HazukiWindowsTitleBarController> {
  const HazukiWindowsTitleBarScope({
    super.key,
    required HazukiWindowsTitleBarController controller,
    required super.child,
  }) : super(notifier: controller);

  static HazukiWindowsTitleBarController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HazukiWindowsTitleBarScope>();
    assert(scope != null, 'HazukiWindowsTitleBarScope is missing.');
    return scope!.notifier!;
  }
}
