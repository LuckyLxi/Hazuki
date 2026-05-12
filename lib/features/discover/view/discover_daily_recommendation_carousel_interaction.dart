part of 'discover_daily_recommendation_carousel.dart';

extension _DiscoverDailyRecommendationCarouselInteraction
    on _DiscoverDailyRecommendationCarouselState {
  void _logCarouselEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    _sourceService.addApplicationLog(
      level: level,
      title: title,
      source: 'discover_carousel',
      content: {
        'sessionId': _carouselSessionId,
        'recommendationCount': _recommendationCount,
        'currentLogicalPage': _currentPage,
        'currentPhysicalPage': _pageController.hasClients
            ? _roundTo(
                _pageController.page ?? _initialPhysicalPage.toDouble(),
                3,
              )
            : _initialPhysicalPage,
        'detailOpen': _detailOpen,
        'isHovered': _isHovered,
        'isUserScrolling': _isUserScrolling,
        'isNormalizingLoopBoundary': _loopController.isNormalizingLoopBoundary,
        'usingMixedSnapshots': _usingMixedSnapshots,
        'protectedVisibleItemCount': _protectedVisibleItems.length,
        'hasPendingRecommendations': _hasPendingRecommendations,
        if (content != null) ...content,
      },
    );
  }

  void _cancelAutoPlay({required String trigger, String? reason}) {
    if (!_autoPlay.isArmed) {
      return;
    }
    _autoPlay.cancel();
    final content = <String, Object?>{'trigger': trigger};
    if (reason != null) {
      content['reason'] = reason;
    }
    _logCarouselEvent('Discover carousel autoplay cancelled', content: content);
  }

  void _startAutoPlay({required String trigger}) {
    _cancelAutoPlay(trigger: '${trigger}_restart');
    if (!_isLooping || _detailOpen || _isHovered || _isUserScrolling) {
      _logCarouselEvent(
        'Discover carousel autoplay skipped',
        content: {'trigger': trigger, 'reason': _autoPlaySkipReason},
      );
      return;
    }
    _logCarouselEvent(
      'Discover carousel autoplay armed',
      content: {
        'trigger': trigger,
        'intervalMs': _DiscoverDailyRecommendationCarouselState
            ._autoPlayInterval
            .inMilliseconds,
        'animationDurationMs': _DiscoverDailyRecommendationCarouselState
            ._autoPlayAnimationDuration
            .inMilliseconds,
      },
    );
    _autoPlay.arm(
      interval: _DiscoverDailyRecommendationCarouselState._autoPlayInterval,
      onTick: () {
        if (!mounted || !_pageController.hasClients) {
          _logCarouselEvent(
            'Discover carousel autoplay tick skipped',
            content: {
              'trigger': 'timer_tick',
              'mounted': mounted,
              'hasClients': _pageController.hasClients,
            },
          );
          return;
        }
        final currentPhysicalPage =
            _pageController.page?.round() ??
            _physicalPageForLogical(_currentPage);
        final targetPhysicalPage = currentPhysicalPage + 1;
        _logCarouselEvent(
          'Discover carousel autoplay tick',
          content: {
            'fromPhysicalPage': currentPhysicalPage,
            'toPhysicalPage': targetPhysicalPage,
            'fromLogicalPage': _logicalPageForPhysical(currentPhysicalPage),
            'toLogicalPage': _logicalPageForPhysical(targetPhysicalPage),
          },
        );
        _pageController.animateToPage(
          targetPhysicalPage,
          duration: _DiscoverDailyRecommendationCarouselState
              ._autoPlayAnimationDuration,
          curve: _DiscoverDailyRecommendationCarouselState._autoPlayCurve,
        );
      },
    );
  }

  void _handlePageChanged(int page) {
    if (!mounted || _recommendationCount == 0) {
      return;
    }
    final nextLogicalPage = _logicalPageForPhysical(page);
    final previousLogicalPage = _currentPage;
    _setCarouselState(() {
      _currentPage = nextLogicalPage;
    });
    _warmUpRecommendationCovers(nextLogicalPage);
    _scheduleProtectedItemRelease(trigger: 'page_changed');
    _logCarouselEvent(
      'Discover carousel page changed',
      content: {
        'physicalPage': page,
        'fromLogicalPage': previousLogicalPage,
        'toLogicalPage': nextLogicalPage,
        'isLoopGhost':
            _isLooping && (page <= 1 || page >= _recommendationCount + 2),
      },
    );
  }

  void _normalizeLoopBoundary() {
    _loopController.normalizeLoopBoundary(
      recommendationCount: _recommendationCount,
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_isLooping) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      if (!_isUserScrolling) {
        _setCarouselState(() {
          _isUserScrolling = true;
        });
        _logCarouselEvent(
          'Discover carousel user drag started',
          content: {
            'dragStartDx': _roundTo(
              notification.dragDetails?.globalPosition.dx ?? 0,
              1,
            ),
            'dragStartDy': _roundTo(
              notification.dragDetails?.globalPosition.dy ?? 0,
              1,
            ),
          },
        );
      }
      _cancelAutoPlay(trigger: 'user_drag_start', reason: 'user_scrolling');
      return false;
    }

    if (notification is ScrollEndNotification) {
      _normalizeLoopBoundary();
      _scheduleProtectedItemRelease(trigger: 'scroll_end');
      if (_isUserScrolling) {
        _setCarouselState(() {
          _isUserScrolling = false;
        });
        _logCarouselEvent('Discover carousel user drag ended');
      }
      _startAutoPlay(trigger: 'scroll_end');
    }

    return false;
  }

  DiscoverCarouselCardLayoutMetrics _buildCardLayoutMetrics({
    required double delta,
    required double heroCardWidth,
    required double pageExtent,
  }) {
    return buildDiscoverCarouselCardLayoutMetrics(
      delta: delta,
      heroCardWidth: heroCardWidth,
      pageExtent: pageExtent,
      itemSpacing: _DiscoverDailyRecommendationCarouselState._itemSpacing,
    );
  }

  String get _autoPlaySkipReason {
    if (!_isLooping) {
      return 'not_looping';
    }
    if (_detailOpen) {
      return 'detail_open';
    }
    if (_isHovered) {
      return 'hovered';
    }
    if (_isUserScrolling) {
      return 'user_scrolling';
    }
    return 'ready';
  }

  double _roundTo(num value, int fractionDigits) {
    return roundDiscoverCarouselValue(value, fractionDigits);
  }

  String _shortUrl(String url) {
    return shortenDiscoverCarouselUrl(url);
  }

  String _describeCardPhase(
    double delta,
    double clipScaleX,
    double cardOpacity,
  ) {
    return describeDiscoverCarouselCardPhase(delta, clipScaleX, cardOpacity);
  }

  void _reportCardLayout({
    required int physicalIndex,
    required int logicalIndex,
    required double delta,
    required double clipScaleX,
    required double clippedWidth,
    required double outerTranslateX,
    required double imageTranslateX,
    required double cardOpacity,
    required double heroCardWidth,
    required double pageExtent,
  }) {
    if (delta < -1.2 || delta > 2.2) {
      _reportedCardSnapshots.remove(physicalIndex);
      return;
    }
    final phase = _describeCardPhase(delta, clipScaleX, cardOpacity);
    final isLoopGhost =
        _isLooping &&
        (physicalIndex <= 1 || physicalIndex >= _recommendationCount + 2);
    final clipBucket = (clipScaleX * 10).round();
    final deltaBucket = (delta * 10).round();
    final outerBucket = (outerTranslateX / 12).round();
    final imageBucket = (imageTranslateX / 6).round();
    final snapshot =
        '$logicalIndex|$phase|$clipBucket|$deltaBucket|$outerBucket|$imageBucket|${isLoopGhost ? 1 : 0}';
    if (_reportedCardSnapshots[physicalIndex] == snapshot) {
      return;
    }
    _reportedCardSnapshots[physicalIndex] = snapshot;
    _logCarouselEvent(
      'Discover carousel card layout',
      content: {
        'physicalIndex': physicalIndex,
        'logicalIndex': logicalIndex,
        'phase': phase,
        'isLoopGhost': isLoopGhost,
        'delta': _roundTo(delta, 2),
        'clipScaleX': _roundTo(clipScaleX, 2),
        'clippedWidth': clippedWidth.round(),
        'heroCardWidth': heroCardWidth.round(),
        'pageExtent': pageExtent.round(),
        'outerTranslateX': _roundTo(outerTranslateX, 1),
        'imageTranslateX': _roundTo(imageTranslateX, 1),
        'cardOpacity': _roundTo(cardOpacity, 2),
      },
    );
  }

  void _reportImageState({
    required int physicalIndex,
    required int logicalIndex,
    required String heroTag,
    required String imageUrl,
    required HazukiCachedImageLoadState state,
  }) {
    final snapshot = '${logicalIndex}_${state.name}_$imageUrl';
    if (_reportedImageStates[physicalIndex] == snapshot) {
      return;
    }
    _reportedImageStates[physicalIndex] = snapshot;
    _logCarouselEvent(
      'Discover carousel image state changed',
      content: {
        'physicalIndex': physicalIndex,
        'logicalIndex': logicalIndex,
        'state': state.name,
        'heroTag': heroTag,
        'coverUrl': _shortUrl(imageUrl),
      },
    );
  }
}
