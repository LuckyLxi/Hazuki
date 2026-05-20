import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/support/reader_source_image_quality_settings.dart';
import 'package:hazuki/features/reader/view/reader_settings_content.dart';

class ReaderSettingsDrawerContent extends StatelessWidget {
  const ReaderSettingsDrawerContent({
    super.key,
    required this.readerMode,
    required this.doublePageMode,
    required this.tapToTurnPage,
    required this.volumeButtonTurnPage,
    required this.pinchToZoom,
    required this.longPressToSave,
    required this.immersiveMode,
    required this.keepScreenOn,
    required this.pageIndicator,
    required this.customBrightness,
    required this.brightnessValue,
    required this.sourceImageQuality,
    required this.onReaderModeChanged,
    required this.onDoublePageModeChanged,
    required this.onTapToTurnPageChanged,
    required this.onVolumeButtonTurnPageChanged,
    required this.onPinchToZoomChanged,
    required this.onLongPressToSaveChanged,
    required this.onImmersiveModeChanged,
    required this.onKeepScreenOnChanged,
    required this.onPageIndicatorChanged,
    required this.onCustomBrightnessChanged,
    required this.onBrightnessChanged,
    required this.onBrightnessChangeEnd,
    required this.onCopyMangaImageQualityChanged,
    required this.onPicacgImageQualityChanged,
    required this.onClose,
  });

  final ReaderMode readerMode;
  final bool doublePageMode;
  final bool tapToTurnPage;
  final bool volumeButtonTurnPage;
  final bool pinchToZoom;
  final bool longPressToSave;
  final bool immersiveMode;
  final bool keepScreenOn;
  final bool pageIndicator;
  final bool customBrightness;
  final double brightnessValue;
  final ReaderSourceImageQualitySnapshot sourceImageQuality;
  final ValueChanged<ReaderMode?> onReaderModeChanged;
  final ValueChanged<bool> onDoublePageModeChanged;
  final ValueChanged<bool>? onTapToTurnPageChanged;
  final ValueChanged<bool> onVolumeButtonTurnPageChanged;
  final ValueChanged<bool> onPinchToZoomChanged;
  final ValueChanged<bool> onLongPressToSaveChanged;
  final ValueChanged<bool> onImmersiveModeChanged;
  final ValueChanged<bool> onKeepScreenOnChanged;
  final ValueChanged<bool> onPageIndicatorChanged;
  final ValueChanged<bool> onCustomBrightnessChanged;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<double>? onBrightnessChangeEnd;
  final ValueChanged<String?> onCopyMangaImageQualityChanged;
  final ValueChanged<String?> onPicacgImageQualityChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsContent(
      surface: ReaderSettingsSurface.drawer,
      readerMode: readerMode,
      doublePageMode: doublePageMode,
      tapToTurnPage: tapToTurnPage,
      volumeButtonTurnPage: volumeButtonTurnPage,
      pinchToZoom: pinchToZoom,
      longPressToSave: longPressToSave,
      immersiveMode: immersiveMode,
      keepScreenOn: keepScreenOn,
      pageIndicator: pageIndicator,
      customBrightness: customBrightness,
      brightnessValue: brightnessValue,
      sourceImageQuality: sourceImageQuality,
      onReaderModeChanged: onReaderModeChanged,
      onDoublePageModeChanged: onDoublePageModeChanged,
      onTapToTurnPageChanged: onTapToTurnPageChanged,
      onVolumeButtonTurnPageChanged: onVolumeButtonTurnPageChanged,
      onPinchToZoomChanged: onPinchToZoomChanged,
      onLongPressToSaveChanged: onLongPressToSaveChanged,
      onImmersiveModeChanged: onImmersiveModeChanged,
      onKeepScreenOnChanged: onKeepScreenOnChanged,
      onPageIndicatorChanged: onPageIndicatorChanged,
      onCustomBrightnessChanged: onCustomBrightnessChanged,
      onBrightnessChanged: onBrightnessChanged,
      onBrightnessChangeEnd: onBrightnessChangeEnd,
      onCopyMangaImageQualityChanged: onCopyMangaImageQualityChanged,
      onPicacgImageQualityChanged: onPicacgImageQualityChanged,
      onClose: onClose,
    );
  }
}
