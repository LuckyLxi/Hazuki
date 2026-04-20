part of 'reader_page.dart';

extension _ReaderPageStateOverlayBuilders on _ReaderPageState {
  void _maybeTriggerSliderHaptic(double value) {
    final targetIndex = math.max(
      0,
      math.min(value.round(), _runtimeState.readerSpreadCount - 1),
    );
    if (_runtimeState.lastSliderHapticPageIndex == targetIndex) {
      return;
    }
    _runtimeState.lastSliderHapticPageIndex = targetIndex;
    unawaited(HapticFeedback.selectionClick());
  }

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
              readerMode: _runtimeState.readerMode,
              doublePageMode: _runtimeState.doublePageMode,
              tapToTurnPage: _runtimeState.tapToTurnPage,
              volumeButtonTurnPage: _runtimeState.volumeButtonTurnPage,
              pinchToZoom: _runtimeState.pinchToZoom,
              longPressToSave: _runtimeState.longPressToSave,
              immersiveMode: _runtimeState.immersiveMode,
              keepScreenOn: _runtimeState.keepScreenOn,
              pageIndicator: _runtimeState.pageIndicator,
              customBrightness: _runtimeState.customBrightness,
              brightnessValue: _runtimeState.brightnessValue,
              onReaderModeChanged: _updateReaderModeSetting,
              onDoublePageModeChanged: _toggleDoublePageModeSetting,
              onTapToTurnPageChanged:
                  _runtimeState.readerMode == ReaderMode.rightToLeft
                  ? _toggleTapToTurnPageSetting
                  : null,
              onVolumeButtonTurnPageChanged: _toggleVolumeButtonTurnPageSetting,
              onPinchToZoomChanged: _togglePinchToZoomSetting,
              onLongPressToSaveChanged: _toggleLongPressToSaveSetting,
              onImmersiveModeChanged: _toggleImmersiveModeSetting,
              onKeepScreenOnChanged: _toggleKeepScreenOnSetting,
              onPageIndicatorChanged: _togglePageIndicatorSetting,
              onCustomBrightnessChanged: _toggleCustomBrightnessSetting,
              onBrightnessChanged: _runtimeState.customBrightness
                  ? _updateBrightnessSetting
                  : null,
              onBrightnessChangeEnd: _runtimeState.customBrightness
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
      controlsVisible: _runtimeState.controlsVisible,
      readerTheme: readerTheme,
      title: widget.title,
      settingsTooltip: l10n(context).readingSettingsTitle,
      onBackPressed: _handleBackPressed,
      onOpenSettingsDrawer: _openReaderSettingsDrawer,
    );
  }

  Widget _buildReaderPageIndicator(ThemeData readerTheme) {
    return ReaderPageIndicatorOverlay(
      controlsVisible: _runtimeState.controlsVisible,
      readerTheme: readerTheme,
      pageIndexNotifier: _runtimeState.pageIndexNotifier,
      chapterIndex: widget.chapterIndex,
      imageCount: _runtimeState.readerSpreadCount,
    );
  }

  Widget _buildReaderBottomControls(ThemeData readerTheme) {
    final maxIndex = math.max(_runtimeState.readerSpreadCount - 1, 0);
    return ReaderBottomControls(
      controlsVisible: _runtimeState.controlsVisible,
      readerTheme: readerTheme,
      pageIndexNotifier: _runtimeState.pageIndexNotifier,
      sliderDragging: _runtimeState.sliderDragging,
      sliderDragValue: _runtimeState.sliderDragValue,
      imageCount: _runtimeState.readerSpreadCount,
      chapterPanelLoading: _chapterPanelLoading,
      onSliderChangeStart: _runtimeState.readerSpreadCount > 1
          ? (value) {
              _runtimeState.lastSliderHapticPageIndex = null;
              _maybeTriggerSliderHaptic(value);
              _updateReaderState(() {
                _runtimeState.sliderDragging = true;
                _runtimeState.sliderDragValue = value;
              });
            }
          : null,
      onSliderChanged: _runtimeState.readerSpreadCount > 1
          ? (value) {
              _maybeTriggerSliderHaptic(value);
              _updateReaderState(() {
                _runtimeState.sliderDragging = true;
                _runtimeState.sliderDragValue = value;
              });
            }
          : null,
      onSliderChangeEnd: _runtimeState.readerSpreadCount > 1
          ? (value) {
              final target = math.max(0, math.min(value.round(), maxIndex));
              _runtimeState.lastSliderHapticPageIndex = null;
              _updateReaderState(() {
                _runtimeState.sliderDragging = false;
                _runtimeState.sliderDragValue = target.toDouble();
              });
              unawaited(
                _navigationController.goToPage(
                  target,
                  trigger: 'bottom_slider',
                ),
              );
            }
          : null,
      onOpenChaptersPanel: _openChaptersPanel,
    );
  }

  Widget _buildReaderChapterJumpOverlay() {
    return ReaderChapterJumpOverlay(
      controlsVisible: _runtimeState.controlsVisible,
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
      controlsVisible: _runtimeState.controlsVisible,
      isZoomed: _runtimeState.isZoomed,
      onResetZoom: _readerZoomController.resetZoom,
      label: l10n(context).readerResetZoom,
    );
  }
}
