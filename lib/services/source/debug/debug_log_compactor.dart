import 'debug_log_internals.dart';

/// Compacts captured log values and removes sensitive network headers.
class DebugLogCompactor {
  const DebugLogCompactor();

  dynamic compactNetworkHeaders(dynamic value) {
    if (value is! Map) {
      return compactGenericLogValue(
        value,
        maxStringLength: 160,
        maxItems: DebugLogConstants.networkHeadersKeep,
        maxDepth: 2,
      );
    }
    final filtered = <String, dynamic>{};
    const allowed = {
      'content-type',
      'content-length',
      'location',
      'cache-control',
      'set-cookie',
      'user-agent',
      'accept',
      'accept-language',
      'referer',
      'origin',
      'cookie',
      'authorization',
    };
    for (final entry in value.entries.take(
      DebugLogConstants.networkHeadersKeep,
    )) {
      final key = entry.key.toString();
      final lower = key.toLowerCase();
      if (!allowed.contains(lower)) continue;
      if (lower == 'cookie' ||
          lower == 'authorization' ||
          lower == 'set-cookie') {
        filtered[key] = '[redacted]';
        continue;
      }
      filtered[key] = compactGenericLogValue(
        entry.value,
        maxStringLength: 160,
        maxItems: 4,
        maxDepth: 2,
      );
    }
    return filtered;
  }

  dynamic compactNetworkPayload(dynamic value, {required int keep}) {
    return compactGenericLogValue(
      value,
      maxStringLength: keep,
      maxItems: 8,
      maxDepth: 4,
    );
  }

  dynamic compactReaderLogContent(
    dynamic value, {
    required String source,
    required String level,
  }) {
    final compacted = compactGenericLogValue(
      value,
      maxStringLength: DebugLogConstants.readerStringKeep,
      maxItems: 40,
      maxDepth: 4,
    );
    if (compacted is! Map) return compacted;

    final normalizedLevel = level.toLowerCase();
    final keepBaseKeys = <String>{
      'sessionId',
      'epId',
      'readerMode',
      'currentPage',
      'totalPages',
    };
    final keepEventKeys = <String>{
      'trigger',
      'pageIndex',
      'page',
      'fromPageIndex',
      'fromPage',
      'targetPageIndex',
      'targetPage',
      'targetImageIndex',
      'targetImage',
      'targetEpId',
      'targetChapterIndex',
      'targetChapterTitle',
      'setting',
      'value',
      'previousValue',
      'nextValue',
      'brightnessPercent',
      'error',
      'imageCount',
      'incomingImageCount',
      'hasInitialImages',
      'imageUrl',
      'savedPath',
      'enabled',
      'controlsVisible',
      'settingsLoaded',
      'providerCachesCleared',
      'hadCachedChapterDetails',
      'hasVisibleContext',
      'listHasClients',
      'reason',
      'offset',
      'attempt',
      'animate',
      'path',
      'syncPath',
      'notificationType',
      'overscroll',
      'velocity',
      'depth',
      'diagnosticSequence',
      'previousListPixels',
      'currentListPixels',
      'listDeltaPixels',
      'jumpedToTop',
      'largeJump',
      'resolvedPageIndex',
      'resolvedPage',
      'visibleImageIndices',
    };
    final keepVerboseKeys = <String>{
      'comicId',
      'chapterTitle',
      'chapterIndex',
      'doublePageMode',
      'currentPageIndex',
      'pageIndicatorIndex',
      'loadImagesError',
      'listViewportDimension',
      'listExtentBefore',
      'listExtentAfter',
      'listAtEdge',
      'listOutOfRange',
      'listUserDirection',
      'nearbyRenderedItems',
      'activeProgrammaticListScrollReason',
      'activeProgrammaticListTargetIndex',
      'lastCompletedProgrammaticListTargetIndex',
      'lastObservedListPixels',
      'zoomScale',
      'activePointerCount',
      'providerCacheSize',
      'providerFutureCacheSize',
      'aspectRatioCacheSize',
      'prefetchAheadRunning',
      'activeUnscrambleTasks',
      'listUserScrollInProgress',
      'controlsVisible',
      'tapToTurnPage',
      'pageIndicator',
      'pinchToZoom',
      'longPressToSave',
      'immersiveMode',
      'keepScreenOn',
      'customBrightness',
      'brightnessValue',
      'loadingImages',
      'noImageModeEnabled',
      'isZoomed',
      'zoomInteracting',
      'listPixels',
      'listMaxScrollExtent',
      'listMinScrollExtent',
      'pageControllerPage',
    };
    final shouldKeepVerbose =
        normalizedLevel == 'warning' || normalizedLevel == 'error';
    final filtered = <String, dynamic>{};
    for (final entry in compacted.entries) {
      final key = entry.key.toString();
      if (keepBaseKeys.contains(key) ||
          keepEventKeys.contains(key) ||
          (shouldKeepVerbose && keepVerboseKeys.contains(key))) {
        filtered[key] = entry.value;
      }
    }
    if (filtered['nearbyRenderedItems'] is List && !shouldKeepVerbose) {
      filtered.remove('nearbyRenderedItems');
    }
    return filtered;
  }

  dynamic compactGenericLogValue(
    dynamic value, {
    required int maxStringLength,
    required int maxItems,
    required int maxDepth,
    int depth = 0,
  }) {
    if (value == null) return null;
    if (depth >= maxDepth) {
      if (value is Map) return '[map omitted]';
      if (value is Iterable && value is! String) return '[list omitted]';
    }
    if (value is String) {
      return toBodyPreview(value, keep: maxStringLength);
    }
    if (value is num || value is bool) return value;
    if (value is Map) {
      final result = <String, dynamic>{};
      var kept = 0;
      for (final entry in value.entries) {
        if (kept >= maxItems) {
          result['__truncated__'] = '+${value.length - maxItems} keys';
          break;
        }
        final normalized = compactGenericLogValue(
          entry.value,
          maxStringLength: maxStringLength,
          maxItems: maxItems,
          maxDepth: maxDepth,
          depth: depth + 1,
        );
        if (normalized != null) {
          result[entry.key.toString()] = normalized;
          kept++;
        }
      }
      return result;
    }
    if (value is Iterable) {
      final items = value.toList(growable: false);
      final limited = <dynamic>[];
      final takeCount = items.length > maxItems ? maxItems : items.length;
      for (var i = 0; i < takeCount; i++) {
        limited.add(
          compactGenericLogValue(
            items[i],
            maxStringLength: maxStringLength,
            maxItems: maxItems,
            maxDepth: maxDepth,
            depth: depth + 1,
          ),
        );
      }
      if (items.length > maxItems) {
        limited.add('[+${items.length - maxItems} items]');
      }
      return limited;
    }
    return toBodyPreview(value.toString(), keep: maxStringLength);
  }
}
