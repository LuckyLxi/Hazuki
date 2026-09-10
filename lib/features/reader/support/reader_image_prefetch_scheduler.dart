import 'dart:async';
import 'package:flutter/painting.dart';
import '../state/reader_image_pipeline_state.dart';

/// Only the image range needed for a prefetch decision.
class ReaderImagePrefetchWindow {
  const ReaderImagePrefetchWindow({
    required this.images,
    required this.anchorImageIndex,
    required this.visibleImageIndices,
    required this.spreadSize,
  });
  final List<String> images;
  final int anchorImageIndex;
  final Iterable<int> visibleImageIndices;
  final int spreadSize;
}

class ReaderImagePrefetchScheduler {
  ReaderImagePrefetchScheduler({
    required ReaderImagePipelineState state,
    required ReaderImagePrefetchWindow Function(int index) windowFor,
    required Future<ImageProvider> Function(String url, {bool priority})
    getImageProvider,
    required bool Function(String url) isLocalImagePath,
    required Future<void> Function(String url) downloadImageBytes,
    required void Function(Iterable<String>) evictImageBytesFromMemory,
  }) : _pipelineState = state,
       _windowFor = windowFor,
       _getImageProvider = getImageProvider,
       _isLocalImagePath = isLocalImagePath,
       _downloadImageBytes = downloadImageBytes,
       _evictImageBytesFromMemory = evictImageBytesFromMemory;

  static const int _prefetchAroundCount = 10;
  static const int _prefetchAheadMemoryCount = 6;
  static const int _providerKeepBehindCount = 12;
  static const int _providerKeepAheadCount = 24;
  final ReaderImagePipelineState _pipelineState;
  final ReaderImagePrefetchWindow Function(int index) _windowFor;
  final Future<ImageProvider> Function(String url, {bool priority})
  _getImageProvider;
  final bool Function(String url) _isLocalImagePath;
  final Future<void> Function(String url) _downloadImageBytes;
  final void Function(Iterable<String>) _evictImageBytesFromMemory;
  Map<String, ImageProvider> get providerCache => _pipelineState.providerCache;
  Map<String, Future<ImageProvider>> get providerFutureCache =>
      _pipelineState.providerFutureCache;

  void prefetchAround(int currentSpreadIndex) {
    final window = _windowFor(currentSpreadIndex);
    final anchorImageIndex = window.anchorImageIndex;
    var start = anchorImageIndex - _prefetchAroundCount;
    if (start < 0) {
      start = 0;
    }
    final max = window.images.length;
    var end = anchorImageIndex + _prefetchAroundCount;
    if (end > max) {
      end = max;
    }

    final visibleImageIndices = window.visibleImageIndices
        .where((index) => index >= start && index < end)
        .toSet();

    for (final index in visibleImageIndices) {
      final url = window.images[index];
      if (providerCache.containsKey(url) ||
          (providerFutureCache.containsKey(url) &&
              _pipelineState.priorityProviderRequests.contains(url))) {
        continue;
      }
      _prefetchImageProvider(url, priority: true);
    }

    for (var i = start; i < end; i++) {
      if (visibleImageIndices.contains(i)) {
        continue;
      }
      final url = window.images[i];
      if (providerCache.containsKey(url) ||
          providerFutureCache.containsKey(url)) {
        continue;
      }
      _prefetchImageProvider(url);
    }

    _trimProviderCachesAround(anchorImageIndex, window.images);
  }

  void requestPrefetchAhead(int currentIndex) {
    if (_windowFor(currentIndex).images.isEmpty) {
      return;
    }
    _pipelineState.queuedPrefetchAheadIndex = currentIndex;
    if (_pipelineState.prefetchAheadRunning) {
      return;
    }
    unawaited(_drainPrefetchAheadQueue());
  }

  void _prefetchImageProvider(String url, {bool priority = false}) {
    unawaited(() async {
      try {
        await _getImageProvider(url, priority: priority);
      } catch (_) {
        // Prefetch is best-effort; visible image builders and retries surface
        // load failures through their own awaited futures.
      }
    }());
  }

  void _trimProviderCachesAround(int centerIndex, List<String> images) {
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
      _pipelineState.priorityProviderRequests.remove(key);
    }

    final staleByteUrls = <String>[];
    for (var i = 0; i < images.length; i++) {
      if (i < keepStart || i > keepEnd) {
        staleByteUrls.add(images[i]);
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
        if (currentIndex == null || _windowFor(currentIndex).images.isEmpty) {
          break;
        }
        await _prefetchAheadFrom(currentIndex);
        if (_pipelineState.disposed) break;
      }
    } finally {
      _pipelineState.prefetchAheadRunning = false;
      if (!_pipelineState.disposed &&
          _pipelineState.queuedPrefetchAheadIndex != null) {
        unawaited(_drainPrefetchAheadQueue());
      }
    }
  }

  Future<void> _prefetchAheadFrom(int currentSpreadIndex) async {
    final window = _windowFor(currentSpreadIndex);
    if (_pipelineState.disposed || window.images.isEmpty) {
      return;
    }
    var start = window.anchorImageIndex + window.spreadSize;
    if (start < 0) {
      start = 0;
    }
    if (start >= window.images.length) {
      return;
    }
    final endExclusive =
        (start + _prefetchAheadMemoryCount) < window.images.length
        ? (start + _prefetchAheadMemoryCount)
        : window.images.length;
    final futures = <Future<void>>[];

    for (var i = start; i < endExclusive; i++) {
      if (_pipelineState.queuedPrefetchAheadIndex != null &&
          _pipelineState.queuedPrefetchAheadIndex != currentSpreadIndex) {
        break;
      }

      final url = window.images[i];
      if (url.trim().isEmpty) {
        continue;
      }

      if (_isLocalImagePath(url)) {
        _prefetchImageProvider(url);
        continue;
      }

      futures.add(_downloadImageBytes(url).catchError((_) {}));
      _prefetchImageProvider(url);
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }
}
