part of '../reader_page.dart';

extension _ReaderSettingsActionsExtension on _ReaderPageState {
  Future<void> _loadReadingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final immersiveMode =
        prefs.getBool('reader_immersive_mode') ??
        _ReaderPageState._defaultImmersiveMode;
    final keepScreenOn =
        prefs.getBool('reader_keep_screen_on') ??
        _ReaderPageState._defaultKeepScreenOn;
    final customBrightness =
        prefs.getBool('reader_custom_brightness') ??
        _ReaderPageState._defaultCustomBrightness;
    final pageIndicator =
        prefs.getBool('reader_page_indicator') ??
        _ReaderPageState._defaultPageIndicator;
    final brightnessValue =
        prefs.getDouble('reader_brightness_value') ??
        _ReaderPageState._defaultBrightnessValue;
    final readerMode = readerModeFromRaw(
      prefs.getString('reader_reading_mode'),
    );
    if (!mounted) {
      return;
    }
    _updateReaderState(() {
      _immersiveMode = immersiveMode;
      _keepScreenOn = keepScreenOn;
      _customBrightness = customBrightness;
      _pageIndicator = pageIndicator;
      _brightnessValue = math.max(0.0, math.min(brightnessValue, 1.0));
      _readerMode = readerMode;
      _tapToTurnPage = prefs.getBool('reader_tap_to_turn_page') ?? false;
      _pinchToZoom = prefs.getBool('reader_pinch_to_zoom') ?? false;
      _longPressToSave = prefs.getBool('reader_long_press_save') ?? false;
    });
    _logReaderEvent(
      'Reader settings loaded',
      source: 'reader_settings',
      content: _readerLogPayload({'settingsLoaded': true}),
    );
    await _applyReaderDisplaySettings();
  }

  Future<void> _applyReaderDisplaySettings() async {
    if (_immersiveMode) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    if (Platform.isAndroid) {
      try {
        await _ReaderPageState._readerDisplayChannel.invokeMethod<void>(
          'setKeepScreenOn',
          {
          'enabled': _keepScreenOn,
          },
        );
        await _ReaderPageState._readerDisplayChannel.invokeMethod<bool>(
          'setReaderBrightness',
          {
          'value': _customBrightness ? _brightnessValue : null,
          },
        );
      } catch (_) {}
    }
  }

  Future<void> _restoreReaderDisplay() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (Platform.isAndroid) {
      try {
        await _ReaderPageState._readerDisplayChannel.invokeMethod<void>(
          'setKeepScreenOn',
          {
          'enabled': false,
          },
        );
        await _ReaderPageState._readerDisplayChannel.invokeMethod<bool>(
          'setReaderBrightness',
          {
          'value': null,
          },
        );
      } catch (_) {}
    }
  }

  void _toggleControlsVisibility() {
    final nextVisible = !_controlsVisible;
    _updateReaderState(() {
      _controlsVisible = nextVisible;
    });
    _logReaderEvent(
      'Reader controls toggled',
      source: 'reader_ui',
      content: _readerLogPayload({'controlsVisible': nextVisible}),
    );
  }

  void _openReaderSettingsDrawer() {
    _logReaderEvent('Reader settings drawer opened', source: 'reader_settings');
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _persistReaderBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _persistReaderDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _persistReaderString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _updateReaderModeSetting(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    final previousMode = _readerMode.prefsValue;
    final changed = _readerMode != value;
    _updateReaderState(() {
      _readerMode = value;
    });
    await _persistReaderString('reader_reading_mode', value.prefsValue);
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
      _resetZoomImmediately(reason: 'reading_mode_changed');
      _syncReaderPositionAfterModeChange();
    }
  }

  Future<void> _toggleTapToTurnPageSetting(bool value) async {
    _updateReaderState(() {
      _tapToTurnPage = value;
    });
    await _persistReaderBool('reader_tap_to_turn_page', value);
    _logReaderEvent(
      'Reader tap to turn page toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'tap_to_turn_page',
        'value': value,
      }),
    );
  }

  Future<void> _toggleImmersiveModeSetting(bool value) async {
    _updateReaderState(() {
      _immersiveMode = value;
    });
    await _persistReaderBool('reader_immersive_mode', value);
    _logReaderEvent(
      'Reader immersive mode toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'immersive_mode', 'value': value}),
    );
    await _applyReaderDisplaySettings();
  }

  Future<void> _toggleKeepScreenOnSetting(bool value) async {
    _updateReaderState(() {
      _keepScreenOn = value;
    });
    await _persistReaderBool('reader_keep_screen_on', value);
    _logReaderEvent(
      'Reader keep screen on toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'keep_screen_on', 'value': value}),
    );
    await _applyReaderDisplaySettings();
  }

  Future<void> _toggleCustomBrightnessSetting(bool value) async {
    _updateReaderState(() {
      _customBrightness = value;
    });
    await _persistReaderBool('reader_custom_brightness', value);
    _logReaderEvent(
      'Reader custom brightness toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'custom_brightness',
        'value': value,
      }),
    );
    await _applyReaderDisplaySettings();
  }

  Future<void> _updateBrightnessSetting(double value) async {
    final normalized = math.max(0.0, math.min(value, 1.0));
    _updateReaderState(() {
      _brightnessValue = normalized;
    });
    await _persistReaderDouble('reader_brightness_value', normalized);
    await _applyReaderDisplaySettings();
  }

  Future<void> _togglePageIndicatorSetting(bool value) async {
    _updateReaderState(() {
      _pageIndicator = value;
    });
    await _persistReaderBool('reader_page_indicator', value);
    _logReaderEvent(
      'Reader page indicator toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'page_indicator', 'value': value}),
    );
  }

  Future<void> _togglePinchToZoomSetting(bool value) async {
    if (!value) {
      _resetZoomImmediately(reason: 'pinch_to_zoom_disabled');
    }
    _updateReaderState(() {
      _pinchToZoom = value;
    });
    await _persistReaderBool('reader_pinch_to_zoom', value);
    _logReaderEvent(
      'Reader pinch to zoom toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'pinch_to_zoom', 'value': value}),
    );
  }

  Future<void> _toggleLongPressToSaveSetting(bool value) async {
    _updateReaderState(() {
      _longPressToSave = value;
    });
    await _persistReaderBool('reader_long_press_save', value);
    _logReaderEvent(
      'Reader long press to save toggled',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'long_press_to_save',
        'value': value,
      }),
    );
  }

  Future<void> _openChaptersPanel() async {
    if (_chapterPanelLoading) {
      return;
    }
    final hadCachedChapterDetails = _chapterDetailsCache != null;
    _updateReaderState(() {
      _chapterPanelLoading = true;
    });
    _logReaderEvent(
      'Reader chapters panel requested',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'hadCachedChapterDetails': hadCachedChapterDetails,
      }),
    );
    try {
      final details =
          _chapterDetailsCache ??
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      if (!mounted) {
        return;
      }
      _logReaderEvent(
        'Reader chapters panel opened',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
        }),
      );
      Navigator.of(context).push(
        SpringBottomSheetRoute(
          builder: (routeContext) {
            final themedData = widget.comicTheme ?? Theme.of(routeContext);
            return Theme(
              data: themedData,
              child: ChaptersPanelSheet(
                details: details,
                onDownloadConfirm: (_) {
                  Navigator.of(routeContext).pop();
                },
                onChapterTap: (epId, chapterTitle, index) {
                  unawaited(
                    _handleChapterSelectedFromPanel(
                      routeContext,
                      epId,
                      chapterTitle,
                      index,
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    } catch (e) {
      _logReaderEvent(
        'Reader chapters panel failed',
        level: 'error',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
          'error': '$e',
        }),
      );
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).readerChapterLoadFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        _updateReaderState(() {
          _chapterPanelLoading = false;
        });
      }
    }
  }

  Future<void> _handleChapterSelectedFromPanel(
    BuildContext routeContext,
    String epId,
    String chapterTitle,
    int index,
  ) async {
    Navigator.of(routeContext).pop();
    if (epId == widget.epId) {
      _logReaderEvent(
        'Reader chapter selection ignored',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'targetEpId': epId,
          'targetChapterTitle': chapterTitle,
          'targetChapterIndex': index,
          'reason': 'already_current_chapter',
        }),
      );
      return;
    }
    _logReaderEvent(
      'Reader chapter selected',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'targetEpId': epId,
        'targetChapterTitle': chapterTitle,
        'targetChapterIndex': index,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          title: widget.title,
          chapterTitle: chapterTitle,
          comicId: widget.comicId,
          epId: epId,
          chapterIndex: index,
          images: const [],
          comicTheme: widget.comicTheme,
        ),
      ),
    );
  }

  void _syncReaderPositionAfterModeChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _images.isEmpty) {
        return;
      }
      final target = math.max(
        0,
        math.min(_currentPageIndex, _images.length - 1),
      );
      _setDisplayedPageIndex(target);
      _logReaderEvent(
        'Reader position synced after mode change',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'targetPageIndex': target,
          'targetPage': target + 1,
          'syncPath': _readerMode == ReaderMode.rightToLeft
              ? 'page_controller_jump'
              : 'list_scroll_alignment',
        }),
      );
      _logVisiblePageChange(index: target, trigger: 'mode_changed_sync');
      if (_readerMode == ReaderMode.rightToLeft) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(target);
        }
      } else {
        unawaited(
          _scrollToListReaderPage(
            target,
            animate: false,
            trigger: 'mode_changed_sync',
          ),
        );
      }
    });
  }
}
