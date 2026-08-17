import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_settings_store.dart';
import 'package:hazuki/app/appearance_settings.dart';
import 'package:hazuki/app/hazuki_app_controller.dart';
import 'package:hazuki/app/theme/hazuki_theme_controller.dart';
import 'package:hazuki/app/windows/windows_title_bar_controller.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppSettingsStore extends Mock implements HazukiAppSettingsStore {}

class _MockThemeController extends Mock implements HazukiThemeController {}

class _MockWindowsTitleBarController extends Mock
    implements HazukiWindowsTitleBarController {}

void main() {
  test('cloud restore applies restored appearance runtime state', () async {
    final settingsStore = _MockAppSettingsStore();
    final themeController = _MockThemeController();
    final windowsTitleBarController = _MockWindowsTitleBarController();
    const appearance = AppearanceSettingsData(
      themeMode: ThemeMode.system,
      oledPureBlack: false,
      dynamicColor: false,
      presetIndex: hazukiDefaultAppearancePresetIndex,
      displayModeRaw: 'native:auto',
      comicDetailDynamicColor: false,
      useSystemFont: true,
      liquidGlassEnabled: false,
    );
    final appliedRuntimeAppearances = <AppearanceSettingsData>[];
    var localeReloadCount = 0;
    var refreshCount = 0;

    when(settingsStore.loadAppearance).thenAnswer((_) async => appearance);
    when(
      () => themeController.applyRestoredSettings(appearance),
    ).thenAnswer((_) async {});
    when(windowsTitleBarController.reloadFromStore).thenAnswer((_) async {});

    final controller = HazukiAppController(
      settingsStore: settingsStore,
      themeController: themeController,
      windowsTitleBarController: windowsTitleBarController,
      applyAppearanceRuntime: (value) async {
        appliedRuntimeAppearances.add(value);
      },
      reloadLocale: () async {
        localeReloadCount++;
      },
      refreshHome: () {
        refreshCount++;
      },
    );

    await controller.applyCloudSyncRestore(
      const CloudSyncRestoreResult(
        restoredSettings: true,
        restoredReading: false,
        restoredSearchHistory: false,
        appliedPlatformFilteredKeys: [],
        skippedKeys: [],
      ),
    );

    expect(appliedRuntimeAppearances, [appearance]);
    expect(localeReloadCount, 1);
    expect(refreshCount, 1);
    verify(() => themeController.applyRestoredSettings(appearance)).called(1);
    verify(() => windowsTitleBarController.reloadFromStore()).called(1);
  });
}
