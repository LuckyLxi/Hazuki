part of 'reader_page.dart';

extension _ReaderPageStateSettingsActions on _ReaderPageState {
  Future<void> _updateReaderModeSetting(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    final targetImageIndex = _runtimeState.spreadStartIndex(
      _runtimeState.currentPageIndex,
    );
    final previousMode = _runtimeState.readerMode.prefsValue;
    final changed = _runtimeState.readerMode != value;
    _updateReaderState(() {
      _runtimeState.readerMode = value;
    });
    await _ReaderPageState._readerSettingsStore.saveReaderMode(value);
    _logReaderEvent(
      changed ? 'Reader mode changed' : 'Reader mode reselected',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'reading_mode',
        'previousValue': previousMode,
        'nextValue': value.prefsValue,
      }),
    );
    if (changed) {
      _readerZoomController.resetZoomImmediately(
        reason: 'reading_mode_changed',
      );
      _navigationController.syncPositionToImageIndex(
        targetImageIndex,
        trigger: 'mode_changed_sync',
      );
    }
  }

  Future<void> _toggleDoublePageModeSetting(bool value) async {
    final targetImageIndex = _runtimeState.spreadStartIndex(
      _runtimeState.currentPageIndex,
    );
    final previousValue = _runtimeState.doublePageMode;
    _updateReaderState(() {
      _runtimeState.doublePageMode = value;
      _runtimeState.rebuildSpreadItemKeys();
    });
    await _ReaderPageState._readerSettingsStore.saveDoublePageMode(value);
    _logReaderEvent(
      previousValue != value
          ? 'Reader double page mode toggled'
          : 'Reader double page mode reselected',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'double_page_mode',
        'previousValue': previousValue,
        'nextValue': value,
      }),
    );
    if (previousValue != value) {
      _readerZoomController.resetZoomImmediately(
        reason: 'double_page_mode_changed',
      );
      _navigationController.syncPositionToImageIndex(
        targetImageIndex,
        trigger: 'double_page_mode_changed_sync',
      );
    }
  }

  Future<void> _toggleTapToTurnPageSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.tapToTurnPage = value;
    });
    await _ReaderPageState._readerSettingsStore.saveTapToTurnPage(value);
    _logReaderEvent(
      'Reader tap to turn page toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'tap_to_turn_page',
        'value': value,
      }),
    );
  }

  Future<void> _toggleVolumeButtonTurnPageSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.volumeButtonTurnPage = value;
    });
    await _ReaderPageState._readerSettingsStore.saveVolumeButtonTurnPage(value);
    _logReaderEvent(
      'Reader volume button turn page toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'volume_button_turn_page',
        'value': value,
      }),
    );
    await _sessionController.syncVolumeButtonPagingPlatformState();
  }

  Future<void> _toggleImmersiveModeSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.immersiveMode = value;
    });
    await _ReaderPageState._readerSettingsStore.saveImmersiveMode(value);
    _logReaderEvent(
      'Reader immersive mode toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'immersive_mode', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _toggleKeepScreenOnSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.keepScreenOn = value;
    });
    await _ReaderPageState._readerSettingsStore.saveKeepScreenOn(value);
    _logReaderEvent(
      'Reader keep screen on toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'keep_screen_on', 'value': value}),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _toggleCustomBrightnessSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.customBrightness = value;
    });
    await _ReaderPageState._readerSettingsStore.saveCustomBrightness(value);
    _logReaderEvent(
      'Reader custom brightness toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'custom_brightness',
        'value': value,
      }),
    );
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _updateBrightnessSetting(double value) async {
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    _updateReaderState(() {
      _runtimeState.brightnessValue = normalized;
    });
    await _ReaderPageState._readerSettingsStore.saveBrightnessValue(normalized);
    await _sessionController.applyReaderDisplaySettings();
  }

  Future<void> _togglePageIndicatorSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.pageIndicator = value;
    });
    await _ReaderPageState._readerSettingsStore.savePageIndicator(value);
    _logReaderEvent(
      'Reader page indicator toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'page_indicator', 'value': value}),
    );
  }

  Future<void> _togglePinchToZoomSetting(bool value) async {
    final previousValue = _runtimeState.pinchToZoom;
    final targetImageIndex = _runtimeState.images.isEmpty
        ? 0
        : _runtimeState.spreadStartIndex(_runtimeState.pageIndexNotifier.value);
    if (!value) {
      _readerZoomController.resetZoomImmediately(
        reason: 'pinch_to_zoom_disabled',
      );
    }
    _updateReaderState(() {
      _runtimeState.pinchToZoom = value;
    });
    await _ReaderPageState._readerSettingsStore.savePinchToZoom(value);
    _logReaderEvent(
      'Reader pinch to zoom toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'pinch_to_zoom', 'value': value}),
    );
    if (previousValue != value) {
      unawaited(
        _navigationController.syncPositionAfterPinchToggle(targetImageIndex),
      );
    }
  }

  Future<void> _toggleLongPressToSaveSetting(bool value) async {
    _updateReaderState(() {
      _runtimeState.longPressToSave = value;
    });
    await _ReaderPageState._readerSettingsStore.saveLongPressToSave(value);
    _logReaderEvent(
      'Reader long press to save toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'long_press_to_save',
        'value': value,
      }),
    );
  }

  void _toggleControlsVisibility() {
    final nextVisible = !_runtimeState.controlsVisible;
    _updateReaderState(() {
      _runtimeState.controlsVisible = nextVisible;
    });
    _logReaderEvent(
      'Reader controls toggled',
      source: 'reader_ui',
      content: _readerLogPayload({'controlsVisible': nextVisible}),
    );
  }
}
