import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_settings_store.dart';
import 'package:hazuki/app/appearance_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'liquid glass is enabled by default and persists its preference',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const store = HazukiAppSettingsStore();

      final initial = await store.loadAppearance();
      expect(initial.liquidGlassEnabled, isTrue);

      final disabled = initial.copyWith(liquidGlassEnabled: false);
      await store.saveAppearance(disabled);

      final persisted = await store.loadAppearance();
      expect(persisted.liquidGlassEnabled, isFalse);
    },
  );

  test('liquid glass participates in appearance setting equality', () {
    const enabled = AppearanceSettingsData(
      themeMode: ThemeMode.system,
      oledPureBlack: false,
      dynamicColor: false,
      presetIndex: hazukiDefaultAppearancePresetIndex,
      displayModeRaw: 'native:auto',
      comicDetailDynamicColor: false,
      useSystemFont: true,
    );

    expect(enabled.copyWith(liquidGlassEnabled: false), isNot(enabled));
  });
}
