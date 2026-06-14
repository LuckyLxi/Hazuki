import 'dart:async';

import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/state/reader_filter_color.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';

class ReaderSettingsController {
  ReaderSettingsController({
    required ReaderRuntimeState runtimeState,
    required ReaderSettingsStore settingsStore,
    required ReaderNavigationController navigationController,
    required ReaderSessionController sessionController,
    required ReaderZoomController zoomController,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
  }) : _runtimeState = runtimeState,
       _settingsStore = settingsStore,
       _navigationController = navigationController,
       _sessionController = sessionController,
       _zoomController = zoomController,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload;

  final ReaderRuntimeState _runtimeState;
  final ReaderSettingsStore _settingsStore;
  final ReaderNavigationController _navigationController;
  final ReaderSessionController _sessionController;
  final ReaderZoomController _zoomController;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;

  Future<void> updateReaderMode(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    final targetImageIndex = _runtimeState.spreadStartIndex(
      _runtimeState.currentPageIndex,
    );
    final previousMode = _runtimeState.readerMode.prefsValue;
    final changed = _runtimeState.readerMode != value;
    _updateState(() {
      _runtimeState.readerMode = value;
    });
    await _settingsStore.saveReaderMode(value);
    _logEvent(
      changed ? 'Reader mode changed' : 'Reader mode reselected',
      source: 'reader_settings',
      content: _logPayload({
        'setting': 'reading_mode',
        'previousValue': previousMode,
        'nextValue': value.prefsValue,
      }),
    );
    if (changed) {
      _zoomController.resetZoomImmediately(reason: 'reading_mode_changed');
      _navigationController.syncPositionToImageIndex(
        targetImageIndex,
        trigger: 'mode_changed_sync',
      );
    }
  }

  Future<void> toggleDoublePageMode(bool value) async {
    final targetImageIndex = _runtimeState.spreadStartIndex(
      _runtimeState.currentPageIndex,
    );
    final previousValue = _runtimeState.doublePageMode;
    _updateState(() {
      _runtimeState.doublePageMode = value;
      _runtimeState.rebuildSpreadItemKeys();
    });
    await _settingsStore.saveDoublePageMode(value);
    _logEvent(
      previousValue != value
          ? 'Reader double page mode toggled'
          : 'Reader double page mode reselected',
      source: 'reader_settings',
      content: _logPayload({
        'setting': 'double_page_mode',
        'previousValue': previousValue,
        'nextValue': value,
      }),
    );
    if (previousValue != value) {
      _zoomController.resetZoomImmediately(reason: 'double_page_mode_changed');
      _navigationController.syncPositionToImageIndex(
        targetImageIndex,
        trigger: 'double_page_mode_changed_sync',
      );
    }
  }

  Future<void> toggleTapToTurnPage(bool value) async {
    _updateState(() {
      _runtimeState.tapToTurnPage = value;
    });
    await _settingsStore.saveTapToTurnPage(value);
    _logEvent(
      'Reader tap to turn page toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'tap_to_turn_page', 'value': value}),
    );
  }

  Future<void> toggleVolumeButtonTurnPage(bool value) async {
    _updateState(() {
      _runtimeState.volumeButtonTurnPage = value;
    });
    await _settingsStore.saveVolumeButtonTurnPage(value);
    _logEvent(
      'Reader volume button turn page toggled',
      source: 'reader_settings',
      content: _logPayload({
        'setting': 'volume_button_turn_page',
        'value': value,
      }),
    );
    await _sessionController.syncVolumeButtonPagingPlatformState();
  }

  Future<void> toggleImmersiveMode(bool value) async {
    _updateState(() {
      _runtimeState.immersiveMode = value;
    });
    await _settingsStore.saveImmersiveMode(value);
    _logEvent(
      'Reader immersive mode toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'immersive_mode', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> toggleKeepScreenOn(bool value) async {
    _updateState(() {
      _runtimeState.keepScreenOn = value;
    });
    await _settingsStore.saveKeepScreenOn(value);
    _logEvent(
      'Reader keep screen on toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'keep_screen_on', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> toggleCustomBrightness(bool value) async {
    _updateState(() {
      _runtimeState.customBrightness = value;
    });
    await _settingsStore.saveCustomBrightness(value);
    _logEvent(
      'Reader custom brightness toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'custom_brightness', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> updateBrightness(double value) async {
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    _updateState(() {
      _runtimeState.brightnessValue = normalized;
    });
    await _settingsStore.saveBrightnessValue(normalized);
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> toggleFilter(bool value) async {
    _updateState(() {
      _runtimeState.filterEnabled = value;
    });
    await _settingsStore.saveFilterEnabled(value);
    _logEvent(
      'Reader filter toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'filter', 'value': value}),
    );
  }

  Future<void> updateFilterColor(ReaderFilterColor value) async {
    _updateState(() {
      _runtimeState.filterColor = value;
    });
    await _settingsStore.saveFilterColor(value);
    _logEvent(
      'Reader filter color changed',
      source: 'reader_settings',
      content: _logPayload({
        'setting': 'filter_color',
        'value': value.prefsValue,
      }),
    );
  }

  Future<void> updateFilterStrength(double value) async {
    final normalized = ReaderSettingsStore.normalizeFilterStrength(value);
    _updateState(() {
      _runtimeState.filterStrength = normalized;
    });
    await _settingsStore.saveFilterStrength(normalized);
  }

  void handleFilterStrengthChangeEnd(double value) {
    final normalized = ReaderSettingsStore.normalizeFilterStrength(value);
    _logEvent(
      'Reader filter strength adjusted',
      source: 'reader_settings',
      content: _logPayload({
        'setting': 'filter_strength',
        'value': normalized,
        'strengthPercent': (normalized * 100).round(),
      }),
    );
  }

  Future<void> togglePageIndicator(bool value) async {
    _updateState(() {
      _runtimeState.pageIndicator = value;
    });
    await _settingsStore.savePageIndicator(value);
    _logEvent(
      'Reader page indicator toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'page_indicator', 'value': value}),
    );
  }

  Future<void> togglePinchToZoom(bool value) async {
    final previousValue = _runtimeState.pinchToZoom;
    final targetImageIndex = _runtimeState.images.isEmpty
        ? 0
        : _runtimeState.spreadStartIndex(_runtimeState.pageIndexNotifier.value);
    if (!value) {
      _zoomController.resetZoomImmediately(reason: 'pinch_to_zoom_disabled');
    }
    _updateState(() {
      _runtimeState.pinchToZoom = value;
    });
    await _settingsStore.savePinchToZoom(value);
    _logEvent(
      'Reader pinch to zoom toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'pinch_to_zoom', 'value': value}),
    );
    if (previousValue != value) {
      unawaited(
        _navigationController.syncPositionAfterPinchToggle(targetImageIndex),
      );
    }
  }

  Future<void> toggleLongPressToSave(bool value) async {
    _updateState(() {
      _runtimeState.longPressToSave = value;
    });
    await _settingsStore.saveLongPressToSave(value);
    _logEvent(
      'Reader long press to save toggled',
      source: 'reader_settings',
      content: _logPayload({'setting': 'long_press_to_save', 'value': value}),
    );
  }

  void handleBrightnessChangeEnd(double value) {
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    _logEvent(
      'Reader brightness adjusted',
      source: 'reader_settings',
      content: _logPayload({
        'setting': 'brightness',
        'value': normalized,
        'brightnessPercent': (normalized * 100).round(),
      }),
    );
  }
}
