import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/shared/reading/reader_source_image_quality_settings.dart';
import 'package:hazuki/features/reader/view/reader_overlay_controls.dart';
import 'package:hazuki/features/reader/view/reader_settings_drawer_content.dart';
import 'package:hazuki/l10n/l10n.dart';

const Duration readerSliderHapticMinInterval = Duration(milliseconds: 90);

int readerSliderHapticPageStep(int pageCount) {
  if (pageCount <= 80) {
    return 1;
  }
  if (pageCount <= 200) {
    return 2;
  }
  if (pageCount <= 500) {
    return 5;
  }
  return 10;
}

void maybeTriggerReaderSliderHaptic({
  required ReaderRuntimeState runtimeState,
  required double value,
  bool force = false,
  DateTime? now,
  VoidCallback? triggerHaptic,
}) {
  final targetIndex = math.max(
    0,
    math.min(value.round(), runtimeState.readerSpreadCount - 1),
  );
  final timestamp = now ?? DateTime.now();
  if (!force) {
    final step = readerSliderHapticPageStep(runtimeState.readerSpreadCount);
    final lastIndex = runtimeState.lastSliderHapticPageIndex;
    if (lastIndex != null && (targetIndex - lastIndex).abs() < step) {
      return;
    }
    final lastAt = runtimeState.lastSliderHapticAt;
    if (lastAt != null &&
        timestamp.difference(lastAt) < readerSliderHapticMinInterval) {
      return;
    }
  }
  runtimeState.lastSliderHapticPageIndex = targetIndex;
  runtimeState.lastSliderHapticAt = timestamp;
  final callback = triggerHaptic;
  if (callback != null) {
    callback();
  } else {
    unawaited(HapticFeedback.selectionClick());
  }
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
  required ValueChanged<bool> onFilterEnabledChanged,
  required ValueChanged<ReaderFilterColor> onFilterColorChanged,
  required ValueChanged<double>? onFilterStrengthChanged,
  required ValueChanged<double>? onFilterStrengthChangeEnd,
  required ReaderSourceImageQualitySnapshot sourceImageQuality,
  required ValueChanged<String?> onCopyMangaImageQualityChanged,
  required ValueChanged<String?> onPicacgImageQualityChanged,
}) {
  final drawerWidth = math.min(MediaQuery.sizeOf(context).width * 0.88, 360.0);

  return Theme(
    data: readerTheme,
    child: Builder(
      builder: (drawerContext) {
        final colorScheme = Theme.of(drawerContext).colorScheme;
        final isDark = Theme.of(drawerContext).brightness == Brightness.dark;

        return Drawer(
          width: drawerWidth,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ColoredBox(
                color: colorScheme.surface.withValues(
                  alpha: isDark ? 0.68 : 0.76,
                ),
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
                  filterEnabled: runtimeState.filterEnabled,
                  filterColor: runtimeState.filterColor,
                  filterStrength: runtimeState.filterStrength,
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
                  onFilterEnabledChanged: onFilterEnabledChanged,
                  onFilterColorChanged: onFilterColorChanged,
                  onFilterStrengthChanged: onFilterStrengthChanged,
                  onFilterStrengthChangeEnd: onFilterStrengthChangeEnd,
                  sourceImageQuality: sourceImageQuality,
                  onCopyMangaImageQualityChanged:
                      onCopyMangaImageQualityChanged,
                  onPicacgImageQualityChanged: onPicacgImageQualityChanged,
                  onClose: () => Navigator.of(drawerContext).pop(),
                ),
              ),
            ),
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
  required void Function(double value, {bool force}) maybeTriggerSliderHaptic,
  required void Function(VoidCallback update) updateState,
  required Future<void> Function(int target) goToPage,
  Future<void> Function()? onOpenChaptersPanel,
  VoidCallback? onPreviousChapter,
  VoidCallback? onFavorite,
  VoidCallback? onComments,
  VoidCallback? onNextChapter,
  required VoidCallback onResetZoom,
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
            runtimeState.lastSliderHapticAt = null;
          }
        : null,
    onSliderPointerDown: runtimeState.readerSpreadCount > 1
        ? (value) {
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
            final latestValue = runtimeState.sliderDragging
                ? runtimeState.sliderDragValue
                : value;
            final target = math.max(0, math.min(latestValue.round(), maxIndex));
            runtimeState.lastSliderHapticPageIndex = null;
            runtimeState.lastSliderHapticAt = null;
            maybeTriggerSliderHaptic(target.toDouble(), force: true);
            updateState(() {
              runtimeState.sliderDragging = false;
              runtimeState.sliderDragValue = target.toDouble();
            });
            unawaited(goToPage(target));
          }
        : null,
    onOpenChaptersPanel: onOpenChaptersPanel,
    onPreviousChapter: onPreviousChapter,
    onFavorite: onFavorite,
    onComments: onComments,
    onNextChapter: onNextChapter,
    onResetZoom: onResetZoom,
    isZoomed: runtimeState.pinchToZoom && runtimeState.isZoomed,
    previousTooltip: l10n(context).readerPreviousChapter,
    chaptersTooltip: l10n(context).comicDetailChapters,
    favoriteTooltip: l10n(context).comicDetailFavorite,
    commentsTooltip: l10n(context).commentsTitle,
    nextTooltip: l10n(context).readerNextChapter,
    resetZoomLabel: l10n(context).readerResetZoom,
  );
}
