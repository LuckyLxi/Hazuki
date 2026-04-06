part of '../reader_page.dart';

extension _ReaderSettingsActionsExtension on _ReaderPageState {
  Future<void> _loadReadingSettings() async {
    final settings = await _ReaderPageState._readerSettingsStore.load();
    if (!mounted) {
      return;
    }
    _updateReaderState(() {
      _immersiveMode = settings.immersiveMode;
      _keepScreenOn = settings.keepScreenOn;
      _customBrightness = settings.customBrightness;
      _pageIndicator = settings.pageIndicator;
      _brightnessValue = settings.brightnessValue;
      _readerMode = settings.readerMode;
      _doublePageMode = settings.doublePageMode;
      _rebuildSpreadItemKeys();
      _tapToTurnPage = settings.tapToTurnPage;
      _volumeButtonTurnPage = settings.volumeButtonTurnPage;
      _pinchToZoom = settings.pinchToZoom;
      _longPressToSave = settings.longPressToSave;
    });
    _logReaderEvent(
      'Reader settings loaded',
      source: 'reader_settings',
      content: _readerLogPayload({'settingsLoaded': true}),
    );
    await _applyReaderDisplaySettings();
    await _syncReaderVolumeButtonPagingPlatformState();
  }

  Future<void> _applyReaderDisplaySettings() async {
    await _ReaderPageState._readerDisplayController.apply(
      immersiveMode: _immersiveMode,
      keepScreenOn: _keepScreenOn,
      customBrightness: _customBrightness,
      brightnessValue: _brightnessValue,
    );
  }

  Future<void> _syncReaderVolumeButtonPagingPlatformState({
    bool? enabled,
  }) async {
    await _ReaderPageState._readerDisplayController.syncVolumeButtonPaging(
      enabled: enabled ?? _volumeButtonTurnPage,
      sessionId: _readerSessionId,
    );
  }

  Future<void> _restoreReaderDisplay() async {
    await _ReaderPageState._readerDisplayController.restore(
      sessionId: _readerSessionId,
    );
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

  Future<void> _updateReaderModeSetting(ReaderMode? value) async {
    if (value == null) {
      return;
    }
    final targetImageIndex = _spreadStartIndex(_currentPageIndex);
    final previousMode = _readerMode.prefsValue;
    final changed = _readerMode != value;
    _updateReaderState(() {
      _readerMode = value;
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
      _resetZoomImmediately(reason: 'reading_mode_changed');
      _syncReaderPositionToImageIndex(
        targetImageIndex,
        trigger: 'mode_changed_sync',
      );
    }
  }

  Future<void> _toggleDoublePageModeSetting(bool value) async {
    final targetImageIndex = _spreadStartIndex(_currentPageIndex);
    final previousValue = _doublePageMode;
    _updateReaderState(() {
      _doublePageMode = value;
      _rebuildSpreadItemKeys();
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
      _resetZoomImmediately(reason: 'double_page_mode_changed');
      _syncReaderPositionToImageIndex(
        targetImageIndex,
        trigger: 'double_page_mode_changed_sync',
      );
    }
  }

  Future<void> _toggleTapToTurnPageSetting(bool value) async {
    _updateReaderState(() {
      _tapToTurnPage = value;
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
      _volumeButtonTurnPage = value;
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
    await _syncReaderVolumeButtonPagingPlatformState();
  }

  Future<void> _toggleImmersiveModeSetting(bool value) async {
    _updateReaderState(() {
      _immersiveMode = value;
    });
    await _ReaderPageState._readerSettingsStore.saveImmersiveMode(value);
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
    await _ReaderPageState._readerSettingsStore.saveKeepScreenOn(value);
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
    await _ReaderPageState._readerSettingsStore.saveCustomBrightness(value);
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
    final normalized = ReaderSettingsStore.normalizeBrightnessValue(value);
    _updateReaderState(() {
      _brightnessValue = normalized;
    });
    await _ReaderPageState._readerSettingsStore.saveBrightnessValue(normalized);
    await _applyReaderDisplaySettings();
  }

  Future<void> _togglePageIndicatorSetting(bool value) async {
    _updateReaderState(() {
      _pageIndicator = value;
    });
    await _ReaderPageState._readerSettingsStore.savePageIndicator(value);
    _logReaderEvent(
      'Reader page indicator toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'page_indicator', 'value': value}),
    );
  }

  Future<void> _togglePinchToZoomSetting(bool value) async {
    final previousValue = _pinchToZoom;
    final targetImageIndex = _images.isEmpty
        ? 0
        : _spreadStartIndex(_pageIndexNotifier.value);
    if (!value) {
      _resetZoomImmediately(reason: 'pinch_to_zoom_disabled');
    }
    _updateReaderState(() {
      _pinchToZoom = value;
    });
    await _ReaderPageState._readerSettingsStore.savePinchToZoom(value);
    _logReaderEvent(
      'Reader pinch to zoom toggled',
      source: 'reader_settings',
      content: _readerLogPayload({'setting': 'pinch_to_zoom', 'value': value}),
    );
    if (previousValue != value) {
      unawaited(_syncReaderPositionAfterPinchToggle(targetImageIndex));
    }
  }

  Future<void> _toggleLongPressToSaveSetting(bool value) async {
    _updateReaderState(() {
      _longPressToSave = value;
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
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: false,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 380),
          reverseDuration: Duration(milliseconds: 280),
        ),
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

  Future<void> _jumpToAdjacentChapter(int offset) async {
    final navigator = Navigator.of(context);
    final strings = l10n(context);
    try {
      final details =
          _chapterDetailsCache ??
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      final chapterEntries = details.chapters.entries.toList(growable: false);
      if (chapterEntries.isEmpty) {
        return;
      }

      var currentChapterIndex = chapterEntries.indexWhere(
        (entry) => entry.key == widget.epId,
      );
      if (currentChapterIndex < 0) {
        currentChapterIndex = widget.chapterIndex.clamp(
          0,
          chapterEntries.length - 1,
        );
      }
      final targetIndex = currentChapterIndex + offset;

      if (targetIndex < 0) {
        if (mounted) {
          unawaited(showHazukiPrompt(context, strings.readerNoPreviousChapter));
        }
        return;
      }
      if (targetIndex >= chapterEntries.length) {
        if (mounted) {
          unawaited(
            showHazukiPrompt(context, strings.readerAlreadyLastChapter),
          );
        }
        return;
      }

      final targetChapter = chapterEntries[targetIndex];
      _logReaderEvent(
        'Reader adjacent chapter navigation requested',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'offset': offset,
          'fromChapterIndex': currentChapterIndex,
          'targetChapterIndex': targetIndex,
          'targetEpId': targetChapter.key,
          'targetChapterTitle': targetChapter.value,
        }),
      );

      if (!mounted) {
        return;
      }
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReaderPage(
            title: widget.title,
            chapterTitle: targetChapter.value,
            comicId: widget.comicId,
            epId: targetChapter.key,
            chapterIndex: targetIndex,
            images: const [],
            comicTheme: widget.comicTheme,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.readerChapterLoadFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  void _syncReaderPositionToImageIndex(
    int targetImageIndex, {
    required String trigger,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _images.isEmpty) {
        return;
      }
      final safeImageIndex = math.max(
        0,
        math.min(targetImageIndex, _images.length - 1),
      );
      final target = _normalizeSpreadIndex(safeImageIndex ~/ _readerSpreadSize);
      _currentPageIndex = target;
      _setDisplayedPageIndex(target);
      _logReaderEvent(
        'Reader position synced after layout change',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'trigger': trigger,
          'targetImageIndex': safeImageIndex,
          'targetImage': safeImageIndex + 1,
          'targetPageIndex': target,
          'targetPage': target + 1,
          'syncPath': _readerMode == ReaderMode.rightToLeft
              ? 'page_controller_jump'
              : 'list_scroll_alignment',
        }),
      );
      _logVisiblePageChange(index: target, trigger: trigger);
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

  Future<void> _syncReaderPositionAfterPinchToggle(int targetImageIndex) async {
    const maxAttempts = 6;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _images.isEmpty) {
        return;
      }
      final safeImageIndex = math.max(
        0,
        math.min(targetImageIndex, _images.length - 1),
      );
      final target = _normalizeSpreadIndex(safeImageIndex ~/ _readerSpreadSize);
      _currentPageIndex = target;
      _setDisplayedPageIndex(target);

      if (_readerMode == ReaderMode.rightToLeft) {
        if (!_pageController.hasClients) {
          continue;
        }
        _pageController.jumpToPage(target);
        _logReaderEvent(
          'Reader position synced after pinch toggle',
          source: 'reader_navigation',
          content: _readerLogPayload({
            'targetPageIndex': target,
            'targetPage': target + 1,
            'syncPath': 'page_controller_jump',
            'attempt': attempt,
          }),
        );
        _logVisiblePageChange(
          index: target,
          trigger: 'pinch_to_zoom_toggle_sync',
        );
        return;
      }

      if (!_scrollController.hasClients) {
        continue;
      }
      await _scrollToListReaderPage(
        target,
        animate: false,
        trigger: 'pinch_to_zoom_toggle_sync_attempt_$attempt',
      );
      if (!mounted) {
        return;
      }
      _logReaderEvent(
        'Reader position synced after pinch toggle',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'targetPageIndex': target,
          'targetPage': target + 1,
          'syncPath': 'list_scroll_alignment',
          'attempt': attempt,
        }),
      );
      _logVisiblePageChange(
        index: target,
        trigger: 'pinch_to_zoom_toggle_sync',
      );
      return;
    }

    _logReaderEvent(
      'Reader position sync after pinch toggle skipped',
      level: 'warning',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'targetImageIndex': targetImageIndex,
        'targetImage': _images.isEmpty ? 0 : targetImageIndex + 1,
        'reason': _readerMode == ReaderMode.rightToLeft
            ? 'page_controller_unavailable'
            : 'scroll_controller_unavailable',
      }),
    );
  }
}
