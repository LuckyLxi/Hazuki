part of 'reader_page.dart';

extension _ReaderPageStateDiagnosticsActions on _ReaderPageState {
  double _normalizeLogDouble(num value) => normalizeReaderLogDouble(value);

  List<Map<String, dynamic>> _captureRenderedItemsAround(int anchorIndex) {
    return captureReaderRenderedItemsAround(
      itemCount: _runtimeState.readerSpreadCount,
      itemKeys: _runtimeState.itemKeys,
      anchorIndex: anchorIndex,
    );
  }

  ReaderDiagnosticsSnapshot _createReaderDiagnosticsSnapshot() {
    final listSnapshot = _scrollController.hasClients
        ? ReaderListDiagnosticsSnapshot(
            pixels: _normalizeLogDouble(_scrollController.position.pixels),
            maxScrollExtent: _normalizeLogDouble(
              _scrollController.position.maxScrollExtent,
            ),
            minScrollExtent: _normalizeLogDouble(
              _scrollController.position.minScrollExtent,
            ),
            viewportDimension: _normalizeLogDouble(
              _scrollController.position.viewportDimension,
            ),
            extentBefore: _normalizeLogDouble(
              _scrollController.position.extentBefore,
            ),
            extentAfter: _normalizeLogDouble(
              _scrollController.position.extentAfter,
            ),
            atEdge: _scrollController.position.atEdge,
            outOfRange: _scrollController.position.outOfRange,
            userDirection: _scrollController.position.userScrollDirection.name,
          )
        : null;
    final pageControllerPage = _pageController.hasClients
        ? _normalizeLogDouble(
            _pageController.page ?? _runtimeState.currentPageIndex.toDouble(),
          )
        : null;
    return ReaderDiagnosticsSnapshot(
      readerSessionId: _displayBridge.sessionId,
      comicId: widget.comicId,
      epId: widget.epId,
      chapterTitle: widget.chapterTitle,
      chapterIndex: widget.chapterIndex,
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
      noImageModeEnabled: _noImageModeEnabled,
      isZoomed: _runtimeState.isZoomed,
      zoomInteracting: _runtimeState.zoomInteracting,
      zoomScale: _normalizeLogDouble(_zoomController.value.getMaxScaleOnAxis()),
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
          : _normalizeLogDouble(_diagnosticsState.lastObservedListPixels!),
      pageControllerPage: pageControllerPage,
      listSnapshot: listSnapshot,
    );
  }

  Map<String, dynamic> _readerLogPayload([Map<String, dynamic>? extra]) {
    return buildReaderLogPayload(
      snapshot: _createReaderDiagnosticsSnapshot(),
      extra: extra,
    );
  }

  void _logReaderEvent(
    String title, {
    String level = 'info',
    String source = 'reader_ui',
    Object? content,
  }) {
    HazukiSourceService.instance.addReaderLog(
      level: level,
      title: title,
      source: source,
      content: content ?? _readerLogPayload(),
    );
  }

  void _logVisiblePageChange({required int index, required String trigger}) {
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
    _logReaderEvent(
      'Reader visible page changed',
      source: 'reader_position',
      content: _readerLogPayload({
        'trigger': trigger,
        'pageIndex': safeIndex,
        'page': safeIndex + 1,
        'visibleImageIndices': _runtimeState.spreadImageIndices(safeIndex),
        if (_runtimeState.readerMode == ReaderMode.topToBottom)
          'nearbyRenderedItems': _captureRenderedItemsAround(safeIndex),
      }),
    );
  }
}
