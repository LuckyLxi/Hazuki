import 'dart:async';

import 'package:flutter/material.dart';

class ReaderImagePipelineState {
  final Map<String, ImageProvider> providerCache = <String, ImageProvider>{};
  final Map<String, Future<ImageProvider>> providerFutureCache =
      <String, Future<ImageProvider>>{};
  final Map<String, double> imageAspectRatioCache = <String, double>{};
  final List<Completer<void>> decodeWaiters = <Completer<void>>[];
  final Map<String, int> imageIndexMap = <String, int>{};
  final Set<String> retryingImageUrls = <String>{};

  int activeUnscrambleTasks = 0;
  bool prefetchAheadRunning = false;
  int? queuedPrefetchAheadIndex;
  bool disposed = false;

  void resetForImages(List<String> images) {
    clearProviderCaches();
    imageAspectRatioCache.clear();
    retryingImageUrls.clear();
    activeUnscrambleTasks = 0;
    prefetchAheadRunning = false;
    queuedPrefetchAheadIndex = null;
    completeDecodeWaiters();
    rebuildImageIndexMap(images);
  }

  void rebuildImageIndexMap(List<String> images) {
    imageIndexMap
      ..clear()
      ..addEntries(
        images.asMap().entries.map((entry) {
          return MapEntry(entry.value, entry.key);
        }),
      );
  }

  void clearProviderCaches() {
    providerCache.clear();
    providerFutureCache.clear();
  }

  void completeDecodeWaiters() {
    for (final waiter in decodeWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    decodeWaiters.clear();
  }

  void dispose() {
    disposed = true;
    clearProviderCaches();
    imageAspectRatioCache.clear();
    retryingImageUrls.clear();
    activeUnscrambleTasks = 0;
    prefetchAheadRunning = false;
    queuedPrefetchAheadIndex = null;
    completeDecodeWaiters();
  }
}
