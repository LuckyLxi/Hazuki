part of '../reader_page.dart';

extension _ReaderImagePipelineExtension on _ReaderPageState {
  void _rebuildImageIndexMap() {
    _imageIndexMap
      ..clear()
      ..addEntries(
        _images.asMap().entries.map((entry) {
          return MapEntry(entry.value, entry.key);
        }),
      );
  }

  void _trimProviderCachesAround(int centerIndex) {
    final keepStart = centerIndex - _ReaderPageState._providerKeepBehindCount;
    final keepEnd = centerIndex + _ReaderPageState._providerKeepAheadCount;

    final staleProviderKeys = <String>[];
    _providerCache.forEach((key, _) {
      final index = _imageIndexMap[key];
      if (index == null || index < keepStart || index > keepEnd) {
        staleProviderKeys.add(key);
      }
    });
    for (final key in staleProviderKeys) {
      _providerCache.remove(key);
    }

    final staleFutureKeys = <String>[];
    _providerFutureCache.forEach((key, _) {
      final index = _imageIndexMap[key];
      if (index == null || index < keepStart || index > keepEnd) {
        staleFutureKeys.add(key);
      }
    });
    for (final key in staleFutureKeys) {
      _providerFutureCache.remove(key);
    }

    final staleByteUrls = <String>[];
    for (var i = 0; i < _images.length; i++) {
      if (i < keepStart || i > keepEnd) {
        staleByteUrls.add(_images[i]);
      }
    }
    if (staleByteUrls.isNotEmpty) {
      HazukiSourceService.instance.evictImageBytesFromMemory(staleByteUrls);
    }
  }

  Future<void> _loadChapterImages({String trigger = 'manual'}) async {
    _logReaderEvent(
      'Reader chapter images loading started',
      source: 'reader_data',
      content: _readerLogPayload({'trigger': trigger}),
    );
    try {
      final images = await HazukiSourceService.instance.loadChapterImages(
        comicId: widget.comicId,
        epId: widget.epId,
      );
      if (!mounted) {
        return;
      }
      _updateReaderState(() {
        _zoomController.value = Matrix4.identity();
        _imageAspectRatioCache.clear();
        _images = images.where((e) => e.trim().isNotEmpty).toList();
        _itemKeys.clear();
        _itemKeys.addAll(List.generate(_images.length, (_) => GlobalKey()));
        _rebuildImageIndexMap();
        _loadingImages = false;
        _loadImagesError = null;
        _currentPageIndex = 0;
        _isZoomed = false;
        _zoomInteracting = false;
        _activePointerCount = 0;
      });
      _diagnosticsState.lastLoggedVisiblePageIndex = -1;
      _logReaderEvent(
        'Reader chapter images loading finished',
        source: 'reader_data',
        content: _readerLogPayload({
          'trigger': trigger,
          'imageCount': _images.length,
        }),
      );
      _setDisplayedPageIndex(0);
      _logVisiblePageChange(index: 0, trigger: 'chapter_images_loaded');
      if (!_noImageModeEnabled) {
        _prefetchAround(0);
        _requestPrefetchAhead(0);
      }
    } catch (e) {
      _logReaderEvent(
        'Reader chapter images loading failed',
        level: 'error',
        source: 'reader_data',
        content: _readerLogPayload({'trigger': trigger, 'error': '$e'}),
      );
      if (!mounted) {
        return;
      }
      _updateReaderState(() {
        _loadingImages = false;
        _loadImagesError = l10n(context).readerChapterLoadFailed('$e');
      });
    }
  }

  void _onScrollPrefetch() {
    if (!_scrollController.hasClients || _images.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return;
    }

    final currentPixels = position.pixels;
    final previousPixels = _diagnosticsState.lastObservedListPixels;
    int normalizedIndex = _currentPageIndex;

    for (var i = 0; i < _images.length; i++) {
      if (i >= _itemKeys.length) {
        break;
      }
      final ctx = _itemKeys[i].currentContext;
      if (ctx != null) {
        final renderObject = ctx.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          final positionY = renderObject.localToGlobal(Offset.zero).dy;
          final itemHeight = renderObject.size.height;
          if (positionY + itemHeight > 50) {
            normalizedIndex = i;
            break;
          }
        }
      }
    }

    if (_currentPageIndex != normalizedIndex) {
      _currentPageIndex = normalizedIndex;
      _logVisiblePageChange(index: normalizedIndex, trigger: 'scroll');
    }
    _setDisplayedPageIndex(normalizedIndex);

    if (previousPixels != null) {
      final hasRecentExpectedTopJump =
          _diagnosticsState.activeProgrammaticListTargetIndex == 0 ||
          (_diagnosticsState.lastCompletedProgrammaticListTargetIndex == 0 &&
              _diagnosticsState.lastCompletedProgrammaticListScrollAt != null &&
              DateTime.now().difference(
                    _diagnosticsState.lastCompletedProgrammaticListScrollAt!,
                  ) <
                  const Duration(seconds: 1));
      final jumpedToTop =
          currentPixels <= _ReaderPageState._topEdgeOffsetEpsilon &&
          previousPixels >= _ReaderPageState._unexpectedTopOffsetThreshold &&
          !hasRecentExpectedTopJump;
      final deltaPixels = currentPixels - previousPixels;
      final largeJump = deltaPixels.abs() >= math.max(viewport * 1.35, 1200.0);
      if ((jumpedToTop || largeJump) && _shouldLogUnexpectedListJump()) {
        _logListPositionSnapshot(
          jumpedToTop
              ? 'Reader suspicious return to top detected'
              : 'Reader suspicious list offset jump detected',
          trigger: jumpedToTop
              ? 'scroll_return_to_top'
              : 'scroll_large_offset_jump',
          previousPixels: previousPixels,
          normalizedIndex: normalizedIndex,
          level: 'warning',
          extra: {
            'deltaPixels': _normalizeLogDouble(deltaPixels),
            'jumpedToTop': jumpedToTop,
            'largeJump': largeJump,
          },
        );
      }
    }

    _diagnosticsState.lastObservedListPixels = currentPixels;
    if (!_noImageModeEnabled) {
      _prefetchAround(normalizedIndex);
      _requestPrefetchAhead(normalizedIndex);
    }
  }

  void _requestPrefetchAhead(int currentIndex) {
    if (_images.isEmpty) {
      return;
    }
    _queuedPrefetchAheadIndex = currentIndex;
    if (_prefetchAheadRunning) {
      return;
    }
    unawaited(_drainPrefetchAheadQueue());
  }

  Future<void> _drainPrefetchAheadQueue() async {
    if (_prefetchAheadRunning) {
      return;
    }
    _prefetchAheadRunning = true;
    try {
      while (true) {
        final currentIndex = _queuedPrefetchAheadIndex;
        _queuedPrefetchAheadIndex = null;
        if (currentIndex == null || _images.isEmpty) {
          break;
        }
        await _prefetchAheadFrom(currentIndex);
      }
    } finally {
      _prefetchAheadRunning = false;
      if (_queuedPrefetchAheadIndex != null) {
        unawaited(_drainPrefetchAheadQueue());
      }
    }
  }

  void _prefetchAround(int currentIndex) {
    var start = currentIndex - _ReaderPageState._prefetchAroundCount;
    if (start < 0) {
      start = 0;
    }
    final max = _images.length;
    var end = currentIndex + _ReaderPageState._prefetchAroundCount;
    if (end > max) {
      end = max;
    }

    for (var i = start; i < end; i++) {
      final url = _images[i];
      if (_providerCache.containsKey(url) ||
          _providerFutureCache.containsKey(url)) {
        continue;
      }
      unawaited(_getOrCreateImageProviderFuture(url));
    }

    _trimProviderCachesAround(currentIndex);
  }

  Future<void> _prefetchAheadFrom(int currentIndex) async {
    if (_images.isEmpty) {
      return;
    }
    var start = currentIndex + 1;
    if (start < 0) {
      start = 0;
    }
    if (start >= _images.length) {
      return;
    }
    final endExclusive =
        (start + _ReaderPageState._prefetchAheadMemoryCount) < _images.length
        ? (start + _ReaderPageState._prefetchAheadMemoryCount)
        : _images.length;
    final futures = <Future<void>>[];

    for (var i = start; i < endExclusive; i++) {
      if (_queuedPrefetchAheadIndex != null &&
          _queuedPrefetchAheadIndex != currentIndex) {
        break;
      }

      final url = _images[i];
      if (url.trim().isEmpty) {
        continue;
      }

      if (HazukiSourceService.instance.isLocalImagePath(url)) {
        unawaited(_getOrCreateImageProviderFuture(url));
        continue;
      }

      futures.add(
        HazukiSourceService.instance
            .downloadImageBytes(
              url,
              comicId: widget.comicId,
              epId: widget.epId,
              keepInMemory: true,
              useDiskCache: true,
            )
            .then((_) {})
            .catchError((_) {}),
      );
      unawaited(_getOrCreateImageProviderFuture(url));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _acquireUnscramblePermit() async {
    if (_activeUnscrambleTasks < _ReaderPageState._maxUnscrambleConcurrency) {
      _activeUnscrambleTasks++;
      return;
    }
    final waiter = Completer<void>();
    _decodeWaiters.add(waiter);
    await waiter.future;
    _activeUnscrambleTasks++;
  }

  void _releaseUnscramblePermit() {
    if (_activeUnscrambleTasks > 0) {
      _activeUnscrambleTasks--;
    }
    while (_decodeWaiters.isNotEmpty) {
      final waiter = _decodeWaiters.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
        break;
      }
    }
  }

  Future<ImageProvider> _getOrCreateImageProviderFuture(String url) {
    final existing = _providerFutureCache[url];
    if (existing != null) {
      return existing;
    }

    final created = _buildImageProvider(url)
        .then((provider) async {
          _providerCache[url] = provider;
          if (mounted) {
            try {
              await precacheImage(provider, context);
            } catch (_) {}
          }
          return provider;
        })
        .catchError((Object error, StackTrace stackTrace) {
          _providerFutureCache.remove(url);
          throw error;
        });

    _providerFutureCache[url] = created;
    return created;
  }

  Future<void> _rememberAspectRatioFromBytes(
    String url,
    Uint8List bytes,
  ) async {
    if (_imageAspectRatioCache.containsKey(url)) {
      return;
    }
    try {
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (image.height <= 0) {
        return;
      }
      final aspectRatio = image.width / image.height;
      _imageAspectRatioCache[url] = aspectRatio;
      final index = _imageIndexMap[url];
      if (index != null &&
          _readerMode == ReaderMode.topToBottom &&
          index < _currentPageIndex &&
          index >= _currentPageIndex - 4) {
        _logListPositionSnapshot(
          'Reader upstream page aspect ratio resolved',
          trigger: 'image_aspect_ratio_resolved',
          normalizedIndex: _currentPageIndex,
          extra: {
            'resolvedPageIndex': index,
            'resolvedPage': index + 1,
            'aspectRatio': _normalizeLogDouble(aspectRatio),
            'isBeforeCurrentPage': true,
          },
        );
      }
    } catch (_) {}
  }

  void _rememberAspectRatio(String url, double? aspectRatio) {
    if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
      return;
    }
    _imageAspectRatioCache[url] = aspectRatio;
  }

  double _resolvePlaceholderAspectRatio(int index) {
    if (index >= 0 && index < _images.length) {
      final exact = _imageAspectRatioCache[_images[index]];
      if (exact != null && exact.isFinite && exact > 0) {
        return exact;
      }
    }

    for (var distance = 1; distance <= 3; distance++) {
      final before = index - distance;
      if (before >= 0) {
        final ratio = _imageAspectRatioCache[_images[before]];
        if (ratio != null && ratio.isFinite && ratio > 0) {
          return ratio;
        }
      }

      final after = index + distance;
      if (after < _images.length) {
        final ratio = _imageAspectRatioCache[_images[after]];
        if (ratio != null && ratio.isFinite && ratio > 0) {
          return ratio;
        }
      }
    }

    if (_imageAspectRatioCache.isNotEmpty) {
      var total = 0.0;
      var count = 0;
      for (final ratio in _imageAspectRatioCache.values) {
        if (!ratio.isFinite || ratio <= 0) {
          continue;
        }
        total += ratio;
        count++;
        if (count >= 8) {
          break;
        }
      }
      if (count > 0) {
        final average = total / count;
        return average.clamp(0.45, 1.2).toDouble();
      }
    }

    return _ReaderPageState._defaultPlaceholderAspectRatio;
  }

  double _readerListCacheExtent(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).height;
    if (!viewport.isFinite || viewport <= 0) {
      return _ReaderPageState._readerListCacheExtentMin;
    }
    return (viewport *
            _ReaderPageState._readerListCacheExtentViewportMultiplier)
        .clamp(
          _ReaderPageState._readerListCacheExtentMin,
          _ReaderPageState._readerListCacheExtentMax,
        )
        .toDouble();
  }

  Future<ImageProvider> _buildImageProvider(String url) async {
    final sourceService = HazukiSourceService.instance;
    if (_noImageModeEnabled) {
      throw StateError('no-image mode enabled');
    }

    if (sourceService.isLocalImagePath(url)) {
      final file = File(sourceService.normalizeLocalImagePath(url));
      try {
        final bytes = await file.readAsBytes();
        await _rememberAspectRatioFromBytes(url, bytes);
      } catch (_) {}
      return FileImage(file);
    }

    await _acquireUnscramblePermit();
    try {
      final prepared = await sourceService.prepareChapterImageData(
        url,
        comicId: widget.comicId,
        epId: widget.epId,
        useDiskCache: true,
      );
      _rememberAspectRatio(url, prepared.aspectRatio);
      if (!_imageAspectRatioCache.containsKey(url)) {
        await _rememberAspectRatioFromBytes(url, prepared.bytes);
      }
      return MemoryImage(prepared.bytes);
    } finally {
      _releaseUnscramblePermit();
    }
  }
}
