import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_settings_store.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

class ReaderSessionController {
  ReaderSessionController({
    required ReaderRuntimeState runtimeState,
    required ReaderDisplayBridge displayBridge,
    required ReaderSettingsStore settingsStore,
    required ScrollController scrollController,
    required PageController pageController,
    required FocusNode readerKeyFocusNode,
    required TransformationController zoomController,
    required void Function(List<String> images, {required String trigger})
    applyInitialImages,
    required Future<void> Function({String trigger}) loadChapterImages,
    required VoidCallback onNoImageModeChanged,
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
    required HazukiSourceService sourceService,
  }) : _runtimeState = runtimeState,
       _displayBridge = displayBridge,
       _settingsStore = settingsStore,
       _scrollController = scrollController,
       _pageController = pageController,
       _readerKeyFocusNode = readerKeyFocusNode,
       _zoomController = zoomController,
       _applyInitialImages = applyInitialImages,
       _loadChapterImages = loadChapterImages,
       _onNoImageModeChanged = onNoImageModeChanged,
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
       _widgetImages = widgetImages,
       _sourceService = sourceService;

  final ReaderRuntimeState _runtimeState;
  final ReaderDisplayBridge _displayBridge;
  final ReaderSettingsStore _settingsStore;
  final ScrollController _scrollController;
  final PageController _pageController;
  final FocusNode _readerKeyFocusNode;
  final TransformationController _zoomController;
  final void Function(List<String> images, {required String trigger})
  _applyInitialImages;
  final Future<void> Function({String trigger}) _loadChapterImages;
  final VoidCallback _onNoImageModeChanged;
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
  final HazukiSourceService _sourceService;

  Future<ComicDetailsData> loadComicDetails(String comicId) =>
      _sourceService.loadComicDetails(comicId);

  Future<PreparedChapterImageData> prepareImageForSave(
    String imageUrl, {
    required String comicId,
    required String epId,
  }) => _sourceService.prepareChapterImageData(
    imageUrl,
    comicId: comicId,
    epId: epId,
  );

  bool isLocalImagePath(String value) => _sourceService.isLocalImagePath(value);

  String normalizeLocalImagePath(String value) =>
      _sourceService.normalizeLocalImagePath(value);

  void log(
    String title, {
    String level = 'info',
    String source = 'reader_ui',
    Object? content,
  }) {
    _sourceService.addReaderLog(
      level: level,
      title: title,
      source: source,
      content: content,
    );
  }

  void initialize() {
    _displayBridge.attach();
    hazukiNoImageModeNotifier.addListener(_onNoImageModeChanged);
    _scrollController.addListener(_onScrollPositionChanged);
    _zoomController.addListener(_onZoomChanged);
    unawaited(loadReadingSettings());
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
      _applyInitialImages(initialImages, trigger: 'constructor_images');
      return;
    }
    unawaited(_loadChapterImages(trigger: 'initial_load'));
  }

  void dispose() {
    final lastVisiblePageIndex = _runtimeState.pageIndexNotifier.value;
    _displayBridge.detach();
    hazukiNoImageModeNotifier.removeListener(_onNoImageModeChanged);
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    _pageController.dispose();
    _readerKeyFocusNode.dispose();
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _runtimeState.pageIndexNotifier.dispose();
    _logEvent(
      'Reader session closed',
      source: 'reader_lifecycle',
      content: _logPayload({
        'lastVisiblePageIndex': lastVisiblePageIndex,
        'lastVisiblePage': _runtimeState.readerSpreadCount <= 0
            ? 0
            : lastVisiblePageIndex + 1,
      }),
    );
    unawaited(_recordReadingProgress(lastPageIndex: lastVisiblePageIndex));
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

  Future<void> _recordReadingProgress({int lastPageIndex = 0}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = {
        'epId': _epId,
        'title': _chapterTitle,
        'index': _chapterIndex,
        'pageIndex': lastPageIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('reading_progress_$_comicId', jsonEncode(progress));
    } catch (_) {}
  }
}
