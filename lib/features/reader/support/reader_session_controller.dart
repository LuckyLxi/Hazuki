import 'dart:async';

import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/features/reader/support/reader_view_bindings.dart';

class ReaderSessionController {
  ReaderSessionController({
    required ReaderRuntimeState runtimeState,
    required ReaderDisplayBridge displayBridge,
    required ReaderDisplaySession displaySession,
    required ReaderSettingsStore settingsStore,
    required ReaderViewBindings viewBindings,
    required void Function(List<String> images, {required String trigger})
    applyInitialImages,
    required Future<void> Function({String trigger}) loadChapterImages,
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
  }) : _runtimeState = runtimeState,
       _displayBridge = displayBridge,
       _displaySession = displaySession,
       _settingsStore = settingsStore,
       _viewBindings = viewBindings,
       _applyInitialImages = applyInitialImages,
       _loadChapterImages = loadChapterImages,
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
  final void Function(List<String> images, {required String trigger})
  _applyInitialImages;
  final Future<void> Function({String trigger}) _loadChapterImages;
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

  void initialize() {
    _displayBridge.attach();
    _viewBindings.attach();
    unawaited(loadReadingSettings());
    _viewBindings.requestFocusAfterFrame(isMounted: _isMounted);

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
    unawaited(_loadChapterImages(trigger: 'initial_load'));
  }

  void dispose() {
    _closed = true;
    _displaySession.close();
    final lastVisiblePageIndex = _runtimeState.pageIndexNotifier.value;
    _displayBridge.detach();
    _viewBindings.dispose();
    _runtimeState.dispose();
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
    if (_closed || !_isMounted()) {
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
    if (_closed) {
      return;
    }
    await syncVolumeButtonPagingPlatformState();
  }

  Future<void> applyReaderDisplaySettings() => _displaySession.apply();

  Future<void> syncVolumeButtonPagingPlatformState({bool? enabled}) =>
      _displaySession.syncVolumeButtonPaging(enabled: enabled);

  Future<void> restoreReaderDisplay() => _displaySession.restore();

  Future<void> _recordReadingProgress({int lastPageIndex = 0}) async {
    try {
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
