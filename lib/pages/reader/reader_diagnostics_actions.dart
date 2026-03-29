part of '../reader_page.dart';

extension _ReaderDiagnosticsActionsExtension on _ReaderPageState {
  double _normalizeLogDouble(num value) => normalizeReaderLogDouble(value);

  List<Map<String, dynamic>> _captureRenderedItemsAround(int anchorIndex) {
    return captureReaderRenderedItemsAround(
      images: _images,
      itemKeys: _itemKeys,
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
            _pageController.page ?? _currentPageIndex.toDouble(),
          )
        : null;
    return ReaderDiagnosticsSnapshot(
      readerSessionId: _readerSessionId,
      comicId: widget.comicId,
      epId: widget.epId,
      chapterTitle: widget.chapterTitle,
      chapterIndex: widget.chapterIndex,
      readerMode: _readerMode.prefsValue,
      currentPageIndex: _currentPageIndex,
      currentPage: _images.isEmpty
          ? 0
          : math.min(_currentPageIndex + 1, _images.length),
      pageIndicatorIndex: _pageIndexNotifier.value,
      totalPages: _images.length,
      controlsVisible: _controlsVisible,
      tapToTurnPage: _tapToTurnPage,
      pageIndicator: _pageIndicator,
      pinchToZoom: _pinchToZoom,
      longPressToSave: _longPressToSave,
      immersiveMode: _immersiveMode,
      keepScreenOn: _keepScreenOn,
      customBrightness: _customBrightness,
      brightnessValue: _brightnessValue,
      loadingImages: _loadingImages,
      loadImagesError: _loadImagesError,
      noImageModeEnabled: _noImageModeEnabled,
      isZoomed: _isZoomed,
      zoomInteracting: _zoomInteracting,
      zoomScale: _normalizeLogDouble(_zoomController.value.getMaxScaleOnAxis()),
      activePointerCount: _activePointerCount,
      providerCacheSize: _providerCache.length,
      providerFutureCacheSize: _providerFutureCache.length,
      aspectRatioCacheSize: _imageAspectRatioCache.length,
      prefetchAheadRunning: _prefetchAheadRunning,
      activeUnscrambleTasks: _activeUnscrambleTasks,
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

  void _logListPositionSnapshot(
    String title, {
    required String trigger,
    double? previousPixels,
    int? normalizedIndex,
    String level = 'info',
    Map<String, dynamic>? extra,
  }) {
    final payload = <String, dynamic>{
      'trigger': trigger,
      'diagnosticSequence': _diagnosticsState.nextDiagnosticSequence(),
      if (previousPixels != null)
        'previousListPixels': _normalizeLogDouble(previousPixels),
    };
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      payload.addAll({
        'currentListPixels': _normalizeLogDouble(position.pixels),
        if (previousPixels != null)
          'listDeltaPixels': _normalizeLogDouble(
            position.pixels - previousPixels,
          ),
        'listMaxScrollExtent': _normalizeLogDouble(position.maxScrollExtent),
        'listViewportDimension': _normalizeLogDouble(
          position.viewportDimension,
        ),
        'listExtentBefore': _normalizeLogDouble(position.extentBefore),
        'listExtentAfter': _normalizeLogDouble(position.extentAfter),
        'listAtEdge': position.atEdge,
        'listOutOfRange': position.outOfRange,
        'listUserDirection': position.userScrollDirection.name,
        'nearbyRenderedItems': _captureRenderedItemsAround(
          normalizedIndex ?? _currentPageIndex,
        ),
      });
    } else {
      payload['listHasClients'] = false;
    }
    if (extra != null) {
      payload.addAll(extra);
    }
    _logReaderEvent(
      title,
      level: level,
      source: 'reader_position',
      content: _readerLogPayload(payload),
    );
  }

  bool _shouldLogUnexpectedListJump() =>
      _diagnosticsState.shouldLogUnexpectedListJump();

  void _markProgrammaticListScrollCompleted(int target) {
    _diagnosticsState.markProgrammaticListScrollCompleted(target);
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
    if (_images.isEmpty) {
      return;
    }
    final normalizedIndex = math.max(0, math.min(index, _images.length - 1));
    if (_diagnosticsState.lastLoggedVisiblePageIndex == normalizedIndex) {
      return;
    }
    _diagnosticsState.lastLoggedVisiblePageIndex = normalizedIndex;
    _logReaderEvent(
      'Reader visible page changed',
      source: 'reader_position',
      content: _readerLogPayload({
        'trigger': trigger,
        'pageIndex': normalizedIndex,
        'page': normalizedIndex + 1,
        if (_readerMode == ReaderMode.topToBottom)
          'nearbyRenderedItems': _captureRenderedItemsAround(normalizedIndex),
      }),
    );
  }

  void _handleBrightnessChangeEnd(double value) {
    final normalized = math.max(0.0, math.min(value, 1.0));
    _logReaderEvent(
      'Reader brightness adjusted',
      source: 'reader_settings',
      content: _readerLogPayload({
        'setting': 'brightness',
        'value': normalized,
        'brightnessPercent': (normalized * 100).round(),
      }),
    );
  }

  void _handleBackPressed() {
    _logReaderEvent('Reader back pressed', source: 'reader_navigation');
    Navigator.of(context).maybePop();
  }
}
