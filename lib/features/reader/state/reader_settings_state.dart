import 'package:flutter/foundation.dart';

import 'package:hazuki/shared/reading/reader_filter_color.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';

/// Settings can read the visible position and update preferences, but cannot
/// replace chapter images or mutate navigation and zoom state directly.
abstract interface class ReaderSettingsState {
  int get currentPageIndex;
  int get imageCount;
  ReaderMode get readerMode;
  bool get doublePageMode;
  bool get pinchToZoom;
  ValueListenable<int> get pageIndexNotifier;
  int spreadStartIndex(int spreadIndex);

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
  });
}
