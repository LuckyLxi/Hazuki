import 'package:flutter/material.dart';

class ReaderListDiagnosticsSnapshot {
  const ReaderListDiagnosticsSnapshot({
    required this.pixels,
    required this.maxScrollExtent,
    required this.minScrollExtent,
    required this.viewportDimension,
    required this.extentBefore,
    required this.extentAfter,
    required this.atEdge,
    required this.outOfRange,
    required this.userDirection,
  });

  final double pixels;
  final double maxScrollExtent;
  final double minScrollExtent;
  final double viewportDimension;
  final double extentBefore;
  final double extentAfter;
  final bool atEdge;
  final bool outOfRange;
  final String userDirection;
}

class ReaderDiagnosticsSnapshot {
  const ReaderDiagnosticsSnapshot({
    required this.readerSessionId,
    required this.comicId,
    required this.epId,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.readerMode,
    required this.currentPageIndex,
    required this.currentPage,
    required this.pageIndicatorIndex,
    required this.totalPages,
    required this.controlsVisible,
    required this.tapToTurnPage,
    required this.pageIndicator,
    required this.pinchToZoom,
    required this.longPressToSave,
    required this.immersiveMode,
    required this.keepScreenOn,
    required this.customBrightness,
    required this.brightnessValue,
    required this.loadingImages,
    required this.loadImagesError,
    required this.noImageModeEnabled,
    required this.isZoomed,
    required this.zoomInteracting,
    required this.zoomScale,
    required this.activePointerCount,
    required this.providerCacheSize,
    required this.providerFutureCacheSize,
    required this.aspectRatioCacheSize,
    required this.prefetchAheadRunning,
    required this.activeUnscrambleTasks,
    required this.listUserScrollInProgress,
    required this.activeProgrammaticListScrollReason,
    required this.activeProgrammaticListTargetIndex,
    required this.lastCompletedProgrammaticListTargetIndex,
    required this.lastObservedListPixels,
    required this.pageControllerPage,
    required this.listSnapshot,
  });

  final String readerSessionId;
  final String comicId;
  final String epId;
  final String chapterTitle;
  final int chapterIndex;
  final String readerMode;
  final int currentPageIndex;
  final int currentPage;
  final int pageIndicatorIndex;
  final int totalPages;
  final bool controlsVisible;
  final bool tapToTurnPage;
  final bool pageIndicator;
  final bool pinchToZoom;
  final bool longPressToSave;
  final bool immersiveMode;
  final bool keepScreenOn;
  final bool customBrightness;
  final double brightnessValue;
  final bool loadingImages;
  final String? loadImagesError;
  final bool noImageModeEnabled;
  final bool isZoomed;
  final bool zoomInteracting;
  final double zoomScale;
  final int activePointerCount;
  final int providerCacheSize;
  final int providerFutureCacheSize;
  final int aspectRatioCacheSize;
  final bool prefetchAheadRunning;
  final int activeUnscrambleTasks;
  final bool listUserScrollInProgress;
  final String? activeProgrammaticListScrollReason;
  final int? activeProgrammaticListTargetIndex;
  final int? lastCompletedProgrammaticListTargetIndex;
  final double? lastObservedListPixels;
  final double? pageControllerPage;
  final ReaderListDiagnosticsSnapshot? listSnapshot;
}

class ReaderDiagnosticsState {
  int lastLoggedVisiblePageIndex = -1;
  double? lastObservedListPixels;
  bool listUserScrollInProgress = false;
  String? activeProgrammaticListScrollReason;
  int? activeProgrammaticListTargetIndex;
  int? lastCompletedProgrammaticListTargetIndex;
  DateTime? lastCompletedProgrammaticListScrollAt;
  int readerDiagnosticSequence = 0;
  DateTime? lastUnexpectedListJumpLoggedAt;

  bool shouldLogUnexpectedListJump() {
    final now = DateTime.now();
    final lastLoggedAt = lastUnexpectedListJumpLoggedAt;
    if (lastLoggedAt != null &&
        now.difference(lastLoggedAt) < const Duration(milliseconds: 900)) {
      return false;
    }
    lastUnexpectedListJumpLoggedAt = now;
    return true;
  }

  void markProgrammaticListScrollCompleted(int target) {
    lastCompletedProgrammaticListTargetIndex = target;
    lastCompletedProgrammaticListScrollAt = DateTime.now();
  }

  int nextDiagnosticSequence() => ++readerDiagnosticSequence;
}

double normalizeReaderLogDouble(num value) {
  final normalized = value.toDouble();
  if (!normalized.isFinite) {
    return 0;
  }
  return double.parse(normalized.toStringAsFixed(2));
}

List<Map<String, dynamic>> captureReaderRenderedItemsAround({
  required List<String> images,
  required List<GlobalKey> itemKeys,
  required int anchorIndex,
}) {
  if (images.isEmpty || itemKeys.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  final target = anchorIndex.clamp(0, images.length - 1);
  final start = (target - 2).clamp(0, images.length - 1);
  final end = (target + 2).clamp(0, images.length - 1);
  final items = <Map<String, dynamic>>[];
  for (var i = start; i <= end; i++) {
    if (i >= itemKeys.length) {
      continue;
    }
    final ctx = itemKeys[i].currentContext;
    if (ctx == null) {
      items.add({'index': i, 'mounted': false});
      continue;
    }
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      items.add({'index': i, 'mounted': true, 'hasSize': false});
      continue;
    }
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final height = renderObject.size.height;
    items.add({
      'index': i,
      'mounted': true,
      'top': normalizeReaderLogDouble(top),
      'height': normalizeReaderLogDouble(height),
      'bottom': normalizeReaderLogDouble(top + height),
    });
  }
  return items;
}

Map<String, dynamic> buildReaderLogPayload({
  required ReaderDiagnosticsSnapshot snapshot,
  Map<String, dynamic>? extra,
}) {
  final payload = <String, dynamic>{
    'sessionId': snapshot.readerSessionId,
    'comicId': snapshot.comicId,
    'epId': snapshot.epId,
    'chapterTitle': snapshot.chapterTitle,
    'chapterIndex': snapshot.chapterIndex,
    'readerMode': snapshot.readerMode,
    'currentPageIndex': snapshot.currentPageIndex,
    'currentPage': snapshot.currentPage,
    'pageIndicatorIndex': snapshot.pageIndicatorIndex,
    'totalPages': snapshot.totalPages,
    'controlsVisible': snapshot.controlsVisible,
    'tapToTurnPage': snapshot.tapToTurnPage,
    'pageIndicator': snapshot.pageIndicator,
    'pinchToZoom': snapshot.pinchToZoom,
    'longPressToSave': snapshot.longPressToSave,
    'immersiveMode': snapshot.immersiveMode,
    'keepScreenOn': snapshot.keepScreenOn,
    'customBrightness': snapshot.customBrightness,
    'brightnessValue': snapshot.brightnessValue,
    'loadingImages': snapshot.loadingImages,
    'loadImagesError': snapshot.loadImagesError,
    'noImageModeEnabled': snapshot.noImageModeEnabled,
    'isZoomed': snapshot.isZoomed,
    'zoomInteracting': snapshot.zoomInteracting,
    'zoomScale': snapshot.zoomScale,
    'activePointerCount': snapshot.activePointerCount,
    'providerCacheSize': snapshot.providerCacheSize,
    'providerFutureCacheSize': snapshot.providerFutureCacheSize,
    'aspectRatioCacheSize': snapshot.aspectRatioCacheSize,
    'prefetchAheadRunning': snapshot.prefetchAheadRunning,
    'activeUnscrambleTasks': snapshot.activeUnscrambleTasks,
    'listUserScrollInProgress': snapshot.listUserScrollInProgress,
    'activeProgrammaticListScrollReason':
        snapshot.activeProgrammaticListScrollReason,
    'activeProgrammaticListTargetIndex':
        snapshot.activeProgrammaticListTargetIndex,
    'lastCompletedProgrammaticListTargetIndex':
        snapshot.lastCompletedProgrammaticListTargetIndex,
    if (snapshot.lastObservedListPixels != null)
      'lastObservedListPixels': snapshot.lastObservedListPixels,
  };
  final listSnapshot = snapshot.listSnapshot;
  if (listSnapshot != null) {
    payload.addAll({
      'listPixels': listSnapshot.pixels,
      'listMaxScrollExtent': listSnapshot.maxScrollExtent,
      'listMinScrollExtent': listSnapshot.minScrollExtent,
      'listViewportDimension': listSnapshot.viewportDimension,
      'listExtentBefore': listSnapshot.extentBefore,
      'listExtentAfter': listSnapshot.extentAfter,
      'listAtEdge': listSnapshot.atEdge,
      'listOutOfRange': listSnapshot.outOfRange,
      'listUserDirection': listSnapshot.userDirection,
    });
  }
  if (snapshot.pageControllerPage != null) {
    payload['pageControllerPage'] = snapshot.pageControllerPage;
  }
  if (extra != null) {
    payload.addAll(extra);
  }
  return payload;
}
