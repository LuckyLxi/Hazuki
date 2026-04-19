import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import 'reader_controller_support.dart';
import 'reader_display_bridge.dart';
import 'reader_image_pipeline_controller.dart';
import 'reader_runtime_state.dart';
import 'reader_settings_store.dart';

class ReaderSessionController {
  ReaderSessionController({
    required ReaderRuntimeState runtimeState,
    required ReaderDisplayBridge displayBridge,
    required ReaderSettingsStore settingsStore,
    required ScrollController scrollController,
    required PageController pageController,
    required FocusNode readerKeyFocusNode,
    required TransformationController zoomController,
    required ReaderImagePipelineController imagePipelineController,
    required ReaderIsMounted isMounted,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required void Function() onScrollPositionChanged,
    required void Function() onZoomChanged,
    required String comicId,
    required String epId,
    required String chapterTitle,
    required int chapterIndex,
    required List<String> widgetImages,
  }) : _runtimeState = runtimeState,
       _displayBridge = displayBridge,
       _settingsStore = settingsStore,
       _scrollController = scrollController,
       _pageController = pageController,
       _readerKeyFocusNode = readerKeyFocusNode,
       _zoomController = zoomController,
       _imagePipelineController = imagePipelineController,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _onScrollPositionChanged = onScrollPositionChanged,
       _onZoomChanged = onZoomChanged,
       _comicId = comicId,
       _epId = epId,
       _chapterTitle = chapterTitle,
       _chapterIndex = chapterIndex,
       _widgetImages = widgetImages;

  final ReaderRuntimeState _runtimeState;
  final ReaderDisplayBridge _displayBridge;
  final ReaderSettingsStore _settingsStore;
  final ScrollController _scrollController;
  final PageController _pageController;
  final FocusNode _readerKeyFocusNode;
  final TransformationController _zoomController;
  final ReaderImagePipelineController _imagePipelineController;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final void Function() _onScrollPositionChanged;
  final void Function() _onZoomChanged;
  final String _comicId;
  final String _epId;
  final String _chapterTitle;
  final int _chapterIndex;
  final List<String> _widgetImages;

  void initialize() {
    _displayBridge.attach();
    hazukiNoImageModeNotifier.addListener(
      _imagePipelineController.handleNoImageModeChanged,
    );
    _scrollController.addListener(_onScrollPositionChanged);
    _zoomController.addListener(_onZoomChanged);
    unawaited(loadReadingSettings());
    unawaited(_recordReadingProgress());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted()) {
        _readerKeyFocusNode.requestFocus();
      }
    });

    final initialImages = _widgetImages
        .where((entry) => entry.trim().isNotEmpty)
        .toList();
    _logEvent(
      'Reader session started',
      source: 'reader_lifecycle',
      content: _logPayload({
        'incomingImageCount': _widgetImages.length,
        'hasInitialImages': initialImages.isNotEmpty,
      }),
    );
    if (initialImages.isNotEmpty) {
      _imagePipelineController.applyInitialImages(
        initialImages,
        trigger: 'constructor_images',
      );
      return;
    }
    unawaited(
      _imagePipelineController.loadChapterImages(trigger: 'initial_load'),
    );
  }

  void dispose() {
    _displayBridge.detach();
    hazukiNoImageModeNotifier.removeListener(
      _imagePipelineController.handleNoImageModeChanged,
    );
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    _pageController.dispose();
    _readerKeyFocusNode.dispose();
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _runtimeState.pageIndexNotifier.dispose();
    _imagePipelineController.dispose();
    _logEvent(
      'Reader session closed',
      source: 'reader_lifecycle',
      content: _logPayload({
        'lastVisiblePageIndex': _runtimeState.pageIndexNotifier.value,
        'lastVisiblePage': _runtimeState.readerSpreadCount <= 0
            ? 0
            : _runtimeState.pageIndexNotifier.value + 1,
      }),
    );
    unawaited(restoreReaderDisplay());
  }

  Future<void> loadReadingSettings() async {
    final settings = await _settingsStore.load();
    if (!_isMounted()) {
      return;
    }
    _updateState(() {
      _runtimeState.applySettingsSnapshot(settings);
    });
    _logEvent(
      'Reader settings loaded',
      source: 'reader_settings',
      content: _logPayload({'settingsLoaded': true}),
    );
    await applyReaderDisplaySettings();
    await syncVolumeButtonPagingPlatformState();
  }

  Future<void> applyReaderDisplaySettings() {
    return ReaderDisplayBridge.controller.apply(
      immersiveMode: _runtimeState.immersiveMode,
      keepScreenOn: _runtimeState.keepScreenOn,
      customBrightness: _runtimeState.customBrightness,
      brightnessValue: _runtimeState.brightnessValue,
    );
  }

  Future<void> syncVolumeButtonPagingPlatformState({bool? enabled}) {
    return ReaderDisplayBridge.controller.syncVolumeButtonPaging(
      enabled: enabled ?? _runtimeState.volumeButtonTurnPage,
      sessionId: _displayBridge.sessionId,
    );
  }

  Future<void> restoreReaderDisplay() {
    return ReaderDisplayBridge.controller.restore(
      sessionId: _displayBridge.sessionId,
    );
  }

  Future<void> _recordReadingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = {
        'epId': _epId,
        'title': _chapterTitle,
        'index': _chapterIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('reading_progress_$_comicId', jsonEncode(progress));
    } catch (_) {}
  }
}
