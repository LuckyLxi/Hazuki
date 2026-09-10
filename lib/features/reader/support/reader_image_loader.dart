import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show instantiateImageCodec;
import 'package:flutter/painting.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import '../state/reader_image_pipeline_state.dart';

/// Loads providers and resolves dimensions without depending on reader layout
/// or widget lifecycle. The pipeline owns publication and display updates.
class ReaderImageLoader {
  ReaderImageLoader({
    required ReaderImagePipelineState state,
    required SourceReaderGateway source,
    required String comicId,
    required String epId,
    required String sourceKey,
    required bool Function() noImageModeEnabled,
    required void Function(Iterable<String>) evictImageBytesFromMemory,
    required Future<void> Function(Iterable<String>) evictImageCacheEntries,
    Future<ImageProvider> Function(String url, {bool useDiskCache})?
    imageProviderBuilder,
    void Function(String url, double aspectRatio)? onDecodedAspectRatio,
  }) : _pipelineState = state,
       _sourceService = source,
       _comicId = comicId,
       _epId = epId,
       _sourceKey = sourceKey,
       _noImageModeEnabled = noImageModeEnabled,
       _evictImageBytesFromMemory = evictImageBytesFromMemory,
       _evictImageCacheEntries = evictImageCacheEntries,
       _imageProviderBuilder = imageProviderBuilder,
       _onDecodedAspectRatio = onDecodedAspectRatio;

  static const _maxUnscrambleConcurrency = 5;
  final ReaderImagePipelineState _pipelineState;
  final SourceReaderGateway _sourceService;
  final String _comicId;
  final String _epId;
  final String _sourceKey;
  final bool Function() _noImageModeEnabled;
  final void Function(Iterable<String>) _evictImageBytesFromMemory;
  final Future<void> Function(Iterable<String>) _evictImageCacheEntries;
  final Future<ImageProvider> Function(String url, {bool useDiskCache})?
  _imageProviderBuilder;
  final void Function(String url, double aspectRatio)? _onDecodedAspectRatio;
  Map<String, double> get imageAspectRatioCache =>
      _pipelineState.imageAspectRatioCache;
  Map<String, ImageProvider> get providerCache => _pipelineState.providerCache;
  Map<String, Future<ImageProvider>> get providerFutureCache =>
      _pipelineState.providerFutureCache;

  Future<ImageProvider> load(
    String url, {
    required bool useDiskCache,
    bool priority = false,
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

    if (!await _acquireUnscramblePermit(priority: priority)) {
      throw StateError('reader_disposed');
    }
    try {
      // A cache retry keeps its existing permit. Recursively acquiring a
      // second permit would deadlock when all five active images are corrupt.
      while (true) {
        final prepared = await _sourceService.prepareChapterImageData(
          url,
          comicId: _comicId,
          epId: _epId,
          useDiskCache: useDiskCache,
          priority: priority,
          sourceKey: _sourceKey,
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
          if (_noImageModeEnabled()) {
            throw StateError('no-image mode enabled');
          }
          if (_pipelineState.disposed) {
            throw StateError('reader_disposed');
          }
          useDiskCache = false;
          priority = true;
          continue;
        }
        return MemoryImage(prepared.bytes);
      }
    } finally {
      _releaseUnscramblePermit();
    }
  }

  Future<bool> _acquireUnscramblePermit({required bool priority}) async {
    if (_pipelineState.activeUnscrambleTasks < _maxUnscrambleConcurrency) {
      _pipelineState.activeUnscrambleTasks++;
      return true;
    }
    final waiter = ReaderImagePipelinePermitWaiter();
    if (priority) {
      _pipelineState.decodeWaiters.insert(0, waiter);
    } else {
      _pipelineState.decodeWaiters.add(waiter);
    }
    await waiter.completer.future;
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
      if (!waiter.completer.isCompleted) {
        waiter.completer.complete();
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
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          if (image.height <= 0) {
            return false;
          }
          final aspectRatio = image.width / image.height;
          imageAspectRatioCache[url] = aspectRatio;
          _onDecodedAspectRatio?.call(url, aspectRatio);
          return true;
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
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
}
