part of '../reader_page.dart';

extension _ReaderShellWidgetsExtension on _ReaderPageState {
  Widget _buildReaderSettingsDrawer(ThemeData readerTheme) {
    final drawerWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.88,
      360.0,
    );

    return Theme(
      data: readerTheme,
      child: Builder(
        builder: (drawerContext) {
          return Drawer(
            width: drawerWidth,
            child: ReaderSettingsDrawerContent(
              readerMode: _readerMode,
              tapToTurnPage: _tapToTurnPage,
              volumeButtonTurnPage: _volumeButtonTurnPage,
              pinchToZoom: _pinchToZoom,
              longPressToSave: _longPressToSave,
              immersiveMode: _immersiveMode,
              keepScreenOn: _keepScreenOn,
              pageIndicator: _pageIndicator,
              customBrightness: _customBrightness,
              brightnessValue: _brightnessValue,
              onReaderModeChanged: _updateReaderModeSetting,
              onTapToTurnPageChanged: _readerMode == ReaderMode.rightToLeft
                  ? _toggleTapToTurnPageSetting
                  : null,
              onVolumeButtonTurnPageChanged: _toggleVolumeButtonTurnPageSetting,
              onPinchToZoomChanged: _togglePinchToZoomSetting,
              onLongPressToSaveChanged: _toggleLongPressToSaveSetting,
              onImmersiveModeChanged: _toggleImmersiveModeSetting,
              onKeepScreenOnChanged: _toggleKeepScreenOnSetting,
              onPageIndicatorChanged: _togglePageIndicatorSetting,
              onCustomBrightnessChanged: _toggleCustomBrightnessSetting,
              onBrightnessChanged: _customBrightness
                  ? _updateBrightnessSetting
                  : null,
              onBrightnessChangeEnd: _customBrightness
                  ? _handleBrightnessChangeEnd
                  : null,
              onClose: () => Navigator.of(drawerContext).pop(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReaderTopControls(ThemeData readerTheme) {
    return ReaderTopControls(
      controlsVisible: _controlsVisible,
      readerTheme: readerTheme,
      title: widget.title,
      settingsTooltip: l10n(context).readingSettingsTitle,
      onBackPressed: _handleBackPressed,
      onOpenSettingsDrawer: _openReaderSettingsDrawer,
    );
  }

  Widget _buildReaderPageIndicator(ThemeData readerTheme) {
    return ReaderPageIndicatorOverlay(
      controlsVisible: _controlsVisible,
      readerTheme: readerTheme,
      pageIndexNotifier: _pageIndexNotifier,
      chapterIndex: widget.chapterIndex,
      imageCount: _images.length,
    );
  }

  Widget _buildReaderBottomControls(ThemeData readerTheme) {
    final maxIndex = math.max(_images.length - 1, 0);
    return ReaderBottomControls(
      controlsVisible: _controlsVisible,
      readerTheme: readerTheme,
      pageIndexNotifier: _pageIndexNotifier,
      sliderDragging: _sliderDragging,
      sliderDragValue: _sliderDragValue,
      imageCount: _images.length,
      chapterPanelLoading: _chapterPanelLoading,
      onSliderChangeStart: _images.length > 1
          ? (value) {
              _lastSliderHapticPageIndex = null;
              _maybeTriggerSliderHaptic(value);
              _updateReaderState(() {
                _sliderDragging = true;
                _sliderDragValue = value;
              });
            }
          : null,
      onSliderChanged: _images.length > 1
          ? (value) {
              _maybeTriggerSliderHaptic(value);
              _updateReaderState(() {
                _sliderDragging = true;
                _sliderDragValue = value;
              });
            }
          : null,
      onSliderChangeEnd: _images.length > 1
          ? (value) {
              final target = math.max(0, math.min(value.round(), maxIndex));
              _lastSliderHapticPageIndex = null;
              _updateReaderState(() {
                _sliderDragging = false;
                _sliderDragValue = target.toDouble();
              });
              unawaited(_goToReaderPage(target, trigger: 'bottom_slider'));
            }
          : null,
      onOpenChaptersPanel: _openChaptersPanel,
    );
  }

  Widget _buildReaderChapterJumpOverlay() {
    return ReaderChapterJumpOverlay(
      controlsVisible: _controlsVisible,
      onPreviousChapter: () {
        unawaited(_jumpToAdjacentChapter(-1));
      },
      onNextChapter: () {
        unawaited(_jumpToAdjacentChapter(1));
      },
      previousTooltip: l10n(context).readerPreviousChapter,
      nextTooltip: l10n(context).readerNextChapter,
    );
  }

  Widget _buildReaderZoomResetOverlay() {
    return ReaderZoomResetOverlay(
      controlsVisible: _controlsVisible,
      isZoomed: _isZoomed,
      onResetZoom: _resetZoom,
      label: l10n(context).readerResetZoom,
    );
  }
}
