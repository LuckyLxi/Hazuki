part of '../reader_page.dart';

extension _ReaderLifecycleActionsExtension on _ReaderPageState {
  void _initializeReaderSession() {
    _attachReaderDisplayChannelHandler();
    hazukiNoImageModeNotifier.addListener(_handleNoImageModeChanged);
    _scrollController.addListener(_onScrollPrefetch);
    _zoomController.addListener(_onZoomChanged);
    _resetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    unawaited(_loadReadingSettings());
    unawaited(_recordReadingProgress());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _readerKeyFocusNode.requestFocus();
    });

    final initialImages = widget.images
        .where((e) => e.trim().isNotEmpty)
        .toList();
    _logReaderEvent(
      'Reader session started',
      source: 'reader_lifecycle',
      content: _readerLogPayload({
        'incomingImageCount': widget.images.length,
        'hasInitialImages': initialImages.isNotEmpty,
      }),
    );
    if (initialImages.isNotEmpty) {
      _applyInitialImages(initialImages, trigger: 'constructor_images');
      return;
    }
    unawaited(_loadChapterImages(trigger: 'initial_load'));
  }

  void _disposeReaderSession() {
    _detachReaderDisplayChannelHandler();
    hazukiNoImageModeNotifier.removeListener(_handleNoImageModeChanged);
    _scrollController.removeListener(_onScrollPrefetch);
    _scrollController.dispose();
    _pageController.dispose();
    _readerKeyFocusNode.dispose();
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _resetAnimController.dispose();
    _pageIndexNotifier.dispose();
    for (final waiter in _decodeWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _decodeWaiters.clear();
    _logReaderEvent(
      'Reader session closed',
      source: 'reader_lifecycle',
      content: _readerLogPayload({
        'lastVisiblePageIndex': _pageIndexNotifier.value,
        'lastVisiblePage': _readerSpreadCount <= 0
            ? 0
            : math.min(_pageIndexNotifier.value + 1, _readerSpreadCount),
      }),
    );
    unawaited(_restoreReaderDisplay());
  }

  void _applyInitialImages(List<String> images, {required String trigger}) {
    _zoomController.value = Matrix4.identity();
    _imageAspectRatioCache.clear();
    _images = images;
    _rebuildSpreadItemKeys();
    _rebuildImageIndexMap();
    _loadingImages = false;
    _loadImagesError = null;
    _currentPageIndex = 0;
    _isZoomed = false;
    _zoomInteracting = false;
    _activePointerCount = 0;
    _logReaderEvent(
      'Reader initial images ready',
      source: 'reader_data',
      content: _readerLogPayload({
        'trigger': trigger,
        'imageCount': _images.length,
      }),
    );
    _logVisiblePageChange(index: 0, trigger: trigger);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAround(0);
      _requestPrefetchAhead(0);
    });
  }

  void _handleNoImageModeChanged() {
    _providerCache.clear();
    _providerFutureCache.clear();
    _logReaderEvent(
      'Reader no-image mode changed',
      source: 'reader_data',
      content: _readerLogPayload({
        'enabled': _noImageModeEnabled,
        'providerCachesCleared': true,
      }),
    );
    if (!mounted) {
      return;
    }
    _updateReaderState(() {});
  }

  Future<void> _recordReadingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = {
        'epId': widget.epId,
        'title': widget.chapterTitle,
        'index': widget.chapterIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(
        'reading_progress_${widget.comicId}',
        jsonEncode(progress),
      );
    } catch (_) {}
  }
}
