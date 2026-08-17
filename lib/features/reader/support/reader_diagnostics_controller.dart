import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';

typedef ReaderDiagnosticLogSink =
    void Function(String title, {String level, String source, Object? content});

class ReaderDiagnosticsController {
  ReaderDiagnosticsController({
    required ReaderRuntimeState runtimeState,
    required ReaderImagePipelineState imagePipelineState,
    required ReaderDiagnosticsState diagnosticsState,
    required ScrollController scrollController,
    required PageController pageController,
    required TransformationController zoomController,
    required String Function() sessionId,
    required bool Function() noImageModeEnabled,
    required ReaderDiagnosticLogSink log,
    required this.comicId,
    required this.epId,
    required this.chapterTitle,
    required this.chapterIndex,
  }) : _runtimeState = runtimeState,
       _imagePipelineState = imagePipelineState,
       _diagnosticsState = diagnosticsState,
       _scrollController = scrollController,
       _pageController = pageController,
       _zoomController = zoomController,
       _sessionId = sessionId,
       _noImageModeEnabled = noImageModeEnabled,
       _log = log;

  final ReaderRuntimeState _runtimeState;
  final ReaderImagePipelineState _imagePipelineState;
  final ReaderDiagnosticsState _diagnosticsState;
  final ScrollController _scrollController;
  final PageController _pageController;
  final TransformationController _zoomController;
  final String Function() _sessionId;
  final bool Function() _noImageModeEnabled;
  final ReaderDiagnosticLogSink _log;
  final String comicId;
  final String epId;
  final String chapterTitle;
  final int chapterIndex;

  ReaderDiagnosticsSnapshot createSnapshot() {
    final listSnapshot = _scrollController.hasClients
        ? ReaderListDiagnosticsSnapshot(
            pixels: normalizeReaderLogDouble(_scrollController.position.pixels),
            maxScrollExtent: normalizeReaderLogDouble(
              _scrollController.position.maxScrollExtent,
            ),
            minScrollExtent: normalizeReaderLogDouble(
              _scrollController.position.minScrollExtent,
            ),
            viewportDimension: normalizeReaderLogDouble(
              _scrollController.position.viewportDimension,
            ),
            extentBefore: normalizeReaderLogDouble(
              _scrollController.position.extentBefore,
            ),
            extentAfter: normalizeReaderLogDouble(
              _scrollController.position.extentAfter,
            ),
            atEdge: _scrollController.position.atEdge,
            outOfRange: _scrollController.position.outOfRange,
            userDirection: _scrollController.position.userScrollDirection.name,
          )
        : null;
    final pageControllerPage = _pageController.hasClients
        ? normalizeReaderLogDouble(
            _pageController.page ?? _runtimeState.currentPageIndex.toDouble(),
          )
        : null;
    return ReaderDiagnosticsSnapshot(
      readerSessionId: _sessionId(),
      comicId: comicId,
      epId: epId,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      readerMode: _runtimeState.readerMode.prefsValue,
      doublePageMode: _runtimeState.doublePageMode,
      currentPageIndex: _runtimeState.currentPageIndex,
      currentPage: _runtimeState.images.isEmpty
          ? 0
          : math.min(
              _runtimeState.currentPageIndex + 1,
              _runtimeState.readerSpreadCount,
            ),
      pageIndicatorIndex: _runtimeState.pageIndexNotifier.value,
      totalPages: _runtimeState.readerSpreadCount,
      controlsVisible: _runtimeState.controlsVisible,
      tapToTurnPage: _runtimeState.tapToTurnPage,
      pageIndicator: _runtimeState.pageIndicator,
      pinchToZoom: _runtimeState.pinchToZoom,
      longPressToSave: _runtimeState.longPressToSave,
      immersiveMode: _runtimeState.immersiveMode,
      keepScreenOn: _runtimeState.keepScreenOn,
      customBrightness: _runtimeState.customBrightness,
      brightnessValue: _runtimeState.brightnessValue,
      loadingImages: _runtimeState.loadingImages,
      loadImagesError: _runtimeState.loadImagesError,
      noImageModeEnabled: _noImageModeEnabled(),
      isZoomed: _runtimeState.isZoomed,
      zoomInteracting: _runtimeState.zoomInteracting,
      zoomScale: normalizeReaderLogDouble(
        _zoomController.value.getMaxScaleOnAxis(),
      ),
      activePointerCount: _runtimeState.activePointerCount,
      providerCacheSize: _imagePipelineState.providerCache.length,
      providerFutureCacheSize: _imagePipelineState.providerFutureCache.length,
      aspectRatioCacheSize: _imagePipelineState.imageAspectRatioCache.length,
      prefetchAheadRunning: _imagePipelineState.prefetchAheadRunning,
      activeUnscrambleTasks: _imagePipelineState.activeUnscrambleTasks,
      listUserScrollInProgress: _diagnosticsState.listUserScrollInProgress,
      activeProgrammaticListScrollReason:
          _diagnosticsState.activeProgrammaticListScrollReason,
      activeProgrammaticListTargetIndex:
          _diagnosticsState.activeProgrammaticListTargetIndex,
      lastCompletedProgrammaticListTargetIndex:
          _diagnosticsState.lastCompletedProgrammaticListTargetIndex,
      lastObservedListPixels: _diagnosticsState.lastObservedListPixels == null
          ? null
          : normalizeReaderLogDouble(_diagnosticsState.lastObservedListPixels!),
      pageControllerPage: pageControllerPage,
      listSnapshot: listSnapshot,
    );
  }

  Map<String, dynamic> buildLogPayload([Map<String, dynamic>? extra]) {
    return buildReaderLogPayload(snapshot: createSnapshot(), extra: extra);
  }

  void logEvent(
    String title, {
    String level = 'info',
    String source = 'reader_ui',
    Object? content,
  }) {
    _log(
      title,
      level: level,
      source: source,
      content: content ?? buildLogPayload(),
    );
  }

  void logVisiblePageChange({required int index, required String trigger}) {
    if (_runtimeState.images.isEmpty) {
      return;
    }
    final normalizedIndex = math.max(
      0,
      math.min(index, _runtimeState.readerSpreadCount - 1),
    );
    final safeIndex = _runtimeState.normalizeSpreadIndex(normalizedIndex);
    if (_diagnosticsState.lastLoggedVisiblePageIndex == safeIndex) {
      return;
    }
    _diagnosticsState.lastLoggedVisiblePageIndex = safeIndex;
    logEvent(
      'Reader visible page changed',
      source: 'reader_position',
      content: buildLogPayload({
        'trigger': trigger,
        'pageIndex': safeIndex,
        'page': safeIndex + 1,
        'visibleImageIndices': _runtimeState.spreadImageIndices(safeIndex),
        if (_runtimeState.readerMode == ReaderMode.topToBottom)
          'nearbyRenderedItems': captureReaderRenderedItemsAround(
            itemCount: _runtimeState.readerSpreadCount,
            itemKeys: _runtimeState.itemKeys,
            anchorIndex: safeIndex,
          ),
      }),
    );
  }
}
