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
    SourceTaskOrigin? taskOrigin,
  }) async {
    final generation = _pipelineState.generation;
    void checkActive() {
      final reason = taskOrigin?.cancellation?.reason;
      if (reason != null) throw SourceTaskCancelled(url, reason);
      taskOrigin?.readerSession?.checkActive();
      if (_pipelineState.disposed || generation != _pipelineState.generation) {
        throw SourceTaskCancelled(
          url,
          _pipelineState.disposed
              ? SourceTaskStopReason.ownerDisposed
              : SourceTaskStopReason.superseded,
        );
      }
    }

    checkActive();
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
        checkActive();
        await _rememberAspectRatioFromBytes(
          url,
          bytes,
          checkActive: checkActive,
        );
      } catch (error) {
        if (error is SourceTaskCancelled) rethrow;
      }
      return FileImage(file);
    }

    if (!await _acquireUnscramblePermit(
      priority: priority,
      checkActive: checkActive,
      generation: generation,
      taskOrigin: taskOrigin,
    )) {
      throw StateError('reader_disposed');
    }
    try {
      // A cache retry keeps its existing permit. Recursively acquiring a
      // second permit would deadlock when all five active images are corrupt.
      while (true) {
        checkActive();
        PreparedChapterImageData? prepared;
        try {
          prepared = await _sourceService.prepareChapterImageData(
            url,
            comicId: _comicId,
            epId: _epId,
            useDiskCache: useDiskCache,
            priority: priority,
            sourceKey: _sourceKey,
            taskOrigin: taskOrigin,
          );
        } on SourceImageDecodeFailure {
          // Retry a corrupt cached image using the same permit below.
        }
        checkActive();
        _rememberAspectRatio(url, prepared?.aspectRatio);
        final decoded = prepared == null
            ? false
            : imageAspectRatioCache.containsKey(url)
            ? true
            : await _rememberAspectRatioFromBytes(
                url,
                prepared.bytes,
                checkActive: checkActive,
              );
        if (!decoded) {
          if (!useDiskCache) {
            throw StateError('reader_image_decode_failed');
          }
          _evictImageBytesFromMemory([url]);
          await _evictImageCacheEntries([url]);
          checkActive();
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
      _releaseUnscramblePermit(generation);
    }
  }

  Future<bool> _acquireUnscramblePermit({
    required bool priority,
    required void Function() checkActive,
    required int generation,
    SourceTaskOrigin? taskOrigin,
  }) async {
    checkActive();
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
    try {
      await Future.any([
        waiter.completer.future,
        if (taskOrigin?.cancellation case final cancellation?)
          cancellation.whenStopped,
        if (taskOrigin?.readerSession case final session?)
          session.cancellation.whenStopped,
      ]);
      checkActive();
      return waiter.granted;
    } catch (_) {
      if (waiter.granted) _releaseUnscramblePermit(generation);
      rethrow;
    } finally {
      _pipelineState.decodeWaiters.remove(waiter);
    }
  }

  void _releaseUnscramblePermit(int generation) {
    if (generation != _pipelineState.generation) return;
    if (_pipelineState.activeUnscrambleTasks > 0) {
      _pipelineState.activeUnscrambleTasks--;
    }
    while (_pipelineState.decodeWaiters.isNotEmpty) {
      final waiter = _pipelineState.decodeWaiters.removeAt(0);
      if (!waiter.completer.isCompleted) {
        waiter.granted = true;
        _pipelineState.activeUnscrambleTasks++;
        waiter.completer.complete();
        break;
      }
    }
  }

  Future<bool> _rememberAspectRatioFromBytes(
    String url,
    Uint8List bytes, {
    required void Function() checkActive,
  }) async {
    if (imageAspectRatioCache.containsKey(url)) {
      return true;
    }
    try {
      final codec = await instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          checkActive();
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
    } catch (error) {
      if (error is SourceTaskCancelled) rethrow;
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
