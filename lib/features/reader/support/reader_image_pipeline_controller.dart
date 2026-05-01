import 'dart:async';
import 'dart:io';
import 'dart:ui' show instantiateImageCodec;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_mode.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';

class ReaderImagePipelineController {
  ReaderImagePipelineController({
    required ReaderRuntimeState runtimeState,
    required ReaderImagePipelineState pipelineState,
    required ReaderDiagnosticsState diagnosticsState,
    required TransformationController zoomController,
    required ReaderContextGetter context,
    required ReaderIsMounted isMounted,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required ReaderVisiblePageLogger logVisiblePageChange,
    required bool Function() noImageModeEnabled,
    required String comicId,
    required String epId,
    required String Function(Object error) loadImagesErrorBuilder,
    Future<ImageProvider> Function(String url, {bool useDiskCache})?
    imageProviderBuilder,
    void Function(Iterable<String>)? evictImageBytesFromMemory,
    Future<void> Function(Iterable<String>)? evictImageCacheEntries,
    Future<void> Function(ImageProvider provider)? precacheImageCallback,
    HazukiSourceService? sourceService,
  }) : _runtimeState = runtimeState,
       _pipelineState = pipelineState,
       _diagnosticsState = diagnosticsState,
       _zoomController = zoomController,
       _context = context,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _logVisiblePageChange = logVisiblePageChange,
       _noImageModeEnabled = noImageModeEnabled,
       _comicId = comicId,
       _epId = epId,
       _loadImagesErrorBuilder = loadImagesErrorBuilder,
       _imageProviderBuilder = imageProviderBuilder,
       _sourceService = sourceService ?? HazukiSourceService.instance,
       _evictImageBytesFromMemory =
           evictImageBytesFromMemory ??
           (sourceService ?? HazukiSourceService.instance)
               .evictImageBytesFromMemory,
       _evictImageCacheEntries =
           evictImageCacheEntries ??
           (sourceService ?? HazukiSourceService.instance)
               .evictImageCacheEntries,
       _precacheImageCallback = precacheImageCallback;

  static const int _maxUnscrambleConcurrency = 5;
  static const int _prefetchAroundCount = 10;
  static const int _prefetchAheadMemoryCount = 6;
  static const int _providerKeepBehindCount = 12;
  static const int _providerKeepAheadCount = 24;
  static const double defaultPlaceholderAspectRatio = 0.72;
  static const double readerListCacheExtentViewportMultiplier = 3.0;
  static const double readerListCacheExtentMin = 1600;
  static const double readerListCacheExtentMax = 5200;

  final ReaderRuntimeState _runtimeState;
  final ReaderImagePipelineState _pipelineState;
  final ReaderDiagnosticsState _diagnosticsState;
  final TransformationController _zoomController;
  final ReaderContextGetter _context;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final ReaderVisiblePageLogger _logVisiblePageChange;
  final bool Function() _noImageModeEnabled;
  final String _comicId;
  final String _epId;
  final String Function(Object error) _loadImagesErrorBuilder;
  final Future<ImageProvider> Function(String url, {bool useDiskCache})?
  _imageProviderBuilder;
  final HazukiSourceService _sourceService;
  final void Function(Iterable<String>) _evictImageBytesFromMemory;
  final Future<void> Function(Iterable<String>) _evictImageCacheEntries;
  final Future<void> Function(ImageProvider provider)? _precacheImageCallback;

  Map<String, ImageProvider> get providerCache => _pipelineState.providerCache;
  Map<String, Future<ImageProvider>> get providerFutureCache =>
      _pipelineState.providerFutureCache;
  Map<String, double> get imageAspectRatioCache =>
      _pipelineState.imageAspectRatioCache;
  Set<String> get retryingImageUrls => _pipelineState.retryingImageUrls;

  ImageProvider? cachedProviderFor(String url) => providerCache[url];

  bool isRetrying(String url) => retryingImageUrls.contains(url);

  void applyInitialImages(List<String> images, {required String trigger}) {
    final sanitized = images.where((entry) => entry.trim().isNotEmpty).toList();
    _zoomController.value = Matrix4.identity();
    _pipelineState.resetForImages(sanitized);
    _runtimeState.applyImages(sanitized);
    _logEvent(
      'Reader initial images ready',
      source: 'reader_data',
      content: _logPayload({
        'trigger': trigger,
        'imageCount': _runtimeState.images.length,
      }),
    );
    _logVisiblePageChange(index: 0, trigger: trigger);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prefetchAround(0);
      requestPrefetchAhead(0);
    });
  }

  Future<void> loadChapterImages({String trigger = 'manual'}) async {
    _logEvent(
      'Reader chapter images loading started',
      source: 'reader_data',
      content: _logPayload({'trigger': trigger}),
    );
    try {
      final images = await _sourceService.loadChapterImages(
        comicId: _comicId,
        epId: _epId,
      );
      if (!_isMounted()) {
        return;
      }
      _updateState(() {
        _zoomController.value = Matrix4.identity();
        final sanitizedImages = images
            .where((entry) => entry.trim().isNotEmpty)
            .toList();
        _pipelineState.resetForImages(sanitizedImages);
        _runtimeState.applyImages(sanitizedImages);
      });
      _diagnosticsState.lastLoggedVisiblePageIndex = -1;
      _logEvent(
        'Reader chapter images loading finished',
        source: 'reader_data',
        content: _logPayload({
          'trigger': trigger,
          'imageCount': _runtimeState.images.length,
        }),
      );
      _logVisiblePageChange(index: 0, trigger: 'chapter_images_loaded');
      if (!_noImageModeEnabled()) {
        prefetchAround(0);
        requestPrefetchAhead(0);
      }
    } catch (error) {
      _logEvent(
        'Reader chapter images loading failed',
        level: 'error',
        source: 'reader_data',
        content: _logPayload({'trigger': trigger, 'error': '$error'}),
      );
      if (!_isMounted()) {
        return;
      }
      _updateState(() {
        _runtimeState.markLoadImagesFailed(_loadImagesErrorBuilder(error));
      });
    }
  }

  void handleNoImageModeChanged() {
    _pipelineState.clearProviderCaches();
    _logEvent(
      'Reader no-image mode changed',
      source: 'reader_data',
      content: _logPayload({
        'enabled': _noImageModeEnabled(),
        'providerCachesCleared': true,
      }),
    );
    if (_isMounted()) {
      _updateState(() {});
    }
  }

  void prefetchAround(int currentSpreadIndex) {
    final anchorImageIndex = _runtimeState.spreadStartIndex(currentSpreadIndex);
    var start = anchorImageIndex - _prefetchAroundCount;
    if (start < 0) {
      start = 0;
    }
    final max = _runtimeState.images.length;
    var end = anchorImageIndex + _prefetchAroundCount;
    if (end > max) {
      end = max;
    }

    for (var i = start; i < end; i++) {
      final url = _runtimeState.images[i];
      if (providerCache.containsKey(url) ||
          providerFutureCache.containsKey(url)) {
        continue;
      }
      _prefetchImageProvider(url);
    }

    _trimProviderCachesAround(anchorImageIndex);
  }

  void requestPrefetchAhead(int currentIndex) {
    if (_runtimeState.images.isEmpty) {
      return;
    }
    _pipelineState.queuedPrefetchAheadIndex = currentIndex;
    if (_pipelineState.prefetchAheadRunning) {
      return;
    }
    unawaited(_drainPrefetchAheadQueue());
  }

  Future<ImageProvider> getImageProvider(String url) {
    return _getImageProvider(url, useDiskCache: true);
  }

  void _prefetchImageProvider(String url) {
    unawaited(() async {
      try {
        await getImageProvider(url);
      } catch (_) {
        // Prefetch is best-effort; visible image builders and retries surface
        // load failures through their own awaited futures.
      }
    }());
  }

  Future<ImageProvider> _getImageProvider(
    String url, {
    required bool useDiskCache,
  }) {
    final existing = providerFutureCache[url];
    if (existing != null) {
      return existing;
    }

    final created = _buildImageProvider(url, useDiskCache: useDiskCache)
        .then((provider) async {
          if (_pipelineState.disposed) return provider;
          providerCache[url] = provider;
          if (_isMounted()) {
            try {
              final precacheImageCallback = _precacheImageCallback;
              if (precacheImageCallback != null) {
                await precacheImageCallback(provider);
              } else {
                await precacheImage(provider, _context());
              }
            } catch (_) {}
          }
          return provider;
        })
        .catchError((Object error, StackTrace stackTrace) {
          providerFutureCache.remove(url);
          throw error;
        });

    providerFutureCache[url] = created;
    return created;
  }

  Future<void> retryImage(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty || retryingImageUrls.contains(normalized)) {
      return;
    }

    _logEvent(
      'Reader image retry started',
      source: 'reader_data',
      content: _logPayload({'imageUrl': normalized, 'useDiskCache': false}),
    );
    _updateState(() {
      retryingImageUrls.add(normalized);
      providerCache.remove(normalized);
      providerFutureCache.remove(normalized);
    });
    _evictImageBytesFromMemory([normalized]);
    await _evictImageCacheEntries([normalized]);

    try {
      await _getImageProvider(normalized, useDiskCache: false);
      _logEvent(
        'Reader image retry finished',
        source: 'reader_data',
        content: _logPayload({
          'imageUrl': normalized,
          'useDiskCache': false,
          'success': true,
        }),
      );
    } catch (error) {
      _logEvent(
        'Reader image retry failed',
        level: 'error',
        source: 'reader_data',
        content: _logPayload({
          'imageUrl': normalized,
          'useDiskCache': false,
          'error': '$error',
        }),
      );
      // Keep the error state visible so the user can retry again.
    } finally {
      if (_isMounted()) {
        _updateState(() {
          retryingImageUrls.remove(normalized);
        });
      }
    }
  }

  double resolvePlaceholderAspectRatio(int index) {
    if (index >= 0 && index < _runtimeState.images.length) {
      final exact = imageAspectRatioCache[_runtimeState.images[index]];
      if (exact != null && exact.isFinite && exact > 0) {
        return exact;
      }
    }

    for (var distance = 1; distance <= 3; distance++) {
      final before = index - distance;
      if (before >= 0) {
        final ratio = imageAspectRatioCache[_runtimeState.images[before]];
        if (ratio != null && ratio.isFinite && ratio > 0) {
          return ratio;
        }
      }

      final after = index + distance;
      if (after < _runtimeState.images.length) {
        final ratio = imageAspectRatioCache[_runtimeState.images[after]];
        if (ratio != null && ratio.isFinite && ratio > 0) {
          return ratio;
        }
      }
    }

    if (imageAspectRatioCache.isNotEmpty) {
      var total = 0.0;
      var count = 0;
      for (final ratio in imageAspectRatioCache.values) {
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

    return defaultPlaceholderAspectRatio;
  }

  double readerListCacheExtent(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).height;
    if (!viewport.isFinite || viewport <= 0) {
      return readerListCacheExtentMin;
    }
    return (viewport * readerListCacheExtentViewportMultiplier)
        .clamp(readerListCacheExtentMin, readerListCacheExtentMax)
        .toDouble();
  }

  void dispose() {
    _pipelineState.dispose();
  }

  void _trimProviderCachesAround(int centerIndex) {
    final keepStart = centerIndex - _providerKeepBehindCount;
    final keepEnd = centerIndex + _providerKeepAheadCount;

    final staleProviderKeys = <String>[];
    providerCache.forEach((key, _) {
      final index = _pipelineState.imageIndexMap[key];
      if (index == null || index < keepStart || index > keepEnd) {
        staleProviderKeys.add(key);
      }
    });
    for (final key in staleProviderKeys) {
      providerCache.remove(key);
    }

    final staleFutureKeys = <String>[];
    providerFutureCache.forEach((key, _) {
      final index = _pipelineState.imageIndexMap[key];
      if (index == null || index < keepStart || index > keepEnd) {
        staleFutureKeys.add(key);
      }
    });
    for (final key in staleFutureKeys) {
      providerFutureCache.remove(key);
    }

    final staleByteUrls = <String>[];
    for (var i = 0; i < _runtimeState.images.length; i++) {
      if (i < keepStart || i > keepEnd) {
        staleByteUrls.add(_runtimeState.images[i]);
      }
    }
    if (staleByteUrls.isNotEmpty) {
      _evictImageBytesFromMemory(staleByteUrls);
    }
  }

  Future<void> _drainPrefetchAheadQueue() async {
    if (_pipelineState.prefetchAheadRunning) {
      return;
    }
    _pipelineState.prefetchAheadRunning = true;
    try {
      while (true) {
        final currentIndex = _pipelineState.queuedPrefetchAheadIndex;
        _pipelineState.queuedPrefetchAheadIndex = null;
        if (currentIndex == null || _runtimeState.images.isEmpty) {
          break;
        }
        await _prefetchAheadFrom(currentIndex);
      }
    } finally {
      _pipelineState.prefetchAheadRunning = false;
      if (_pipelineState.queuedPrefetchAheadIndex != null) {
        unawaited(_drainPrefetchAheadQueue());
      }
    }
  }

  Future<void> _prefetchAheadFrom(int currentSpreadIndex) async {
    if (_runtimeState.images.isEmpty) {
      return;
    }
    var start =
        _runtimeState.spreadStartIndex(currentSpreadIndex) +
        _runtimeState.readerSpreadSize;
    if (start < 0) {
      start = 0;
    }
    if (start >= _runtimeState.images.length) {
      return;
    }
    final endExclusive =
        (start + _prefetchAheadMemoryCount) < _runtimeState.images.length
        ? (start + _prefetchAheadMemoryCount)
        : _runtimeState.images.length;
    final futures = <Future<void>>[];

    for (var i = start; i < endExclusive; i++) {
      if (_pipelineState.queuedPrefetchAheadIndex != null &&
          _pipelineState.queuedPrefetchAheadIndex != currentSpreadIndex) {
        break;
      }

      final url = _runtimeState.images[i];
      if (url.trim().isEmpty) {
        continue;
      }

      if (_sourceService.isLocalImagePath(url)) {
        _prefetchImageProvider(url);
        continue;
      }

      futures.add(
        _sourceService
            .downloadImageBytes(
              url,
              comicId: _comicId,
              epId: _epId,
              keepInMemory: true,
              useDiskCache: true,
            )
            .then((_) {})
            .catchError((_) {}),
      );
      _prefetchImageProvider(url);
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<bool> _acquireUnscramblePermit() async {
    if (_pipelineState.activeUnscrambleTasks < _maxUnscrambleConcurrency) {
      _pipelineState.activeUnscrambleTasks++;
      return true;
    }
    final waiter = Completer<void>();
    _pipelineState.decodeWaiters.add(waiter);
    await waiter.future;
    if (_pipelineState.disposed) return false;
    _pipelineState.activeUnscrambleTasks++;
    return true;
  }

  void _releaseUnscramblePermit() {
    if (_pipelineState.activeUnscrambleTasks > 0) {
      _pipelineState.activeUnscrambleTasks--;
    }
    while (_pipelineState.decodeWaiters.isNotEmpty) {
      final waiter = _pipelineState.decodeWaiters.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
        break;
      }
    }
  }

  Future<bool> _rememberAspectRatioFromBytes(
    String url,
    Uint8List bytes,
  ) async {
    if (imageAspectRatioCache.containsKey(url)) {
      return true;
    }
    try {
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        if (image.height <= 0) {
          return false;
        }
        final aspectRatio = image.width / image.height;
        imageAspectRatioCache[url] = aspectRatio;
        final index = _pipelineState.imageIndexMap[url];
        if (index != null &&
            _runtimeState.readerMode == ReaderMode.topToBottom &&
            index <
                _runtimeState.spreadStartIndex(
                  _runtimeState.currentPageIndex,
                ) &&
            index >=
                _runtimeState.spreadStartIndex(_runtimeState.currentPageIndex) -
                    4) {
          _logEvent(
            'Reader upstream page aspect ratio resolved',
            source: 'reader_position',
            content: _logPayload({
              'trigger': 'image_aspect_ratio_resolved',
              'resolvedPageIndex': index,
              'resolvedPage': index + 1,
              'aspectRatio': normalizeReaderLogDouble(aspectRatio),
              'isBeforeCurrentPage': true,
            }),
          );
        }
        return true;
      } finally {
        image.dispose();
      }
    } catch (_) {
      return false;
    }
  }

  void _rememberAspectRatio(String url, double? aspectRatio) {
    if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
      return;
    }
    imageAspectRatioCache[url] = aspectRatio;
  }

  Future<ImageProvider> _buildImageProvider(
    String url, {
    required bool useDiskCache,
  }) async {
    final overrideBuilder = _imageProviderBuilder;
    if (overrideBuilder != null) {
      return overrideBuilder(url, useDiskCache: useDiskCache);
    }
    if (_noImageModeEnabled()) {
      throw StateError('no-image mode enabled');
    }

    if (_sourceService.isLocalImagePath(url)) {
      final file = File(_sourceService.normalizeLocalImagePath(url));
      try {
        final bytes = await file.readAsBytes();
        await _rememberAspectRatioFromBytes(url, bytes);
      } catch (_) {}
      return FileImage(file);
    }

    if (!await _acquireUnscramblePermit()) {
      throw StateError('reader_disposed');
    }
    try {
      final prepared = await _sourceService.prepareChapterImageData(
        url,
        comicId: _comicId,
        epId: _epId,
        useDiskCache: useDiskCache,
      );
      _rememberAspectRatio(url, prepared.aspectRatio);
      final decoded = imageAspectRatioCache.containsKey(url)
          ? true
          : await _rememberAspectRatioFromBytes(url, prepared.bytes);
      if (!decoded) {
        if (!useDiskCache) {
          throw StateError('reader_image_decode_failed');
        }
        _evictImageBytesFromMemory([url]);
        await _evictImageCacheEntries([url]);
        providerCache.remove(url);
        providerFutureCache.remove(url);
        return _buildImageProvider(url, useDiskCache: false);
      }
      return MemoryImage(prepared.bytes);
    } finally {
      _releaseUnscramblePermit();
    }
  }
}
