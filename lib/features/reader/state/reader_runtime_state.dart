import 'reader_navigation_state.dart';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/shared/reading/reader_filter_color.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';

/// Owns reader state transitions. Controllers retain Flutter effects and timing.
class ReaderRuntimeState implements ReaderNavigationState {
  int _currentPageIndex = 0;
  @override
  int get currentPageIndex => _currentPageIndex;

  bool _controlsVisible = false;
  bool get controlsVisible => _controlsVisible;

  bool _sliderDragging = false;
  bool get sliderDragging => _sliderDragging;

  double _sliderDragValue = 0;
  double get sliderDragValue => _sliderDragValue;

  int? _lastSliderHapticPageIndex;
  int? get lastSliderHapticPageIndex => _lastSliderHapticPageIndex;

  DateTime? _lastSliderHapticAt;
  DateTime? get lastSliderHapticAt => _lastSliderHapticAt;

  List<String> _images = const <String>[];
  List<String> get images => _images;
  @override
  int get imageCount => _images.length;

  bool _loadingImages = true;
  bool get loadingImages => _loadingImages;

  String? _loadImagesError;
  String? get loadImagesError => _loadImagesError;

  bool _isZoomed = false;
  @override
  bool get isZoomed => _isZoomed;

  bool _zoomInteracting = false;
  bool get zoomInteracting => _zoomInteracting;

  int _activePointerCount = 0;
  @override
  int get activePointerCount => _activePointerCount;

  ReaderSettingsSnapshot _settings = const ReaderSettingsSnapshot(
    readerMode: ReaderSettingsStore.defaultReaderMode,
    doublePageMode: ReaderSettingsStore.defaultDoublePageMode,
    tapToTurnPage: ReaderSettingsStore.defaultTapToTurnPage,
    volumeButtonTurnPage: ReaderSettingsStore.defaultVolumeButtonTurnPage,
    immersiveMode: ReaderSettingsStore.defaultImmersiveMode,
    keepScreenOn: ReaderSettingsStore.defaultKeepScreenOn,
    customBrightness: ReaderSettingsStore.defaultCustomBrightness,
    brightnessValue: ReaderSettingsStore.defaultBrightnessValue,
    filterEnabled: ReaderSettingsStore.defaultFilterEnabled,
    filterColor: ReaderSettingsStore.defaultFilterColor,
    filterStrength: ReaderSettingsStore.defaultFilterStrength,
    pageIndicator: ReaderSettingsStore.defaultPageIndicator,
    pinchToZoom: ReaderSettingsStore.defaultPinchToZoom,
    longPressToSave: ReaderSettingsStore.defaultLongPressToSave,
  );
  ReaderSettingsSnapshot get settings => _settings;
  @override
  ReaderMode get readerMode => _settings.readerMode;
  bool get doublePageMode => _settings.doublePageMode;
  @override
  bool get tapToTurnPage => _settings.tapToTurnPage;
  @override
  bool get volumeButtonTurnPage => _settings.volumeButtonTurnPage;
  bool get immersiveMode => _settings.immersiveMode;
  bool get keepScreenOn => _settings.keepScreenOn;
  bool get customBrightness => _settings.customBrightness;
  double get brightnessValue => _settings.brightnessValue;
  bool get filterEnabled => _settings.filterEnabled;
  ReaderFilterColor get filterColor => _settings.filterColor;
  double get filterStrength => _settings.filterStrength;
  bool get pageIndicator => _settings.pageIndicator;
  bool get pinchToZoom => _settings.pinchToZoom;
  bool get longPressToSave => _settings.longPressToSave;

  final ValueNotifier<int> _pageIndexNotifier = ValueNotifier<int>(0);
  ValueListenable<int> get pageIndexNotifier => _pageIndexNotifier;
  final List<GlobalKey> _itemKeys = [];
  late final List<GlobalKey> _readOnlyItemKeys = UnmodifiableListView(
    _itemKeys,
  );
  @override
  List<GlobalKey> get itemKeys => _readOnlyItemKeys;

  void applySettingsSnapshot(ReaderSettingsSnapshot settings) {
    _settings = settings;
    _rebuildSpreadItemKeys();
  }

  void updateSettings({
    ReaderMode? readerMode,
    bool? doublePageMode,
    bool? tapToTurnPage,
    bool? volumeButtonTurnPage,
    bool? immersiveMode,
    bool? keepScreenOn,
    bool? customBrightness,
    double? brightnessValue,
    bool? filterEnabled,
    ReaderFilterColor? filterColor,
    double? filterStrength,
    bool? pageIndicator,
    bool? pinchToZoom,
    bool? longPressToSave,
  }) {
    applySettingsSnapshot(
      ReaderSettingsSnapshot(
        readerMode: readerMode ?? _settings.readerMode,
        doublePageMode: doublePageMode ?? _settings.doublePageMode,
        tapToTurnPage: tapToTurnPage ?? _settings.tapToTurnPage,
        volumeButtonTurnPage:
            volumeButtonTurnPage ?? _settings.volumeButtonTurnPage,
        immersiveMode: immersiveMode ?? _settings.immersiveMode,
        keepScreenOn: keepScreenOn ?? _settings.keepScreenOn,
        customBrightness: customBrightness ?? _settings.customBrightness,
        brightnessValue: brightnessValue ?? _settings.brightnessValue,
        filterEnabled: filterEnabled ?? _settings.filterEnabled,
        filterColor: filterColor ?? _settings.filterColor,
        filterStrength: filterStrength ?? _settings.filterStrength,
        pageIndicator: pageIndicator ?? _settings.pageIndicator,
        pinchToZoom: pinchToZoom ?? _settings.pinchToZoom,
        longPressToSave: longPressToSave ?? _settings.longPressToSave,
      ),
    );
  }

  /// Keep the navigation index and the displayed index consistent.
  @override
  void setCurrentPageIndex(int index) {
    _currentPageIndex = normalizeSpreadIndex(index);
    _publishPageIndex(_currentPageIndex);
  }

  void setControlsVisible(bool visible) => _controlsVisible = visible;

  void updateSliderDrag(double value) {
    _sliderDragging = true;
    _sliderDragValue = value;
  }

  void finishSliderDrag(int target) {
    _sliderDragging = false;
    _sliderDragValue = target.toDouble();
  }

  void resetSliderHaptic() {
    _lastSliderHapticPageIndex = null;
    _lastSliderHapticAt = null;
  }

  void recordSliderHaptic(int index, DateTime timestamp) {
    _lastSliderHapticPageIndex = index;
    _lastSliderHapticAt = timestamp;
  }

  void pointerDown() => _activePointerCount++;
  void pointerUp() =>
      _activePointerCount = math.max(0, _activePointerCount - 1);
  void setZoomed(bool zoomed) => _isZoomed = zoomed;
  void beginZoomInteraction() => _zoomInteracting = true;

  void finishZoomInteraction({required bool zoomed}) {
    _zoomInteracting = _activePointerCount > 1;
    _isZoomed = zoomed;
  }

  void resetZoom({bool resetPointers = true}) {
    _isZoomed = false;
    _zoomInteracting = false;
    if (resetPointers) _activePointerCount = 0;
  }

  void applyImages(List<String> nextImages) {
    _images = List.unmodifiable(nextImages);
    _loadingImages = false;
    _loadImagesError = null;
    _currentPageIndex = 0;
    resetZoom();
    _sliderDragging = false;
    _sliderDragValue = 0;
    _lastSliderHapticPageIndex = null;
    _lastSliderHapticAt = null;
    _rebuildSpreadItemKeys();
    _publishPageIndex(0);
  }

  void markLoadingImages() {
    _loadingImages = true;
    _loadImagesError = null;
  }

  void markLoadImagesFailed(String message) {
    _loadingImages = false;
    _loadImagesError = message;
  }

  bool get zoomGestureActive =>
      pinchToZoom && (_isZoomed || _zoomInteracting || _activePointerCount > 1);

  @override
  bool get pageNavigationLocked =>
      pinchToZoom && (_zoomInteracting || _isZoomed || _activePointerCount > 1);

  @override
  int get readerSpreadSize => doublePageMode ? 2 : 1;

  @override
  int get readerSpreadCount {
    if (_images.isEmpty) {
      return 0;
    }
    return (_images.length + readerSpreadSize - 1) ~/ readerSpreadSize;
  }

  @override
  int normalizeSpreadIndex(int index) {
    if (readerSpreadCount <= 0) {
      return 0;
    }
    return math.max(0, math.min(index, readerSpreadCount - 1));
  }

  @override
  int spreadStartIndex(int spreadIndex) {
    if (_images.isEmpty) {
      return 0;
    }
    return normalizeSpreadIndex(spreadIndex) * readerSpreadSize;
  }

  List<int> spreadImageIndices(int spreadIndex) {
    if (_images.isEmpty) {
      return const <int>[];
    }
    final start = spreadStartIndex(spreadIndex);
    final end = math.min(start + readerSpreadSize, _images.length);
    return List<int>.generate(end - start, (offset) => start + offset);
  }

  void _rebuildSpreadItemKeys() {
    final needed = readerSpreadCount;
    if (_itemKeys.length == needed) return;
    _itemKeys
      ..clear()
      ..addAll(List<GlobalKey>.generate(needed, (_) => GlobalKey()));
  }

  void _publishPageIndex(int index) {
    if (readerSpreadCount <= 0) {
      if (_pageIndexNotifier.value != 0) {
        _pageIndexNotifier.value = 0;
      }
      return;
    }
    final normalized = normalizeSpreadIndex(index);
    if (_pageIndexNotifier.value != normalized) {
      _pageIndexNotifier.value = normalized;
    }
  }

  void dispose() => _pageIndexNotifier.dispose();
}
