import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models/hazuki_models.dart';
import '../services/source/source_capabilities.dart';
import '../widgets/cached_image_widgets.dart';
import 'ui_flags.dart';

class ComicCoverPrefetcher {
  ComicCoverPrefetcher({required SourceImageGateway imageGateway})
    : _imageGateway = imageGateway;

  final SourceImageGateway _imageGateway;
  final Set<String> _inFlightKeys = <String>{};
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _inFlightKeys.clear();
  }

  void prefetchAroundScroll({
    required List<ExploreComic> comics,
    required ScrollController scrollController,
    required double estimatedItemExtent,
    int extraBefore = 4,
    int extraAfter = 20,
    int maxRequests = 24,
    bool priority = true,
  }) {
    if (_disposed ||
        comics.isEmpty ||
        hazukiNoImageModeNotifier.value ||
        !scrollController.hasClients ||
        estimatedItemExtent <= 0) {
      return;
    }

    final position = scrollController.position;
    final firstVisible = (position.pixels / estimatedItemExtent).floor();
    final lastVisible =
        ((position.pixels + position.viewportDimension) / estimatedItemExtent)
            .ceil();
    final start = (firstVisible - extraBefore).clamp(0, comics.length - 1);
    final end = (lastVisible + extraAfter).clamp(0, comics.length - 1);

    prefetchRange(
      comics: comics,
      startIndex: start,
      endIndex: end,
      maxRequests: maxRequests,
      priority: priority,
    );
  }

  void prefetchRange({
    required List<ExploreComic> comics,
    required int startIndex,
    required int endIndex,
    int maxRequests = 24,
    bool priority = true,
  }) {
    if (_disposed ||
        comics.isEmpty ||
        maxRequests <= 0 ||
        hazukiNoImageModeNotifier.value) {
      return;
    }

    final start = startIndex.clamp(0, comics.length - 1);
    final end = endIndex.clamp(start, comics.length - 1);
    final requests = <_CoverPrefetchRequest>[];
    final seenKeys = <String>{};

    for (var index = start; index <= end; index++) {
      final request = _requestFor(comics[index]);
      if (request == null ||
          !seenKeys.add(request.cacheKey) ||
          _inFlightKeys.contains(request.cacheKey)) {
        continue;
      }
      if (_hasMemoryHit(request)) {
        continue;
      }
      requests.add(request);
      if (requests.length >= maxRequests) {
        break;
      }
    }

    for (final request in requests.reversed) {
      _startPrefetch(request, priority: priority);
    }
  }

  _CoverPrefetchRequest? _requestFor(ExploreComic comic) {
    final url = comic.cover.trim();
    if (url.isEmpty) {
      return null;
    }
    final sourceKey = comic.sourceKey.trim().isNotEmpty
        ? comic.sourceKey.trim()
        : _imageGateway.activeSourceKey;
    return _CoverPrefetchRequest(
      url: url,
      sourceKey: sourceKey,
      cacheKey: hazukiWidgetImageMemoryKey(url, sourceKey: sourceKey),
    );
  }

  bool _hasMemoryHit(_CoverPrefetchRequest request) {
    return peekHazukiWidgetImageMemory(
              request.url,
              sourceKey: request.sourceKey,
            ) !=
            null ||
        _imageGateway.peekImageBytesFromMemory(
              request.url,
              sourceKey: request.sourceKey,
            ) !=
            null;
  }

  void _startPrefetch(_CoverPrefetchRequest request, {required bool priority}) {
    _inFlightKeys.add(request.cacheKey);
    unawaited(
      _download(request, priority: priority).whenComplete(() {
        _inFlightKeys.remove(request.cacheKey);
      }),
    );
  }

  Future<void> _download(
    _CoverPrefetchRequest request, {
    required bool priority,
  }) async {
    try {
      final Uint8List bytes = await _imageGateway.downloadImageBytes(
        request.url,
        keepInMemory: true,
        priority: priority,
        sourceKey: request.sourceKey,
      );
      if (_disposed) {
        return;
      }
      putHazukiWidgetImageMemory(
        request.url,
        bytes,
        sourceKey: request.sourceKey,
      );
    } catch (_) {
      // Prefetch failures are intentionally silent; visible image widgets keep
      // their normal loading and error handling.
    }
  }
}

class _CoverPrefetchRequest {
  const _CoverPrefetchRequest({
    required this.url,
    required this.sourceKey,
    required this.cacheKey,
  });

  final String url;
  final String sourceKey;
  final String cacheKey;
}
