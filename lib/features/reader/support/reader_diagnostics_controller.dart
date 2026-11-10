import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import '../state/reader_scroll_state.dart';

typedef ReaderDiagnosticLogSink =
    void Function(String title, {String level, String source, Object? content});

class ReaderDiagnosticsController {
  ReaderDiagnosticsController({
    required ReaderRuntimeState runtimeState,
    required ReaderImagePipelineState imagePipelineState,
    required ReaderDiagnosticsState diagnosticsState,
    required ReaderScrollState scrollState,
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
       _scrollState = scrollState,
       _scrollController = scrollController,
       _pageController = pageController,
       _zoomController = zoomController,
       _sessionId = sessionId,
       _noImageModeEnabled = noImageModeEnabled,
       _log = log;

  final ReaderRuntimeState _runtimeState;
  final ReaderImagePipelineState _imagePipelineState;
  final ReaderDiagnosticsState _diagnosticsState;
  final ReaderScrollState _scrollState;
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

  Map<String, dynamic> buildLogPayload([Map<String, dynamic>? extra]) {
    final lastObservedListPixels = _scrollState.lastObservedListPixels;
    final payload = <String, dynamic>{
      'sessionId': _sessionId(),
      'comicId': comicId,
      'epId': epId,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'readerMode': _runtimeState.readerMode.prefsValue,
      'doublePageMode': _runtimeState.doublePageMode,
      'currentPageIndex': _runtimeState.currentPageIndex,
      'currentPage': _runtimeState.images.isEmpty
          ? 0
          : math.min(
              _runtimeState.currentPageIndex + 1,
              _runtimeState.readerSpreadCount,
            ),
      'pageIndicatorIndex': _runtimeState.pageIndexNotifier.value,
      'totalPages': _runtimeState.readerSpreadCount,
      'controlsVisible': _runtimeState.controlsVisible,
      'tapToTurnPage': _runtimeState.tapToTurnPage,
      'pageIndicator': _runtimeState.pageIndicator,
      'pinchToZoom': _runtimeState.pinchToZoom,
      'immersiveMode': _runtimeState.immersiveMode,
      'keepScreenOn': _runtimeState.keepScreenOn,
      'customBrightness': _runtimeState.customBrightness,
      'brightnessValue': _runtimeState.brightnessValue,
      'loadingImages': _runtimeState.loadingImages,
      'loadImagesError': _runtimeState.loadImagesError,
      'noImageModeEnabled': _noImageModeEnabled(),
      'isZoomed': _runtimeState.isZoomed,
      'zoomInteracting': _runtimeState.zoomInteracting,
      'zoomScale': normalizeReaderLogDouble(
        _zoomController.value.getMaxScaleOnAxis(),
      ),
      'activePointerCount': _runtimeState.activePointerCount,
      'providerCacheSize': _imagePipelineState.providerCache.length,
      'providerFutureCacheSize': _imagePipelineState.providerFutureCache.length,
      'aspectRatioCacheSize': _imagePipelineState.imageAspectRatioCache.length,
      'prefetchAheadRunning': _imagePipelineState.prefetchAheadRunning,
      'activeUnscrambleTasks': _imagePipelineState.activeUnscrambleTasks,
      'listUserScrollInProgress': _scrollState.listUserScrollInProgress,
      'activeProgrammaticListScrollReason':
          _scrollState.activeProgrammaticListScrollReason,
      'activeProgrammaticListTargetIndex':
          _scrollState.activeProgrammaticListTargetIndex,
      'lastCompletedProgrammaticListTargetIndex':
          _scrollState.lastCompletedProgrammaticListTargetIndex,
      if (lastObservedListPixels != null)
        'lastObservedListPixels': normalizeReaderLogDouble(
          lastObservedListPixels,
        ),
    };
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      payload.addAll({
        'listPixels': normalizeReaderLogDouble(position.pixels),
        'listMaxScrollExtent': normalizeReaderLogDouble(
          position.maxScrollExtent,
        ),
        'listMinScrollExtent': normalizeReaderLogDouble(
          position.minScrollExtent,
        ),
        'listViewportDimension': normalizeReaderLogDouble(
          position.viewportDimension,
        ),
        'listExtentBefore': normalizeReaderLogDouble(position.extentBefore),
        'listExtentAfter': normalizeReaderLogDouble(position.extentAfter),
        'listAtEdge': position.atEdge,
        'listOutOfRange': position.outOfRange,
        'listUserDirection': position.userScrollDirection.name,
      });
    }
    if (_pageController.hasClients) {
      payload['pageControllerPage'] = normalizeReaderLogDouble(
        _pageController.page ?? _runtimeState.currentPageIndex.toDouble(),
      );
    }
    if (extra != null) {
      payload.addAll(extra);
    }
    return payload;
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
