import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';

class ReaderRuntimeState {
  int currentPageIndex = 0;
  bool controlsVisible = false;
  bool sliderDragging = false;
  double sliderDragValue = 0;
  int? lastSliderHapticPageIndex;
  List<String> images = const <String>[];
  bool loadingImages = true;
  String? loadImagesError;
  bool immersiveMode = ReaderSettingsStore.defaultImmersiveMode;
  bool keepScreenOn = ReaderSettingsStore.defaultKeepScreenOn;
  bool customBrightness = ReaderSettingsStore.defaultCustomBrightness;
  double brightnessValue = ReaderSettingsStore.defaultBrightnessValue;
  ReaderMode readerMode = ReaderSettingsStore.defaultReaderMode;
  bool doublePageMode = ReaderSettingsStore.defaultDoublePageMode;
  bool tapToTurnPage = ReaderSettingsStore.defaultTapToTurnPage;
  bool pageIndicator = ReaderSettingsStore.defaultPageIndicator;
  bool pinchToZoom = ReaderSettingsStore.defaultPinchToZoom;
  bool longPressToSave = ReaderSettingsStore.defaultLongPressToSave;
  bool volumeButtonTurnPage = ReaderSettingsStore.defaultVolumeButtonTurnPage;
  bool isZoomed = false;
  bool zoomInteracting = false;
  int activePointerCount = 0;

  final ValueNotifier<int> pageIndexNotifier = ValueNotifier<int>(0);
  final List<GlobalKey> itemKeys = <GlobalKey>[];

  void applySettingsSnapshot(ReaderSettingsSnapshot settings) {
    immersiveMode = settings.immersiveMode;
    keepScreenOn = settings.keepScreenOn;
    customBrightness = settings.customBrightness;
    pageIndicator = settings.pageIndicator;
    brightnessValue = settings.brightnessValue;
    readerMode = settings.readerMode;
    doublePageMode = settings.doublePageMode;
    tapToTurnPage = settings.tapToTurnPage;
    volumeButtonTurnPage = settings.volumeButtonTurnPage;
    pinchToZoom = settings.pinchToZoom;
    longPressToSave = settings.longPressToSave;
    rebuildSpreadItemKeys();
  }

  void applyImages(List<String> nextImages) {
    images = nextImages;
    loadingImages = false;
    loadImagesError = null;
    currentPageIndex = 0;
    isZoomed = false;
    zoomInteracting = false;
    activePointerCount = 0;
    sliderDragging = false;
    sliderDragValue = 0;
    lastSliderHapticPageIndex = null;
    rebuildSpreadItemKeys();
    setDisplayedPageIndex(0);
  }

  void markLoadingImages() {
    loadingImages = true;
    loadImagesError = null;
  }

  void markLoadImagesFailed(String message) {
    loadingImages = false;
    loadImagesError = message;
  }

  bool get zoomGestureActive =>
      pinchToZoom && (isZoomed || zoomInteracting || activePointerCount > 1);

  bool get pageNavigationLocked =>
      pinchToZoom && (zoomInteracting || isZoomed || activePointerCount > 1);

  int get readerSpreadSize => doublePageMode ? 2 : 1;

  int get readerSpreadCount {
    if (images.isEmpty) {
      return 0;
    }
    return (images.length + readerSpreadSize - 1) ~/ readerSpreadSize;
  }

  int normalizeSpreadIndex(int index) {
    if (readerSpreadCount <= 0) {
      return 0;
    }
    return math.max(0, math.min(index, readerSpreadCount - 1));
  }

  int spreadStartIndex(int spreadIndex) {
    if (images.isEmpty) {
      return 0;
    }
    return normalizeSpreadIndex(spreadIndex) * readerSpreadSize;
  }

  List<int> spreadImageIndices(int spreadIndex) {
    if (images.isEmpty) {
      return const <int>[];
    }
    final start = spreadStartIndex(spreadIndex);
    final end = math.min(start + readerSpreadSize, images.length);
    return List<int>.generate(end - start, (offset) => start + offset);
  }

  void rebuildSpreadItemKeys() {
    final needed = readerSpreadCount;
    if (itemKeys.length == needed) return;
    itemKeys
      ..clear()
      ..addAll(List<GlobalKey>.generate(needed, (_) => GlobalKey()));
  }

  void setDisplayedPageIndex(int index) {
    if (readerSpreadCount <= 0) {
      if (pageIndexNotifier.value != 0) {
        pageIndexNotifier.value = 0;
      }
      return;
    }
    final normalized = normalizeSpreadIndex(index);
    if (pageIndexNotifier.value != normalized) {
      pageIndexNotifier.value = normalized;
    }
  }
}
