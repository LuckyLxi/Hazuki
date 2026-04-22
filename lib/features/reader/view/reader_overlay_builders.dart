import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/view/reader_overlay_controls.dart';
import 'package:hazuki/features/reader/view/reader_settings_drawer_content.dart';
import 'package:hazuki/l10n/l10n.dart';

void maybeTriggerReaderSliderHaptic({
  required ReaderRuntimeState runtimeState,
  required double value,
}) {
  final targetIndex = math.max(
    0,
    math.min(value.round(), runtimeState.readerSpreadCount - 1),
  );
  if (runtimeState.lastSliderHapticPageIndex == targetIndex) {
    return;
  }
  runtimeState.lastSliderHapticPageIndex = targetIndex;
  unawaited(HapticFeedback.selectionClick());
}

Widget buildReaderSettingsDrawer({
  required BuildContext context,
  required ThemeData readerTheme,
  required ReaderRuntimeState runtimeState,
  required ValueChanged<ReaderMode?> onReaderModeChanged,
  required ValueChanged<bool> onDoublePageModeChanged,
  required ValueChanged<bool>? onTapToTurnPageChanged,
  required ValueChanged<bool> onVolumeButtonTurnPageChanged,
  required ValueChanged<bool> onPinchToZoomChanged,
  required ValueChanged<bool> onLongPressToSaveChanged,
  required ValueChanged<bool> onImmersiveModeChanged,
  required ValueChanged<bool> onKeepScreenOnChanged,
  required ValueChanged<bool> onPageIndicatorChanged,
  required ValueChanged<bool> onCustomBrightnessChanged,
  required ValueChanged<double>? onBrightnessChanged,
  required ValueChanged<double>? onBrightnessChangeEnd,
}) {
  final drawerWidth = math.min(MediaQuery.sizeOf(context).width * 0.88, 360.0);

  return Theme(
    data: readerTheme,
    child: Builder(
      builder: (drawerContext) {
        return Drawer(
          width: drawerWidth,
          child: ReaderSettingsDrawerContent(
            readerMode: runtimeState.readerMode,
            doublePageMode: runtimeState.doublePageMode,
            tapToTurnPage: runtimeState.tapToTurnPage,
            volumeButtonTurnPage: runtimeState.volumeButtonTurnPage,
            pinchToZoom: runtimeState.pinchToZoom,
            longPressToSave: runtimeState.longPressToSave,
            immersiveMode: runtimeState.immersiveMode,
            keepScreenOn: runtimeState.keepScreenOn,
            pageIndicator: runtimeState.pageIndicator,
            customBrightness: runtimeState.customBrightness,
            brightnessValue: runtimeState.brightnessValue,
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
            onClose: () => Navigator.of(drawerContext).pop(),
          ),
        );
      },
    ),
  );
}

Widget buildReaderTopControls({
  required BuildContext context,
  required ReaderRuntimeState runtimeState,
  required ThemeData readerTheme,
  required String title,
  required VoidCallback onBackPressed,
  required VoidCallback onOpenSettingsDrawer,
}) {
  return ReaderTopControls(
    controlsVisible: runtimeState.controlsVisible,
    readerTheme: readerTheme,
    title: title,
    settingsTooltip: l10n(context).readingSettingsTitle,
    onBackPressed: onBackPressed,
    onOpenSettingsDrawer: onOpenSettingsDrawer,
  );
}

Widget buildReaderPageIndicator({
  required ReaderRuntimeState runtimeState,
  required ThemeData readerTheme,
  required int chapterIndex,
}) {
  return ReaderPageIndicatorOverlay(
    controlsVisible: runtimeState.controlsVisible,
    readerTheme: readerTheme,
    pageIndexNotifier: runtimeState.pageIndexNotifier,
    chapterIndex: chapterIndex,
    imageCount: runtimeState.readerSpreadCount,
  );
}

Widget buildReaderBottomControls({
  required BuildContext context,
  required ReaderRuntimeState runtimeState,
  required ThemeData readerTheme,
  required bool chapterPanelLoading,
  required void Function(double value) maybeTriggerSliderHaptic,
  required void Function(VoidCallback update) updateState,
  required Future<void> Function(int target) goToPage,
  required Future<void> Function() onOpenChaptersPanel,
}) {
  final maxIndex = math.max(runtimeState.readerSpreadCount - 1, 0);
  return ReaderBottomControls(
    controlsVisible: runtimeState.controlsVisible,
    readerTheme: readerTheme,
    pageIndexNotifier: runtimeState.pageIndexNotifier,
    sliderDragging: runtimeState.sliderDragging,
    sliderDragValue: runtimeState.sliderDragValue,
    imageCount: runtimeState.readerSpreadCount,
    chapterPanelLoading: chapterPanelLoading,
    onSliderChangeStart: runtimeState.readerSpreadCount > 1
        ? (value) {
            runtimeState.lastSliderHapticPageIndex = null;
            maybeTriggerSliderHaptic(value);
            updateState(() {
              runtimeState.sliderDragging = true;
              runtimeState.sliderDragValue = value;
            });
          }
        : null,
    onSliderChanged: runtimeState.readerSpreadCount > 1
        ? (value) {
            maybeTriggerSliderHaptic(value);
            updateState(() {
              runtimeState.sliderDragging = true;
              runtimeState.sliderDragValue = value;
            });
          }
        : null,
    onSliderChangeEnd: runtimeState.readerSpreadCount > 1
        ? (value) {
            final target = math.max(0, math.min(value.round(), maxIndex));
            runtimeState.lastSliderHapticPageIndex = null;
            updateState(() {
              runtimeState.sliderDragging = false;
              runtimeState.sliderDragValue = target.toDouble();
            });
            unawaited(goToPage(target));
          }
        : null,
    onOpenChaptersPanel: onOpenChaptersPanel,
  );
}

Widget buildReaderChapterJumpOverlay({
  required BuildContext context,
  required ReaderRuntimeState runtimeState,
  required VoidCallback onPreviousChapter,
  required VoidCallback onNextChapter,
}) {
  return ReaderChapterJumpOverlay(
    controlsVisible: runtimeState.controlsVisible,
    onPreviousChapter: onPreviousChapter,
    onNextChapter: onNextChapter,
    previousTooltip: l10n(context).readerPreviousChapter,
    nextTooltip: l10n(context).readerNextChapter,
  );
}

Widget buildReaderZoomResetOverlay({
  required BuildContext context,
  required ReaderRuntimeState runtimeState,
  required VoidCallback onResetZoom,
}) {
  return ReaderZoomResetOverlay(
    controlsVisible: runtimeState.controlsVisible,
    isZoomed: runtimeState.isZoomed,
    onResetZoom: onResetZoom,
    label: l10n(context).readerResetZoom,
  );
}
