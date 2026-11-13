import 'dart:async';

import 'package:flutter/scheduler.dart';

import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_progress_reporter.dart';
import 'package:hazuki/features/reader/support/reader_translation_controller.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/state/reader_entry_restore_state.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class ReaderSessionController {
  ReaderSessionController({
    required ReaderRuntimeState runtimeState,
    required ReaderDisplayBridge displayBridge,
    required ReaderDisplaySession displaySession,
    required ReaderSettingsStore settingsStore,
    required ReaderSyncPositionToImageIndex syncPositionToImageIndex,
    required void Function() requestViewportReport,
    required bool Function() noImageModeEnabled,
    required ReaderImagePipelineController imagePipeline,
    required ReaderActionsController actions,
    required ReaderProgressReporter progressReporter,
    ReaderTranslationController? translation,
    required ReaderIsMounted isMounted,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required String comicId,
    required String epId,
    String sourceKey = '',
    required String chapterTitle,
    required int chapterIndex,
    required List<String> widgetImages,
    required ReadingProgressService readingProgressService,
    bool offlineMode = false,
    SourceCloudReadingGateway? cloudReading,
  }) : _runtimeState = runtimeState,
       _displayBridge = displayBridge,
       _displaySession = displaySession,
       _settingsStore = settingsStore,
       _syncPositionToImageIndex = syncPositionToImageIndex,
       _requestViewportReport = requestViewportReport,
       _noImageModeEnabled = noImageModeEnabled,
       _imagePipeline = imagePipeline,
       _actions = actions,
       _progressReporter = progressReporter,
       _translation = translation,
       _cloudReading = cloudReading,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _comicId = comicId,
       _epId = epId,
       _sourceKey = sourceKey,
       _chapterTitle = chapterTitle,
       _chapterIndex = chapterIndex,
       _widgetImages = widgetImages,
       _readingProgressService = readingProgressService,
       _offlineMode = offlineMode;

  final ReaderRuntimeState _runtimeState;
  final ReaderDisplayBridge _displayBridge;
  final ReaderSettingsStore _settingsStore;
  final ReaderSyncPositionToImageIndex _syncPositionToImageIndex;
  final void Function() _requestViewportReport;
  final bool Function() _noImageModeEnabled;
  final ReaderImagePipelineController _imagePipeline;
  final ReaderActionsController _actions;
  final ReaderProgressReporter _progressReporter;
  final ReaderTranslationController? _translation;
  final SourceCloudReadingGateway? _cloudReading;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final String _comicId;
  final String _epId;
  final String _sourceKey;
  final String _chapterTitle;
  final int _chapterIndex;
  final List<String> _widgetImages;
  final ReadingProgressService _readingProgressService;
  final bool _offlineMode;
  final ReaderDisplaySession _displaySession;
  bool _closed = false;
  int? _retiredPageIndex;
  final ReaderEntryRestoreState _entryRestore = ReaderEntryRestoreState();
  bool _entryInitialized = false;
  bool _foreground = true;

  bool get isActive => !_closed && _retiredPageIndex == null;
  bool get restorePagePosition => _entryRestore.restorePagePosition ?? false;

  /// The page supplies inherited route data; all asynchronous restore work
  /// belongs to this chapter and is ignored after it retires.
  void initializeEntry({
    required Map<String, dynamic>? position,
    required bool restoreEntry,
  }) {
    if (!isActive || _entryInitialized) return;
    _entryInitialized = true;
    unawaited(_loadRestorePreference());
    _entryRestore.resolvePosition(position);
    if (_offlineMode && restoreEntry && position == null) {
      _entryRestore.positionReady = false;
      unawaited(_loadOfflineEntryPosition());
    }
    _maybeRestoreEntry();
  }

  Future<void> _loadRestorePreference() async {
    bool enabled;
    try {
      enabled = await _settingsStore.loadRestorePagePosition();
    } catch (_) {
      enabled = false;
    }
    if (!isActive || !_isMounted()) return;
    // A setting changed by the user wins over a late preference read.
    _entryRestore.restorePagePosition ??= enabled;
    _maybeRestoreEntry();
  }

  Future<void> _loadOfflineEntryPosition() async {
    Map<String, dynamic>? position;
    try {
      position = await _readingProgressService.load(
        comicId: _comicId,
        sourceKey: _sourceKey,
      );
    } catch (_) {}
    if (!isActive || !_isMounted()) return;
    _entryRestore.resolvePosition(position);
    _maybeRestoreEntry();
  }

  void setRestorePagePosition(bool value) {
    _entryRestore.restorePagePosition = value;
    unawaited(_settingsStore.saveRestorePagePosition(value));
  }

  void cancelEntryRestore() => _entryRestore.cancel();

  void _maybeRestoreEntry() {
    if (!isActive || !_isMounted() || _entryRestore.started) return;
    final target = _entryRestore.takeTarget(
      epId: _epId,
      imageCount: _runtimeState.imageCount,
      spreadSize: _runtimeState.readerSpreadSize,
    );
    if (!_entryRestore.started) return;
    if (target != null) {
      _syncPositionToImageIndex(target, trigger: 'entry_restore');
    }
    _requestViewportReport();
  }

  void _onImagesChanged() {
    if (!isActive || !_isMounted()) return;
    _maybeRestoreEntry();
    _requestViewportReport();
  }

  Future<void> loadChapterImages({String trigger = 'manual'}) async {
    if (!isActive || !_isMounted()) return;
    _updateState(_runtimeState.markLoadingImages);
    final committed = await _imagePipeline.loadChapterImages(trigger: trigger);
    if (!committed || !isActive || !_isMounted()) return;
    _onImagesChanged();
    _prefetchInitialImages();
  }

  void _prefetchInitialImages() {
    if (!isActive || !_isMounted() || _noImageModeEnabled()) return;
    _imagePipeline.prefetchAround(0);
    _imagePipeline.requestPrefetchAhead(0);
  }

  void _applyInitialImages(List<String> images, {required String trigger}) {
    _imagePipeline.applyInitialImages(images, trigger: trigger);
    _onImagesChanged();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _prefetchInitialImages(),
    );
  }

  void onPageTargetChanged(int index) {
    if (!isActive) return;
    cancelEntryRestore();
    if (_noImageModeEnabled()) return;
    _imagePipeline.prefetchAround(index);
    _translation?.updateWindow(index);
    _imagePipeline.requestPrefetchAhead(index);
  }

  void updateTranslationWindow() {
    if (isActive && _isMounted() && !_noImageModeEnabled()) {
      _translation?.updateWindow(_runtimeState.currentPageIndex);
    }
  }

  void handleNoImageModeChanged() {
    if (!isActive) return;
    _imagePipeline.handleNoImageModeChanged();
    _translation?.reset();
    updateTranslationWindow();
    _requestViewportReport();
  }

  void observeVisibleRange({required int firstImage, required int lastImage}) {
    if (!isActive ||
        !_isMounted() ||
        !_foreground ||
        _offlineMode ||
        _noImageModeEnabled() ||
        !_entryRestore.canReportVisibleRange(firstImage, lastImage)) {
      return;
    }
    _progressReporter.observe(
      firstImage: firstImage,
      lastImage: lastImage,
      totalPages: _runtimeState.imageCount,
    );
  }

  void setForeground(bool foreground) {
    if (!isActive) return;
    if (_foreground && !foreground) _progressReporter.flush('background');
    _foreground = foreground;
  }

  void initialize() {
    _displayBridge.attach();
    unawaited(loadReadingSettings());

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
    if (_offlineMode) {
      _applyInitialImages(
        const <String>[],
        trigger: 'offline_constructor_images',
      );
      return;
    }
    unawaited(loadChapterImages(trigger: 'initial_load'));
  }

  bool retireForChapterChange() {
    if (!isActive) return false;
    _retiredPageIndex = _runtimeState.pageIndexNotifier.value;
    _displaySession.close();
    _progressReporter.close('chapter');
    _imagePipeline.retire();
    _actions.dispose(SourceTaskStopReason.superseded);
    _translation?.retire();
    return true;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    final lastVisiblePageIndex =
        _retiredPageIndex ?? _runtimeState.pageIndexNotifier.value;
    final exitingReader = _retiredPageIndex == null;
    if (exitingReader) _displaySession.close();
    _displayBridge.detach();
    if (exitingReader) {
      _progressReporter.close('exit');
      _imagePipeline.dispose();
      _actions.dispose();
    }
    _translation?.dispose();
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
    if (exitingReader) unawaited(_displaySession.restore());
  }

  Future<void> loadReadingSettings() async {
    final settings = await _settingsStore.load();
    if (!isActive || !_isMounted()) {
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
    await _displaySession.apply();
    if (!isActive) {
      return;
    }
    await _displaySession.syncVolumeButtonPaging();
    if (isActive && _isMounted()) {
      _entryRestore.settingsReady = true;
      _maybeRestoreEntry();
    }
  }

  Future<void> _recordReadingProgress({required int lastPageIndex}) async {
    try {
      if (!_offlineMode &&
          _cloudReading != null &&
          await _cloudReading.usesCloudReading(_sourceKey)) {
        return;
      }
      await _readingProgressService.save(
        comicId: _comicId,
        sourceKey: _sourceKey,
        epId: _epId,
        title: _chapterTitle,
        chapterIndex: _chapterIndex,
        pageIndex: lastPageIndex,
      );
    } catch (_) {}
  }
}
