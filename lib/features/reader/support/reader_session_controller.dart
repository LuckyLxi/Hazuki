import 'dart:async';

import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_progress_reporter.dart';
import 'package:hazuki/features/reader/support/reader_translation_controller.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/features/reader/support/reader_view_bindings.dart';

class ReaderSessionController {
  ReaderSessionController({
    required ReaderRuntimeState runtimeState,
    required ReaderDisplayBridge displayBridge,
    required ReaderDisplaySession displaySession,
    required ReaderSettingsStore settingsStore,
    required ReaderViewBindings viewBindings,
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
    this.onSettingsReady,
  }) : _runtimeState = runtimeState,
       _displayBridge = displayBridge,
       _displaySession = displaySession,
       _settingsStore = settingsStore,
       _viewBindings = viewBindings,
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
  final ReaderViewBindings _viewBindings;
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
  final void Function()? onSettingsReady;

  bool get isActive => !_closed && _retiredPageIndex == null;

  void initialize() {
    _displayBridge.attach();
    _viewBindings.attach();
    unawaited(loadReadingSettings());
    _viewBindings.requestFocusAfterFrame(
      isMounted: () => isActive && _isMounted(),
    );

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
      _imagePipeline.applyInitialImages(
        initialImages,
        trigger: 'constructor_images',
      );
      return;
    }
    if (_offlineMode) {
      _imagePipeline.applyInitialImages(
        const <String>[],
        trigger: 'offline_constructor_images',
      );
      return;
    }
    unawaited(_imagePipeline.loadChapterImages(trigger: 'initial_load'));
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
    _viewBindings.dispose();
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
    if (isActive) onSettingsReady?.call();
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
