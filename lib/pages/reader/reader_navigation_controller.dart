import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_controller_support.dart';
import 'reader_diagnostics_support.dart';
import 'reader_mode.dart';
import 'reader_runtime_state.dart';

class ReaderNavigationController {
  ReaderNavigationController({
    required ReaderRuntimeState runtimeState,
    required ReaderDiagnosticsState diagnosticsState,
    required ScrollController scrollController,
    required PageController pageController,
    required ReaderIsMounted isMounted,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required ReaderVisiblePageLogger logVisiblePageChange,
    required ReaderResetZoom resetZoomImmediately,
    required void Function(int index) prefetchAround,
    required void Function(int index) requestPrefetchAhead,
    required bool Function() noImageModeEnabled,
    required void Function() toggleControlsVisibility,
  }) : _runtimeState = runtimeState,
       _diagnosticsState = diagnosticsState,
       _scrollController = scrollController,
       _pageController = pageController,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _logVisiblePageChange = logVisiblePageChange,
       _resetZoomImmediately = resetZoomImmediately,
       _prefetchAround = prefetchAround,
       _requestPrefetchAhead = requestPrefetchAhead,
       _noImageModeEnabled = noImageModeEnabled,
       _toggleControlsVisibility = toggleControlsVisibility;

  static const double unexpectedTopOffsetThreshold = 240;
  static const double topEdgeOffsetEpsilon = 8;

  final ReaderRuntimeState _runtimeState;
  final ReaderDiagnosticsState _diagnosticsState;
  final ScrollController _scrollController;
  final PageController _pageController;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final ReaderVisiblePageLogger _logVisiblePageChange;
  final ReaderResetZoom _resetZoomImmediately;
  final void Function(int index) _prefetchAround;
  final void Function(int index) _requestPrefetchAhead;
  final bool Function() _noImageModeEnabled;
  final void Function() _toggleControlsVisibility;

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_runtimeState.volumeButtonTurnPage || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      unawaited(goPreviousPage(trigger: 'keyboard_volume_up'));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      unawaited(goNextPage(trigger: 'keyboard_volume_down'));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> handlePlatformVolumeButtonPressed(String? direction) async {
    if (!_runtimeState.volumeButtonTurnPage) {
      return;
    }
    if (direction == 'up') {
      await goPreviousPage(trigger: 'hardware_volume_up');
      return;
    }
    if (direction == 'down') {
      await goNextPage(trigger: 'hardware_volume_down');
    }
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (_runtimeState.readerMode != ReaderMode.topToBottom ||
        notification.depth != 0 ||
        _runtimeState.images.isEmpty) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _diagnosticsState.listUserScrollInProgress =
          notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _diagnosticsState.listUserScrollInProgress = false;
    } else if (notification is OverscrollNotification) {
      final previousPixels = _diagnosticsState.lastObservedListPixels;
      _logListPositionSnapshot(
        'Reader list overscrolled',
        trigger: notification.overscroll < 0
            ? 'overscroll_top'
            : 'overscroll_bottom',
        previousPixels: previousPixels,
        level: 'warning',
        extra: {
          'notificationType': notification.runtimeType.toString(),
          'depth': notification.depth,
          'overscroll': normalizeReaderLogDouble(notification.overscroll),
          'velocity': normalizeReaderLogDouble(notification.velocity),
        },
      );
    }
    return false;
  }

  void handleScrollPositionChanged() {
    if (!_scrollController.hasClients ||
        _runtimeState.images.isEmpty ||
        _runtimeState.itemKeys.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return;
    }

    final currentPixels = position.pixels;
    final previousPixels = _diagnosticsState.lastObservedListPixels;
    var normalizedIndex = _runtimeState.currentPageIndex;

    for (var i = 0; i < _runtimeState.itemKeys.length; i++) {
      final ctx = _runtimeState.itemKeys[i].currentContext;
      if (ctx == null) {
        continue;
      }
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

    normalizedIndex = _runtimeState.normalizeSpreadIndex(normalizedIndex);
    if (_runtimeState.currentPageIndex != normalizedIndex) {
      _runtimeState.currentPageIndex = normalizedIndex;
      _logVisiblePageChange(index: normalizedIndex, trigger: 'scroll');
    }
    _runtimeState.setDisplayedPageIndex(normalizedIndex);

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
          currentPixels <= topEdgeOffsetEpsilon &&
          previousPixels >= unexpectedTopOffsetThreshold &&
          !hasRecentExpectedTopJump;
      final deltaPixels = currentPixels - previousPixels;
      final largeJump = deltaPixels.abs() >= math.max(viewport * 1.35, 1200.0);
      if ((jumpedToTop || largeJump) &&
          _diagnosticsState.shouldLogUnexpectedListJump()) {
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
            'deltaPixels': normalizeReaderLogDouble(deltaPixels),
            'jumpedToTop': jumpedToTop,
            'largeJump': largeJump,
          },
        );
      }
    }

    _diagnosticsState.lastObservedListPixels = currentPixels;
    if (!_noImageModeEnabled()) {
      _prefetchAround(normalizedIndex);
      _requestPrefetchAhead(normalizedIndex);
    }
  }

  void handlePageChanged(int index) {
    if (_runtimeState.pageNavigationLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted() ||
            !_pageController.hasClients ||
            _runtimeState.currentPageIndex == index) {
          return;
        }
        _pageController.jumpToPage(_runtimeState.currentPageIndex);
      });
      return;
    }
    final pageChanged = _runtimeState.currentPageIndex != index;
    final zoomWasActive = _runtimeState.isZoomed;
    _resetZoomImmediately(reason: 'page_swipe');
    if (pageChanged || zoomWasActive) {
      _updateState(() {
        _runtimeState.currentPageIndex = index;
      });
    }
    _runtimeState.setDisplayedPageIndex(index);
    _logVisiblePageChange(index: index, trigger: 'page_swipe');
    if (!_noImageModeEnabled()) {
      _prefetchAround(index);
      _requestPrefetchAhead(index);
    }
  }

  Future<void> handleTapUp(TapUpDetails details, double maxWidth) async {
    if (_runtimeState.activePointerCount > 1) {
      return;
    }
    final tapPagingEnabled =
        _runtimeState.readerMode == ReaderMode.rightToLeft &&
        _runtimeState.tapToTurnPage;
    final leftTriggerWidth = maxWidth * 0.25;
    final rightTriggerStart = maxWidth * 0.75;
    final dx = details.localPosition.dx;
    final isCenterTap = dx > leftTriggerWidth && dx < rightTriggerStart;
    if (tapPagingEnabled && !_runtimeState.pageNavigationLocked) {
      if (dx <= leftTriggerWidth) {
        await goPreviousPage();
        return;
      }
      if (dx >= rightTriggerStart) {
        await goNextPage();
        return;
      }
    }
    if (isCenterTap) {
      _toggleControlsVisibility();
    }
  }

  Future<void> goToPage(int index, {String trigger = 'manual'}) async {
    if (_runtimeState.readerSpreadCount <= 0) {
      return;
    }
    final target = _runtimeState.normalizeSpreadIndex(index);
    _logEvent(
      'Reader page navigation requested',
      source: 'reader_navigation',
      content: _logPayload({
        'trigger': trigger,
        'fromPageIndex': _runtimeState.currentPageIndex,
        'fromPage': _runtimeState.readerSpreadCount <= 0
            ? 0
            : math.min(
                _runtimeState.currentPageIndex + 1,
                _runtimeState.readerSpreadCount,
              ),
        'targetPageIndex': target,
        'targetPage': target + 1,
      }),
    );
    _runtimeState.setDisplayedPageIndex(target);
    if (_runtimeState.readerMode == ReaderMode.rightToLeft) {
      if (!_pageController.hasClients ||
          target == _runtimeState.currentPageIndex) {
        return;
      }
      _resetZoomImmediately(reason: 'page_navigation_request');
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _scrollToListReaderPage(target, trigger: trigger);
  }

  Future<void> goPreviousPage({String trigger = 'tap_previous_zone'}) async {
    if (_runtimeState.currentPageIndex <= 0) {
      return;
    }
    await goToPage(_runtimeState.currentPageIndex - 1, trigger: trigger);
  }

  Future<void> goNextPage({String trigger = 'tap_next_zone'}) async {
    if (_runtimeState.currentPageIndex >= _runtimeState.readerSpreadCount - 1) {
      return;
    }
    await goToPage(_runtimeState.currentPageIndex + 1, trigger: trigger);
  }

  void syncPositionToImageIndex(
    int targetImageIndex, {
    required String trigger,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted() || _runtimeState.images.isEmpty) {
        return;
      }
      final safeImageIndex = math.max(
        0,
        math.min(targetImageIndex, _runtimeState.images.length - 1),
      );
      final target = _runtimeState.normalizeSpreadIndex(
        safeImageIndex ~/ _runtimeState.readerSpreadSize,
      );
      _runtimeState.currentPageIndex = target;
      _runtimeState.setDisplayedPageIndex(target);
      _logEvent(
        'Reader position synced after layout change',
        source: 'reader_navigation',
        content: _logPayload({
          'trigger': trigger,
          'targetImageIndex': safeImageIndex,
          'targetImage': safeImageIndex + 1,
          'targetPageIndex': target,
          'targetPage': target + 1,
          'syncPath': _runtimeState.readerMode == ReaderMode.rightToLeft
              ? 'page_controller_jump'
              : 'list_scroll_alignment',
        }),
      );
      _logVisiblePageChange(index: target, trigger: trigger);
      if (_runtimeState.readerMode == ReaderMode.rightToLeft) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(target);
        }
      } else {
        unawaited(
          _scrollToListReaderPage(target, animate: false, trigger: trigger),
        );
      }
    });
  }

  Future<void> syncPositionAfterPinchToggle(int targetImageIndex) async {
    const maxAttempts = 6;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!_isMounted() || _runtimeState.images.isEmpty) {
        return;
      }
      final safeImageIndex = math.max(
        0,
        math.min(targetImageIndex, _runtimeState.images.length - 1),
      );
      final target = _runtimeState.normalizeSpreadIndex(
        safeImageIndex ~/ _runtimeState.readerSpreadSize,
      );
      _runtimeState.currentPageIndex = target;
      _runtimeState.setDisplayedPageIndex(target);

      if (_runtimeState.readerMode == ReaderMode.rightToLeft) {
        if (!_pageController.hasClients) {
          continue;
        }
        _pageController.jumpToPage(target);
        _logEvent(
          'Reader position synced after pinch toggle',
          source: 'reader_navigation',
          content: _logPayload({
            'targetPageIndex': target,
            'targetPage': target + 1,
            'syncPath': 'page_controller_jump',
            'attempt': attempt,
          }),
        );
        _logVisiblePageChange(
          index: target,
          trigger: 'pinch_to_zoom_toggle_sync',
        );
        return;
      }

      if (!_scrollController.hasClients) {
        continue;
      }
      await _scrollToListReaderPage(
        target,
        animate: false,
        trigger: 'pinch_to_zoom_toggle_sync_attempt_$attempt',
      );
      if (!_isMounted()) {
        return;
      }
      _logEvent(
        'Reader position synced after pinch toggle',
        source: 'reader_navigation',
        content: _logPayload({
          'targetPageIndex': target,
          'targetPage': target + 1,
          'syncPath': 'list_scroll_alignment',
          'attempt': attempt,
        }),
      );
      _logVisiblePageChange(
        index: target,
        trigger: 'pinch_to_zoom_toggle_sync',
      );
      return;
    }

    _logEvent(
      'Reader position sync after pinch toggle skipped',
      level: 'warning',
      source: 'reader_navigation',
      content: _logPayload({
        'targetImageIndex': targetImageIndex,
        'targetImage': _runtimeState.images.isEmpty ? 0 : targetImageIndex + 1,
        'reason': _runtimeState.readerMode == ReaderMode.rightToLeft
            ? 'page_controller_unavailable'
            : 'scroll_controller_unavailable',
      }),
    );
  }

  Future<void> _scrollToListReaderPage(
    int index, {
    bool animate = true,
    String trigger = 'manual',
  }) async {
    if (!_scrollController.hasClients || _runtimeState.readerSpreadCount <= 0) {
      _logEvent(
        'Reader list scroll skipped',
        level: 'warning',
        source: 'reader_navigation',
        content: _logPayload({
          'trigger': trigger,
          'reason': !_scrollController.hasClients
              ? 'scroll_controller_has_no_clients'
              : 'images_empty',
          'targetPageIndex': index,
          'animate': animate,
        }),
      );
      return;
    }
    final target = _runtimeState.normalizeSpreadIndex(index);
    final visibleContext = target < _runtimeState.itemKeys.length
        ? _runtimeState.itemKeys[target].currentContext
        : null;
    _diagnosticsState.activeProgrammaticListScrollReason = trigger;
    _diagnosticsState.activeProgrammaticListTargetIndex = target;
    try {
      if (visibleContext != null) {
        await Scrollable.ensureVisible(
          visibleContext,
          duration: animate ? const Duration(milliseconds: 360) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 0,
        );
        if (!_isMounted()) {
          return;
        }
        _diagnosticsState.markProgrammaticListScrollCompleted(target);
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final ratio = _runtimeState.readerSpreadCount <= 1
          ? 0.0
          : target / (_runtimeState.readerSpreadCount - 1);
      final estimatedOffset = math.max(
        0.0,
        math.min(maxScrollExtent * ratio, maxScrollExtent),
      );
      if (animate) {
        await _scrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(estimatedOffset);
      }

      if (!_isMounted()) {
        return;
      }
      _diagnosticsState.markProgrammaticListScrollCompleted(target);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted()) {
          return;
        }
        final exactContext = target < _runtimeState.itemKeys.length
            ? _runtimeState.itemKeys[target].currentContext
            : null;
        if (exactContext == null) {
          _logEvent(
            'Reader list exact alignment skipped',
            level: 'warning',
            source: 'reader_navigation',
            content: _logPayload({
              'trigger': '${trigger}_post_frame_exact_alignment',
              'targetPageIndex': target,
              'targetPage': target + 1,
              'reason': 'target_context_not_available_after_estimated_scroll',
              'animate': animate,
            }),
          );
          return;
        }
        _diagnosticsState.activeProgrammaticListScrollReason =
            '${trigger}_post_frame_exact_alignment';
        _diagnosticsState.activeProgrammaticListTargetIndex = target;
        unawaited(
          Scrollable.ensureVisible(
            exactContext,
            duration: animate
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            alignment: 0,
          ).then((_) {
            _diagnosticsState.activeProgrammaticListScrollReason = null;
            _diagnosticsState.activeProgrammaticListTargetIndex = null;
            _diagnosticsState.markProgrammaticListScrollCompleted(target);
          }),
        );
      });
    } finally {
      _diagnosticsState.activeProgrammaticListScrollReason = null;
      _diagnosticsState.activeProgrammaticListTargetIndex = null;
    }
  }

  List<Map<String, dynamic>> _captureRenderedItemsAround(int anchorIndex) {
    return captureReaderRenderedItemsAround(
      itemCount: _runtimeState.readerSpreadCount,
      itemKeys: _runtimeState.itemKeys,
      anchorIndex: anchorIndex,
    );
  }

  void _logListPositionSnapshot(
    String title, {
    required String trigger,
    double? previousPixels,
    int? normalizedIndex,
    String level = 'info',
    Map<String, dynamic>? extra,
  }) {
    final payload = <String, dynamic>{
      'trigger': trigger,
      'diagnosticSequence': _diagnosticsState.nextDiagnosticSequence(),
      if (previousPixels != null)
        'previousListPixels': normalizeReaderLogDouble(previousPixels),
    };
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      payload.addAll({
        'currentListPixels': normalizeReaderLogDouble(position.pixels),
        if (previousPixels != null)
          'listDeltaPixels': normalizeReaderLogDouble(
            position.pixels - previousPixels,
          ),
        'listMaxScrollExtent': normalizeReaderLogDouble(
          position.maxScrollExtent,
        ),
        'listViewportDimension': normalizeReaderLogDouble(
          position.viewportDimension,
        ),
        'listExtentBefore': normalizeReaderLogDouble(position.extentBefore),
        'listExtentAfter': normalizeReaderLogDouble(position.extentAfter),
        'listAtEdge': position.atEdge,
        'listOutOfRange': position.outOfRange,
        'listUserDirection': position.userScrollDirection.name,
        'nearbyRenderedItems': _captureRenderedItemsAround(
          normalizedIndex ?? _runtimeState.currentPageIndex,
        ),
      });
    } else {
      payload['listHasClients'] = false;
    }
    if (extra != null) {
      payload.addAll(extra);
    }
    _logEvent(
      title,
      level: level,
      source: 'reader_position',
      content: _logPayload(payload),
    );
  }
}
