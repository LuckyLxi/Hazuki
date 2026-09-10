import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';

import 'reader_image_loader.dart';
import 'reader_image_prefetch_scheduler.dart';

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
    String sourceKey = '',
    required String Function(Object error) loadImagesErrorBuilder,
    Future<ImageProvider> Function(String url, {bool useDiskCache})?
    imageProviderBuilder,
    void Function(Iterable<String>)? evictImageBytesFromMemory,
    Future<void> Function(Iterable<String>)? evictImageCacheEntries,
    Future<void> Function(ImageProvider provider)? precacheImageCallback,
    void Function({
      required int imageIndex,
      double? previousAspectRatio,
      required double resolvedAspectRatio,
    })?
    onImageAspectRatioResolved,
    required SourceReaderGateway sourceService,
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
       _sourceKey = sourceKey,
       _loadImagesErrorBuilder = loadImagesErrorBuilder,
       _sourceService = sourceService,
       _evictImageBytesFromMemory =
           evictImageBytesFromMemory ?? sourceService.evictImageBytesFromMemory,
       _evictImageCacheEntries =
           evictImageCacheEntries ?? sourceService.evictImageCacheEntries,
       _precacheImageCallback = precacheImageCallback,
       _onImageAspectRatioResolved = onImageAspectRatioResolved {
    _imageLoader = ReaderImageLoader(
      state: pipelineState,
      source: sourceService,
      comicId: comicId,
      epId: epId,
      sourceKey: sourceKey,
      noImageModeEnabled: noImageModeEnabled,
      evictImageBytesFromMemory: _evictImageBytesFromMemory,
      evictImageCacheEntries: _evictImageCacheEntries,
      imageProviderBuilder: imageProviderBuilder,
      onDecodedAspectRatio: _logDecodedAspectRatio,
    );
    _prefetchScheduler = ReaderImagePrefetchScheduler(
      state: pipelineState,
      windowFor: (index) => ReaderImagePrefetchWindow(
        images: _runtimeState.images,
        anchorImageIndex: _runtimeState.spreadStartIndex(index),
        visibleImageIndices: _runtimeState.spreadImageIndices(index),
        spreadSize: _runtimeState.readerSpreadSize,
      ),
      getImageProvider: getImageProvider,
      isLocalImagePath: sourceService.isLocalImagePath,
      downloadImageBytes: (url) async {
        await sourceService.downloadImageBytes(
          url,
          comicId: comicId,
          epId: epId,
          sourceKey: sourceKey,
          keepInMemory: true,
          useDiskCache: true,
        );
      },
      evictImageBytesFromMemory: _evictImageBytesFromMemory,
    );
  }

  late final ReaderImageLoader _imageLoader;
  late final ReaderImagePrefetchScheduler _prefetchScheduler;

  void prefetchAround(int index) => _prefetchScheduler.prefetchAround(index);
  void requestPrefetchAhead(int index) =>
      _prefetchScheduler.requestPrefetchAhead(index);

  void _logDecodedAspectRatio(String url, double aspectRatio) {
    final index = _pipelineState.imageIndexMap[url];
    if (index != null &&
        _runtimeState.readerMode == ReaderMode.topToBottom &&
        index <
            _runtimeState.spreadStartIndex(_runtimeState.currentPageIndex) &&
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
  }

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
  final String _sourceKey;
  final String Function(Object error) _loadImagesErrorBuilder;
  final SourceReaderGateway _sourceService;
  final void Function(Iterable<String>) _evictImageBytesFromMemory;
  final Future<void> Function(Iterable<String>) _evictImageCacheEntries;
  final Future<void> Function(ImageProvider provider)? _precacheImageCallback;
  final void Function({
    required int imageIndex,
    double? previousAspectRatio,
    required double resolvedAspectRatio,
  })?
  _onImageAspectRatioResolved;

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
        sourceKey: _sourceKey,
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

  Future<ImageProvider> getImageProvider(String url, {bool priority = false}) {
    return _getImageProvider(url, useDiskCache: true, priority: priority);
  }

  Future<ImageProvider> _getImageProvider(
    String url, {
    required bool useDiskCache,
    bool priority = false,
  }) {
    final existing = providerFutureCache[url];
    if (existing != null &&
        (!priority || _pipelineState.priorityProviderRequests.contains(url))) {
      return existing;
    }

    if (priority) {
      _pipelineState.priorityProviderRequests.add(url);
    }
    late final Future<ImageProvider> created;
    created = _imageLoader
        .load(url, useDiskCache: useDiskCache, priority: priority)
        .then((provider) async {
          if (_pipelineState.disposed) return provider;
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
          if (_pipelineState.disposed) return provider;
          providerCache[url] = provider;
          if (_isMounted()) {
            _updateState(() {});
          }
          _notifyImageAspectRatioResolved(url);
          return provider;
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (identical(providerFutureCache[url], created)) {
            providerFutureCache.remove(url);
            _pipelineState.priorityProviderRequests.remove(url);
          }
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
      await _getImageProvider(normalized, useDiskCache: false, priority: true);
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
      if (!_pipelineState.disposed && _isMounted()) {
        _updateState(() {
          retryingImageUrls.remove(normalized);
        });
      }
    }
  }

  double resolvePlaceholderAspectRatio(int index) {
    if (index >= 0 && index < _runtimeState.images.length) {
      final url = _runtimeState.images[index];
      final exact = imageAspectRatioCache[url];
      if (exact != null && exact.isFinite && exact > 0) {
        return exact;
      }
      final remembered = _pipelineState.listPlaceholderAspectRatioCache[url];
      if (remembered != null && remembered.isFinite && remembered > 0) {
        return remembered;
      }
    }

    late final double placeholderAspectRatio;
    for (var distance = 1; distance <= 3; distance++) {
      final before = index - distance;
      if (before >= 0) {
        final ratio = imageAspectRatioCache[_runtimeState.images[before]];
        if (ratio != null && ratio.isFinite && ratio > 0) {
          placeholderAspectRatio = ratio;
          _rememberListPlaceholderAspectRatio(index, placeholderAspectRatio);
          return placeholderAspectRatio;
        }
      }

      final after = index + distance;
      if (after < _runtimeState.images.length) {
        final ratio = imageAspectRatioCache[_runtimeState.images[after]];
        if (ratio != null && ratio.isFinite && ratio > 0) {
          placeholderAspectRatio = ratio;
          _rememberListPlaceholderAspectRatio(index, placeholderAspectRatio);
          return placeholderAspectRatio;
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
        placeholderAspectRatio = average.clamp(0.45, 1.2).toDouble();
        _rememberListPlaceholderAspectRatio(index, placeholderAspectRatio);
        return placeholderAspectRatio;
      }
    }

    placeholderAspectRatio = defaultPlaceholderAspectRatio;
    _rememberListPlaceholderAspectRatio(index, placeholderAspectRatio);
    return placeholderAspectRatio;
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

  void _notifyImageAspectRatioResolved(String url) {
    final resolvedAspectRatio = imageAspectRatioCache[url];
    if (resolvedAspectRatio == null ||
        !resolvedAspectRatio.isFinite ||
        resolvedAspectRatio <= 0) {
      return;
    }
    final index = _pipelineState.imageIndexMap[url];
    if (index == null) {
      return;
    }
    final previousAspectRatio = _pipelineState.listPlaceholderAspectRatioCache
        .remove(url);
    _onImageAspectRatioResolved?.call(
      imageIndex: index,
      previousAspectRatio: previousAspectRatio,
      resolvedAspectRatio: resolvedAspectRatio,
    );
  }

  void _rememberListPlaceholderAspectRatio(int index, double aspectRatio) {
    if (index < 0 ||
        index >= _runtimeState.images.length ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0) {
      return;
    }
    final url = _runtimeState.images[index];
    if (imageAspectRatioCache.containsKey(url)) {
      return;
    }
    _pipelineState.listPlaceholderAspectRatioCache[url] = aspectRatio;
  }
}
