import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader.dart';

class ReaderSettingsSnapshot {
  const ReaderSettingsSnapshot({
    required this.readerMode,
    required this.doublePageMode,
    required this.tapToTurnPage,
    required this.volumeButtonTurnPage,
    required this.immersiveMode,
    required this.keepScreenOn,
    required this.customBrightness,
    required this.brightnessValue,
    required this.pageIndicator,
    required this.pinchToZoom,
    required this.longPressToSave,
  });

  final ReaderMode readerMode;
  final bool doublePageMode;
  final bool tapToTurnPage;
  final bool volumeButtonTurnPage;
  final bool immersiveMode;
  final bool keepScreenOn;
  final bool customBrightness;
  final double brightnessValue;
  final bool pageIndicator;
  final bool pinchToZoom;
  final bool longPressToSave;
}

class ReaderSettingsStore {
  const ReaderSettingsStore();

  static const String readingModeKey = 'reader_reading_mode';
  static const String doublePageModeKey = 'reader_double_page_mode';
  static const String tapToTurnPageKey = 'reader_tap_to_turn_page';
  static const String volumeButtonTurnPageKey =
      'reader_volume_button_turn_page';
  static const String immersiveModeKey = 'reader_immersive_mode';
  static const String keepScreenOnKey = 'reader_keep_screen_on';
  static const String customBrightnessKey = 'reader_custom_brightness';
  static const String brightnessValueKey = 'reader_brightness_value';
  static const String pageIndicatorKey = 'reader_page_indicator';
  static const String pinchToZoomKey = 'reader_pinch_to_zoom';
  static const String longPressToSaveKey = 'reader_long_press_save';

  static const ReaderMode defaultReaderMode = ReaderMode.topToBottom;
  static const bool defaultDoublePageMode = false;
  static const bool defaultTapToTurnPage = false;
  static const bool defaultVolumeButtonTurnPage = false;
  static const bool defaultImmersiveMode = true;
  static const bool defaultKeepScreenOn = true;
  static const bool defaultCustomBrightness = false;
  static const double defaultBrightnessValue = 0.5;
  static const bool defaultPageIndicator = false;
  static const bool defaultPinchToZoom = false;
  static const bool defaultLongPressToSave = false;

  Future<ReaderSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderSettingsSnapshot(
      readerMode: readerModeFromRaw(prefs.getString(readingModeKey)),
      doublePageMode: prefs.getBool(doublePageModeKey) ?? defaultDoublePageMode,
      tapToTurnPage: prefs.getBool(tapToTurnPageKey) ?? defaultTapToTurnPage,
      volumeButtonTurnPage:
          prefs.getBool(volumeButtonTurnPageKey) ?? defaultVolumeButtonTurnPage,
      immersiveMode: prefs.getBool(immersiveModeKey) ?? defaultImmersiveMode,
      keepScreenOn: prefs.getBool(keepScreenOnKey) ?? defaultKeepScreenOn,
      customBrightness:
          prefs.getBool(customBrightnessKey) ?? defaultCustomBrightness,
      brightnessValue: normalizeBrightnessValue(
        prefs.getDouble(brightnessValueKey) ?? defaultBrightnessValue,
      ),
      pageIndicator: prefs.getBool(pageIndicatorKey) ?? defaultPageIndicator,
      pinchToZoom: prefs.getBool(pinchToZoomKey) ?? defaultPinchToZoom,
      longPressToSave:
          prefs.getBool(longPressToSaveKey) ?? defaultLongPressToSave,
    );
  }

  Future<void> saveReaderMode(ReaderMode value) {
    return _saveString(readingModeKey, value.prefsValue);
  }

  Future<void> saveDoublePageMode(bool value) {
    return _saveBool(doublePageModeKey, value);
  }

  Future<void> saveTapToTurnPage(bool value) {
    return _saveBool(tapToTurnPageKey, value);
  }

  Future<void> saveVolumeButtonTurnPage(bool value) {
    return _saveBool(volumeButtonTurnPageKey, value);
  }

  Future<void> saveImmersiveMode(bool value) {
    return _saveBool(immersiveModeKey, value);
  }

  Future<void> saveKeepScreenOn(bool value) {
    return _saveBool(keepScreenOnKey, value);
  }

  Future<void> saveCustomBrightness(bool value) {
    return _saveBool(customBrightnessKey, value);
  }

  Future<void> saveBrightnessValue(double value) {
    return _saveDouble(brightnessValueKey, normalizeBrightnessValue(value));
  }

  Future<void> savePageIndicator(bool value) {
    return _saveBool(pageIndicatorKey, value);
  }

  Future<void> savePinchToZoom(bool value) {
    return _saveBool(pinchToZoomKey, value);
  }

  Future<void> saveLongPressToSave(bool value) {
    return _saveBool(longPressToSaveKey, value);
  }

  static double normalizeBrightnessValue(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

class ReaderDisplayController {
  const ReaderDisplayController(this._channel);

  final MethodChannel _channel;

  Future<void> apply({
    required bool immersiveMode,
    required bool keepScreenOn,
    required bool customBrightness,
    required double brightnessValue,
  }) async {
    if (immersiveMode) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {
        'enabled': keepScreenOn,
      });
      await _channel.invokeMethod<bool>('setReaderBrightness', {
        'value': customBrightness
            ? ReaderSettingsStore.normalizeBrightnessValue(brightnessValue)
            : null,
      });
    } catch (_) {}
  }

  Future<void> syncVolumeButtonPaging({
    required bool enabled,
    required String sessionId,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('setVolumeButtonPaging', {
        'enabled': enabled,
        'sessionId': sessionId,
      });
    } catch (_) {}
  }

  Future<void> restore({required String sessionId}) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await syncVolumeButtonPaging(enabled: false, sessionId: sessionId);

    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'enabled': false});
      await _channel.invokeMethod<bool>('setReaderBrightness', {'value': null});
    } catch (_) {}
  }
}
