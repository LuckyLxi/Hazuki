import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

class DiscoverDailyRecommendationCarousel extends StatefulWidget {
  const DiscoverDailyRecommendationCarousel({
    super.key,
    required this.displayedRecommendations,
    this.pendingRecommendations = const <DiscoverDailyRecommendationEntry>[],
    this.isPendingReady = false,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final List<DiscoverDailyRecommendationEntry> displayedRecommendations;
  final List<DiscoverDailyRecommendationEntry> pendingRecommendations;
  final bool isPendingReady;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverDailyRecommendationCarousel> createState() =>
      _DiscoverDailyRecommendationCarouselState();
}

class _DiscoverDailyRecommendationCarouselState
    extends State<DiscoverDailyRecommendationCarousel> {
  static const _autoPlayInterval = Duration(seconds: 3);
  static const _autoPlayAnimationDuration = Duration(milliseconds: 1000);
  static const _heroCardMaxWidth = 300.0;
  static const _heroCardHeight = 213.0;
  static const _itemSpacing = 8.0;
  static const Curve _autoPlayCurve = _AnimekoEmphasizedCurve();

  late PageController _pageController;
  Timer? _autoPlayTimer;
  late final String _carouselSessionId;
  late List<DiscoverDailyRecommendationEntry> _displayedRecommendations;
  List<DiscoverDailyRecommendationEntry> _pendingRecommendations =
      const <DiscoverDailyRecommendationEntry>[];
  final Set<int> _protectedVisibleItems = <int>{};
  final Set<int> _prefetchedCoverIndexes = <int>{};
  final Map<int, String> _reportedCardSnapshots = <int, String>{};
  final Map<int, String> _reportedImageStates = <int, String>{};
  int _currentPage = 0;
  bool _detailOpen = false;
  String? _activeOverlayHeroTag;
  Animation<double>? _routeSecondaryAnimation;
  Timer? _overlayRevealTimer;
  bool _isHovered = false;
  bool _isUserScrolling = false;
  bool _isNormalizingLoopBoundary = false;
  bool _usingMixedSnapshots = false;
  bool _pendingActivationScheduled = false;
  double? _lastHeroCardWidth;
  double? _lastPageExtent;
  double? _lastViewportWidth;
  String _displayedSnapshotKey = '';
  String _pendingSnapshotKey = '';

  int get _recommendationCount => _displayedRecommendations.length;

  bool get _hasPendingRecommendations => _pendingRecommendations.isNotEmpty;

  bool get _isLooping => _recommendationCount > 1;

  int get _loopedItemCount =>
      _isLooping ? _recommendationCount + 5 : _recommendationCount;

  int get _initialPhysicalPage => _isLooping ? 2 : 0;

  int _physicalPageForLogical(int logicalPage) {
    if (!_isLooping) {
      return logicalPage;
    }
    return logicalPage + 2;
  }

  int _logicalPageForPhysical(int physicalPage) {
    if (_recommendationCount == 0) {
      return 0;
    }
    if (!_isLooping) {
      return physicalPage.clamp(0, _recommendationCount - 1);
    }
    final normalized = (physicalPage - 2) % _recommendationCount;
    return normalized < 0 ? normalized + _recommendationCount : normalized;
  }

  int _normalizeLogicalPage(int logicalPage) {
    if (_recommendationCount == 0) {
      return 0;
    }
    final normalized = logicalPage % _recommendationCount;
    return normalized < 0 ? normalized + _recommendationCount : normalized;
  }

  @override
  void initState() {
    super.initState();
    if (useWindowsComicDetailPanel) {
      WindowsComicDetailController.instance.addListener(
        _handleWindowsDetailControllerChanged,
      );
    }
    _displayedRecommendations =
        List<DiscoverDailyRecommendationEntry>.unmodifiable(
          widget.displayedRecommendations,
        );
    _displayedSnapshotKey = _snapshotKey(_displayedRecommendations);
    if (widget.isPendingReady && widget.pendingRecommendations.isNotEmpty) {
      _pendingRecommendations =
          List<DiscoverDailyRecommendationEntry>.unmodifiable(
            widget.pendingRecommendations,
          );
      _pendingSnapshotKey = _snapshotKey(_pendingRecommendations);
    }
    _carouselSessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _pageController = PageController(
      initialPage: _initialPhysicalPage,
      viewportFraction: 0.84,
    );
    _logCarouselEvent(
      'Discover carousel initialized',
      content: {
        'initialPhysicalPage': _initialPhysicalPage,
        'initialLogicalPage': _currentPage,
        'loopedItemCount': _loopedItemCount,
        'isLooping': _isLooping,
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _warmUpRecommendationCovers(_currentPage);
      if (_hasPendingRecommendations) {
        _schedulePendingActivation(trigger: 'init_state_pending');
      }
    });
    _startAutoPlay(trigger: 'init_state');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouteAnimationIfNeeded();
  }

  @override
  void didUpdateWidget(
    covariant DiscoverDailyRecommendationCarousel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    final nextDisplayedKey = _snapshotKey(widget.displayedRecommendations);
    final nextPendingKey = widget.isPendingReady
        ? _snapshotKey(widget.pendingRecommendations)
        : '';
    var changed = false;

    if (!widget.isPendingReady || widget.pendingRecommendations.isEmpty) {
      if (nextDisplayedKey != _displayedSnapshotKey ||
          _hasPendingRecommendations ||
          _usingMixedSnapshots) {
        _replaceDisplayedRecommendations(widget.displayedRecommendations);
        _clearPendingRecommendations();
        changed = true;
      }
      if (changed && mounted) {
        setState(() {});
      }
      return;
    }

    if (nextDisplayedKey != _displayedSnapshotKey && !_usingMixedSnapshots) {
      _replaceDisplayedRecommendations(widget.displayedRecommendations);
      changed = true;
    }

    if (nextPendingKey != _pendingSnapshotKey) {
      _pendingRecommendations =
          List<DiscoverDailyRecommendationEntry>.unmodifiable(
            widget.pendingRecommendations,
          );
      _pendingSnapshotKey = nextPendingKey;
      changed = true;
      if (_displayedRecommendations.isEmpty) {
        _replaceDisplayedRecommendations(widget.pendingRecommendations);
        _clearPendingRecommendations();
      } else {
        _schedulePendingActivation(trigger: 'widget_update_pending');
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cancelAutoPlay(trigger: 'dispose');
    _overlayRevealTimer?.cancel();
    _detachRouteAnimation();
    if (useWindowsComicDetailPanel) {
      WindowsComicDetailController.instance.removeListener(
        _handleWindowsDetailControllerChanged,
      );
    }
    _logCarouselEvent(
      'Discover carousel disposed',
      content: {
        'reportedCardCount': _reportedCardSnapshots.length,
        'reportedImageCount': _reportedImageStates.length,
      },
    );
    _pageController.dispose();
    super.dispose();
  }

  void _attachRouteAnimationIfNeeded() {
    final route = ModalRoute.of(context);
    final nextSecondaryAnimation = route?.secondaryAnimation;
    if (identical(nextSecondaryAnimation, _routeSecondaryAnimation)) {
      _syncOverlayHeroTagWithRoute();
      return;
    }
    _detachRouteAnimation();
    _routeSecondaryAnimation = nextSecondaryAnimation;
    _routeSecondaryAnimation?.addStatusListener(_handleRouteStatusChanged);
    _syncOverlayHeroTagWithRoute();
  }

  void _detachRouteAnimation() {
    _routeSecondaryAnimation?.removeStatusListener(_handleRouteStatusChanged);
    _routeSecondaryAnimation = null;
  }

  void _handleRouteStatusChanged(AnimationStatus _) {
    if (!mounted) {
      return;
    }
    _syncOverlayHeroTagWithRoute();
  }

  void _syncOverlayHeroTagWithRoute() {
    if (_detailOpen || _activeOverlayHeroTag == null) {
      return;
    }
    final secondaryAnimation = _routeSecondaryAnimation;
    if (secondaryAnimation != null &&
        secondaryAnimation.status != AnimationStatus.dismissed) {
      return;
    }
    _scheduleOverlayReveal();
  }

  void _scheduleOverlayReveal({
    Duration delay = Duration.zero,
    String? trigger,
  }) {
    _overlayRevealTimer?.cancel();
    if (_activeOverlayHeroTag == null) {
      return;
    }
    if (delay <= Duration.zero) {
      if (!mounted) {
        _activeOverlayHeroTag = null;
      } else {
        setState(() {
          _activeOverlayHeroTag = null;
        });
      }
      return;
    }
    _overlayRevealTimer = Timer(delay, () {
      if (!mounted || _detailOpen || _activeOverlayHeroTag == null) {
        return;
      }
      setState(() {
        _activeOverlayHeroTag = null;
      });
      if (trigger != null) {
        _logCarouselEvent(
          'Discover carousel overlay restored',
          content: {'trigger': trigger, 'logicalPage': _currentPage},
        );
      }
    });
  }

  void _replaceDisplayedRecommendations(
    List<DiscoverDailyRecommendationEntry> recommendations,
  ) {
    _displayedRecommendations =
        List<DiscoverDailyRecommendationEntry>.unmodifiable(recommendations);
    _displayedSnapshotKey = _snapshotKey(_displayedRecommendations);
    _prefetchedCoverIndexes.clear();
    _reportedCardSnapshots.clear();
    _reportedImageStates.clear();
    _currentPage = _recommendationCount == 0
        ? 0
        : _normalizeLogicalPage(_currentPage);
  }

  void _clearPendingRecommendations() {
    _pendingRecommendations = const <DiscoverDailyRecommendationEntry>[];
    _pendingSnapshotKey = '';
    _usingMixedSnapshots = false;
    _pendingActivationScheduled = false;
    _protectedVisibleItems.clear();
  }

  String _snapshotKey(List<DiscoverDailyRecommendationEntry> recommendations) {
    return recommendations
        .map(
          (entry) =>
              '${entry.author}|${entry.comic.id}|${entry.comic.title}|${entry.comic.cover}',
        )
        .join('||');
  }

  void _logCarouselEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    HazukiSourceService.instance.addApplicationLog(
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
        'isNormalizingLoopBoundary': _isNormalizingLoopBoundary,
        'usingMixedSnapshots': _usingMixedSnapshots,
        'protectedVisibleItemCount': _protectedVisibleItems.length,
        'hasPendingRecommendations': _hasPendingRecommendations,
        if (content != null) ...content,
      },
    );
  }

  void _cancelAutoPlay({required String trigger, String? reason}) {
    final hadTimer = _autoPlayTimer != null;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    if (!hadTimer) {
      return;
    }
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
        'intervalMs': _autoPlayInterval.inMilliseconds,
        'animationDurationMs': _autoPlayAnimationDuration.inMilliseconds,
      },
    );
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
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
        duration: _autoPlayAnimationDuration,
        curve: _autoPlayCurve,
      );
    });
  }

  void _handlePageChanged(int page) {
    if (!mounted || _recommendationCount == 0) {
      return;
    }
    final nextLogicalPage = _logicalPageForPhysical(page);
    final previousLogicalPage = _currentPage;
    setState(() {
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
    if (!_isLooping ||
        !_pageController.hasClients ||
        _isNormalizingLoopBoundary) {
      return;
    }
    final settledPage = _pageController.page?.round();
    if (settledPage == null) {
      return;
    }
    final itemCount = _recommendationCount;
    if (settledPage <= 1) {
      _logCarouselEvent(
        'Discover carousel loop boundary detected',
        content: {
          'settledPhysicalPage': settledPage,
          'jumpTargetPhysicalPage': settledPage + itemCount,
          'settledLogicalPage': _logicalPageForPhysical(settledPage),
          'jumpTargetLogicalPage': _logicalPageForPhysical(
            settledPage + itemCount,
          ),
        },
      );
      _scheduleLoopBoundaryJump(settledPage + itemCount);
      return;
    }
    if (settledPage >= itemCount + 2) {
      _logCarouselEvent(
        'Discover carousel loop boundary detected',
        content: {
          'settledPhysicalPage': settledPage,
          'jumpTargetPhysicalPage': settledPage - itemCount,
          'settledLogicalPage': _logicalPageForPhysical(settledPage),
          'jumpTargetLogicalPage': _logicalPageForPhysical(
            settledPage - itemCount,
          ),
        },
      );
      _scheduleLoopBoundaryJump(settledPage - itemCount);
    }
  }

  void _scheduleLoopBoundaryJump(int targetPage) {
    _isNormalizingLoopBoundary = true;
    _logCarouselEvent(
      'Discover carousel loop boundary jump scheduled',
      content: {
        'targetPhysicalPage': targetPage,
        'targetLogicalPage': _logicalPageForPhysical(targetPage),
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        _isNormalizingLoopBoundary = false;
        _logCarouselEvent(
          'Discover carousel loop boundary jump aborted',
          content: {
            'targetPhysicalPage': targetPage,
            'mounted': mounted,
            'hasClients': _pageController.hasClients,
          },
        );
        return;
      }
      _pageController.jumpToPage(targetPage);
      _isNormalizingLoopBoundary = false;
      _scheduleProtectedItemRelease(trigger: 'loop_boundary_jump');
      _logCarouselEvent(
        'Discover carousel loop boundary jump applied',
        content: {
          'targetPhysicalPage': targetPage,
          'targetLogicalPage': _logicalPageForPhysical(targetPage),
        },
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_isLooping) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      if (!_isUserScrolling) {
        setState(() {
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
        setState(() {
          _isUserScrolling = false;
        });
        _logCarouselEvent('Discover carousel user drag ended');
      }
      _startAutoPlay(trigger: 'scroll_end');
    }

    return false;
  }

  void _schedulePendingActivation({required String trigger}) {
    if (_pendingActivationScheduled) {
      return;
    }
    _pendingActivationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingActivationScheduled = false;
      if (!mounted) {
        return;
      }
      _activatePendingRecommendations(trigger: trigger);
    });
  }

  void _activatePendingRecommendations({required String trigger}) {
    if (_usingMixedSnapshots ||
        !_hasPendingRecommendations ||
        _displayedRecommendations.isEmpty) {
      return;
    }
    if (_pendingSnapshotKey == _displayedSnapshotKey) {
      _completePendingPromotion(trigger: '${trigger}_same_snapshot');
      return;
    }
    final protectedVisibleItems = _computeVisibleLogicalItems();
    if (protectedVisibleItems.isEmpty && _recommendationCount > 0) {
      protectedVisibleItems.add(_normalizeLogicalPage(_currentPage));
    }
    setState(() {
      _usingMixedSnapshots = true;
      _protectedVisibleItems
        ..clear()
        ..addAll(protectedVisibleItems);
    });
    _logCarouselEvent(
      'Discover carousel pending recommendations activated',
      content: {
        'trigger': trigger,
        'protectedVisibleItems': protectedVisibleItems.toList()..sort(),
      },
    );
  }

  void _scheduleProtectedItemRelease({required String trigger}) {
    if (!_usingMixedSnapshots) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _releaseOffscreenProtectedItems(trigger: trigger);
    });
  }

  void _releaseOffscreenProtectedItems({required String trigger}) {
    if (!_usingMixedSnapshots || !_hasPendingRecommendations) {
      return;
    }
    final visibleLogicalItems = _computeVisibleLogicalItems();
    final releasedItems = _protectedVisibleItems
        .where((index) => !visibleLogicalItems.contains(index))
        .toList(growable: false);
    if (releasedItems.isNotEmpty) {
      setState(() {
        _protectedVisibleItems.removeAll(releasedItems);
      });
      _logCarouselEvent(
        'Discover carousel protected items released',
        content: {
          'trigger': trigger,
          'releasedItems': releasedItems,
          'remainingProtectedItems': _protectedVisibleItems.toList()..sort(),
        },
      );
    }
    if (_protectedVisibleItems.isEmpty) {
      _completePendingPromotion(trigger: '${trigger}_promotion');
    }
  }

  void _completePendingPromotion({required String trigger}) {
    if (!_hasPendingRecommendations) {
      return;
    }
    final nextRecommendations = _pendingRecommendations;
    setState(() {
      _replaceDisplayedRecommendations(nextRecommendations);
      _clearPendingRecommendations();
    });
    _warmUpRecommendationCovers(_currentPage);
    unawaited(
      DiscoverDailyRecommendationService.instance
          .promotePendingRecommendations(),
    );
    _logCarouselEvent(
      'Discover carousel pending recommendations promoted',
      content: {'trigger': trigger},
    );
  }

  Set<int> _computeVisibleLogicalItems() {
    if (_recommendationCount == 0) {
      return <int>{};
    }
    final heroCardWidth = _lastHeroCardWidth;
    final pageExtent = _lastPageExtent;
    final viewportWidth = _lastViewportWidth;
    if (heroCardWidth == null || pageExtent == null || viewportWidth == null) {
      return <int>{_normalizeLogicalPage(_currentPage)};
    }
    final visibleLogicalItems = <int>{};
    final page = _pageController.hasClients
        ? (_pageController.page ??
              _physicalPageForLogical(_currentPage).toDouble())
        : _physicalPageForLogical(_currentPage).toDouble();
    final start = math.max(0, page.floor() - 2);
    final end = math.min(_loopedItemCount - 1, page.ceil() + 3);
    for (var physicalIndex = start; physicalIndex <= end; physicalIndex++) {
      final metrics = _buildCardLayoutMetrics(
        delta: physicalIndex - page,
        heroCardWidth: heroCardWidth,
        pageExtent: pageExtent,
      );
      if (metrics.visibleWidth(
            heroCardWidth: heroCardWidth,
            viewportWidth: viewportWidth,
          ) <=
          0.5) {
        continue;
      }
      visibleLogicalItems.add(_logicalPageForPhysical(physicalIndex));
    }
    return visibleLogicalItems;
  }

  List<int> _coverWarmUpOrder(int anchorLogicalPage) {
    if (_recommendationCount == 0) {
      return const <int>[];
    }
    final order = <int>[];
    for (var offset = 0; offset < _recommendationCount; offset++) {
      order.add(_normalizeLogicalPage(anchorLogicalPage + offset));
      if (offset > 0) {
        order.add(_normalizeLogicalPage(anchorLogicalPage - offset));
      }
    }
    return order.toSet().toList(growable: false);
  }

  void _warmUpRecommendationCovers(int anchorLogicalPage) {
    if (_recommendationCount == 0) {
      return;
    }
    for (final index in _coverWarmUpOrder(anchorLogicalPage)) {
      if (!_prefetchedCoverIndexes.add(index)) {
        continue;
      }
      unawaited(_prefetchRecommendationCover(index));
    }
  }

  Future<void> _prefetchRecommendationCover(int logicalIndex) async {
    final normalizedIndex = _normalizeLogicalPage(logicalIndex);
    final coverUrl = _resolvedRecommendationEntry(
      normalizedIndex,
    ).comic.cover.trim();
    if (coverUrl.isEmpty) {
      return;
    }
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        coverUrl,
        keepInMemory: true,
      );
      putHazukiWidgetImageMemory(coverUrl, bytes);
    } catch (_) {
      _prefetchedCoverIndexes.remove(normalizedIndex);
    }
  }

  DiscoverDailyRecommendationEntry _resolvedRecommendationEntry(
    int logicalIndex,
  ) {
    final normalizedIndex = _normalizeLogicalPage(logicalIndex);
    if (_usingMixedSnapshots &&
        _hasPendingRecommendations &&
        !_protectedVisibleItems.contains(normalizedIndex) &&
        normalizedIndex < _pendingRecommendations.length) {
      return _pendingRecommendations[normalizedIndex];
    }
    return _displayedRecommendations[normalizedIndex];
  }

  _CarouselCardLayoutMetrics _buildCardLayoutMetrics({
    required double delta,
    required double heroCardWidth,
    required double pageExtent,
  }) {
    const narrowRatio = 0.29;
    const incomingExpansionHold = 0.72;
    const parallaxRatio = 0.035;
    const trailingSmallRevealDelay = 0.42;

    double clipScaleX;
    double imageTranslateX;
    double cardScale;
    double cardOpacity;
    double outerTranslateX;
    final slotLeft = delta * pageExtent;
    final narrowWidth = heroCardWidth * narrowRatio;

    if (delta >= -1 && delta <= 0) {
      final progress = (-delta).clamp(0.0, 1.0);
      clipScaleX = _lerp(1.0, 0.0, progress);
      imageTranslateX = heroCardWidth * parallaxRatio * progress;
      cardScale = 1.0;
      cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;
      outerTranslateX = -slotLeft;
    } else if (delta > 0 && delta <= 1) {
      final progress = (1 - delta).clamp(0.0, 1.0);
      final lockedRightLeft = _itemSpacing + narrowWidth;
      double desiredLeft;

      if (progress < incomingExpansionHold) {
        final phase = progress / incomingExpansionHold;
        clipScaleX = _lerp(narrowRatio, 1.0, phase);
        desiredLeft = _lerp(
          heroCardWidth + _itemSpacing,
          lockedRightLeft,
          phase,
        );
      } else {
        final phase =
            (progress - incomingExpansionHold) / (1.0 - incomingExpansionHold);
        clipScaleX = 1.0;
        desiredLeft = _lerp(lockedRightLeft, 0.0, phase);
      }

      imageTranslateX = heroCardWidth * parallaxRatio * (1.0 - progress);
      cardScale = 1.0;
      cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;
      outerTranslateX = desiredLeft - slotLeft;
    } else if (delta > 1 && delta <= 2) {
      final progress = (2 - delta).clamp(0.0, 1.0);

      final lockedRightLeft = _itemSpacing + narrowWidth;
      double index1DesiredLeft;
      double index1ClipScaleX;

      if (progress < incomingExpansionHold) {
        final phase = progress / incomingExpansionHold;
        index1ClipScaleX = _lerp(narrowRatio, 1.0, phase);
        index1DesiredLeft = _lerp(
          heroCardWidth + _itemSpacing,
          lockedRightLeft,
          phase,
        );
      } else {
        final phase =
            (progress - incomingExpansionHold) / (1.0 - incomingExpansionHold);
        index1ClipScaleX = 1.0;
        index1DesiredLeft = _lerp(lockedRightLeft, 0.0, phase);
      }

      final index1ClippedWidth = (heroCardWidth * index1ClipScaleX).clamp(
        0.0,
        heroCardWidth,
      );
      final index1RightEdge = index1DesiredLeft + index1ClippedWidth;

      final revealProgress =
          ((progress - trailingSmallRevealDelay) /
                  (1.0 - trailingSmallRevealDelay))
              .clamp(0.0, 1.0);
      clipScaleX = _lerp(0.0, narrowRatio, revealProgress);
      imageTranslateX = heroCardWidth * parallaxRatio * delta;
      cardScale = 1.0;
      cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;

      final currentX = index1RightEdge + _itemSpacing;
      outerTranslateX = currentX - slotLeft;
    } else {
      clipScaleX = 0.0;
      imageTranslateX = 0.0;
      cardScale = 1.0;
      cardOpacity = 0.0;
      outerTranslateX = 0.0;
    }

    return _CarouselCardLayoutMetrics(
      clipScaleX: clipScaleX,
      imageTranslateX: imageTranslateX,
      cardScale: cardScale,
      cardOpacity: cardOpacity,
      outerTranslateX: outerTranslateX,
    );
  }

  double _lerp(double begin, double end, double t) {
    return begin + (end - begin) * t;
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
    return double.parse(value.toStringAsFixed(fractionDigits));
  }

  String _shortUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return normalized.length <= 120
          ? normalized
          : '${normalized.substring(0, 117)}...';
    }
    final host = uri.host;
    final path = uri.pathSegments.isEmpty
        ? uri.path
        : uri.pathSegments
              .skip(
                uri.pathSegments.length > 2 ? uri.pathSegments.length - 2 : 0,
              )
              .join('/');
    final compact = host.isEmpty ? normalized : '$host/$path';
    return compact.length <= 120 ? compact : '${compact.substring(0, 117)}...';
  }

  String _describeCardPhase(
    double delta,
    double clipScaleX,
    double cardOpacity,
  ) {
    if (cardOpacity <= 0.001 || clipScaleX <= 0.001) {
      return 'hidden';
    }
    if (delta >= -0.12 && delta <= 0.12) {
      return 'active';
    }
    if (delta > 0 && clipScaleX <= 0.36) {
      return 'incoming_thumbnail';
    }
    if (delta > 0 && clipScaleX < 0.98) {
      return 'incoming_expand';
    }
    if (delta > 0 && clipScaleX >= 0.98) {
      return 'incoming_full';
    }
    if (delta >= -1.0 && delta < 0) {
      return 'outgoing';
    }
    if (delta > 1.0) {
      return 'trailing_thumbnail';
    }
    return 'transitioning';
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

  Future<void> _openRecommendation(
    BuildContext context,
    DiscoverDailyRecommendationEntry entry,
    String heroTag,
  ) async {
    if (_detailOpen) {
      return;
    }
    _overlayRevealTimer?.cancel();
    if (mounted) {
      setState(() {
        _detailOpen = true;
        _activeOverlayHeroTag = heroTag;
      });
    } else {
      _detailOpen = true;
      _activeOverlayHeroTag = heroTag;
    }
    _logCarouselEvent(
      'Discover carousel recommendation opening',
      content: {
        'heroTag': heroTag,
        'logicalPage': _currentPage,
        'comicId': entry.comic.id,
        'comicTitle': entry.comic.title,
      },
    );
    _cancelAutoPlay(trigger: 'open_recommendation', reason: 'detail_open');
    try {
      await openComicDetail(
        context,
        comic: entry.comic,
        heroTag: heroTag,
        pageBuilder: widget.comicDetailPageBuilder,
      );
    } finally {
      final keepDetailOpen =
          useWindowsComicDetailPanel &&
          WindowsComicDetailController.instance.isOpen;
      if (!keepDetailOpen && mounted) {
        setState(() {
          _detailOpen = false;
        });
        _logCarouselEvent(
          'Discover carousel recommendation closed',
          content: {
            'heroTag': heroTag,
            'logicalPage': _currentPage,
            'comicId': entry.comic.id,
          },
        );
        _syncOverlayHeroTagWithRoute();
        _startAutoPlay(trigger: 'detail_closed');
      } else if (!keepDetailOpen) {
        _detailOpen = false;
      }
    }
  }

  void _handleWindowsDetailControllerChanged() {
    final controller = WindowsComicDetailController.instance;
    final panelOpen = controller.isOpen;
    final closedHeroTag = !panelOpen ? _activeOverlayHeroTag : null;
    if (_detailOpen == panelOpen &&
        (panelOpen || _activeOverlayHeroTag == null)) {
      return;
    }
    if (!mounted) {
      _detailOpen = panelOpen;
      if (!panelOpen) {
        _scheduleOverlayReveal(
          delay: windowsComicDetailPanelAnimationDuration,
          trigger: 'windows_detail_closed',
        );
      }
      return;
    }
    if (panelOpen) {
      _overlayRevealTimer?.cancel();
    }
    setState(() {
      _detailOpen = panelOpen;
    });
    if (!panelOpen) {
      _scheduleOverlayReveal(
        delay: windowsComicDetailPanelAnimationDuration,
        trigger: 'windows_detail_closed',
      );
      _logCarouselEvent(
        'Discover carousel recommendation closed',
        content: {'heroTag': closedHeroTag, 'logicalPage': _currentPage},
      );
      _startAutoPlay(trigger: 'windows_detail_closed');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recommendationCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _heroCardHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final heroCardWidth = math
                  .min(_heroCardMaxWidth, math.max(availableWidth - 56, 220))
                  .toDouble();
              final pageExtent = math.min(
                availableWidth,
                heroCardWidth + _itemSpacing,
              );
              final viewportFraction = availableWidth <= 0
                  ? 1.0
                  : (pageExtent / availableWidth).clamp(0.01, 1.0).toDouble();
              final coverCacheWidth =
                  heroCardWidth * MediaQuery.devicePixelRatioOf(context);

              _lastHeroCardWidth = heroCardWidth;
              _lastPageExtent = pageExtent;
              _lastViewportWidth = availableWidth;

              if (_hasPendingRecommendations && !_usingMixedSnapshots) {
                _schedulePendingActivation(trigger: 'layout_ready');
              }

              if ((_pageController.viewportFraction - viewportFraction).abs() >
                  0.001) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  final currentPage = _pageController.hasClients
                      ? (_pageController.page?.round() ??
                            _physicalPageForLogical(_currentPage))
                      : _physicalPageForLogical(_currentPage);
                  _pageController.dispose();
                  _pageController = PageController(
                    initialPage: currentPage,
                    viewportFraction: viewportFraction,
                  );
                  _scheduleProtectedItemRelease(trigger: 'controller_rebuilt');
                  _logCarouselEvent(
                    'Discover carousel controller rebuilt',
                    content: {
                      'physicalPage': currentPage,
                      'viewportFraction': _roundTo(viewportFraction, 3),
                      'availableWidth': availableWidth.round(),
                      'heroCardWidth': heroCardWidth.round(),
                      'pageExtent': pageExtent.round(),
                    },
                  );
                  if (mounted) {
                    setState(() {});
                  }
                });
              }

              return MouseRegion(
                onEnter: (_) {
                  if (_isHovered) {
                    return;
                  }
                  setState(() {
                    _isHovered = true;
                  });
                  _logCarouselEvent('Discover carousel hover entered');
                  _cancelAutoPlay(trigger: 'hover_enter', reason: 'hovered');
                },
                onExit: (_) {
                  if (!_isHovered) {
                    return;
                  }
                  setState(() {
                    _isHovered = false;
                  });
                  _logCarouselEvent('Discover carousel hover exited');
                  _startAutoPlay(trigger: 'hover_exit');
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: PageView.builder(
                    key: const ValueKey(
                      'discover_daily_recommendation_page_view',
                    ),
                    controller: _pageController,
                    clipBehavior: Clip.none,
                    padEnds: false,
                    physics: const _AnimekoCarouselPagePhysics(),
                    itemCount: _loopedItemCount,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      final effectiveIndex = _logicalPageForPhysical(index);
                      final entry = _resolvedRecommendationEntry(
                        effectiveIndex,
                      );
                      final heroTag = widget.comicCoverHeroTagBuilder(
                        entry.comic,
                        salt: 'discover-daily-$effectiveIndex',
                      );
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, _) {
                          final page = _pageController.hasClients
                              ? (_pageController.page ??
                                    _physicalPageForLogical(
                                      _currentPage,
                                    ).toDouble())
                              : _physicalPageForLogical(
                                  _currentPage,
                                ).toDouble();
                          final delta = index - page;
                          final metrics = _buildCardLayoutMetrics(
                            delta: delta,
                            heroCardWidth: heroCardWidth,
                            pageExtent: pageExtent,
                          );
                          final clippedWidth = metrics.clippedWidth(
                            heroCardWidth,
                          );
                          final shouldDeferLoading =
                              _isUserScrolling && delta.abs() > 1.35;
                          _reportCardLayout(
                            physicalIndex: index,
                            logicalIndex: effectiveIndex,
                            delta: delta,
                            clipScaleX: metrics.clipScaleX,
                            clippedWidth: clippedWidth,
                            outerTranslateX: metrics.outerTranslateX,
                            imageTranslateX: metrics.imageTranslateX,
                            cardOpacity: metrics.cardOpacity,
                            heroCardWidth: heroCardWidth,
                            pageExtent: pageExtent,
                          );

                          final imageChild = entry.comic.cover.trim().isEmpty
                              ? ColoredBox(color: placeholderColor)
                              : HazukiCachedImage(
                                  url: entry.comic.cover,
                                  fit: BoxFit.cover,
                                  cacheWidth: coverCacheWidth.round(),
                                  animateOnLoad: true,
                                  filterQuality: FilterQuality.low,
                                  deferLoadingWhileScrolling:
                                      shouldDeferLoading,
                                  loading: SizedBox.expand(
                                    child: ColoredBox(color: placeholderColor),
                                  ),
                                  error: ColoredBox(color: placeholderColor),
                                  onStateChanged: (url, state) {
                                    _reportImageState(
                                      physicalIndex: index,
                                      logicalIndex: effectiveIndex,
                                      heroTag: heroTag,
                                      imageUrl: url,
                                      state: state,
                                    );
                                  },
                                );

                          if (entry.comic.cover.trim().isNotEmpty) {
                            registerComicCoverHeroUrl(
                              heroTag,
                              entry.comic.cover,
                            );
                          }

                          return Transform.translate(
                            offset: Offset(metrics.outerTranslateX, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Opacity(
                                opacity: metrics.cardOpacity.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: metrics.cardScale,
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    key: ValueKey(
                                      'discover_daily_recommendation_card_$index',
                                    ),
                                    width: clippedWidth,
                                    height: _heroCardHeight,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(28),
                                        onTap: () => unawaited(
                                          _openRecommendation(
                                            context,
                                            entry,
                                            heroTag,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Hero(
                                                tag: heroTag,
                                                flightShuttleBuilder:
                                                    buildComicCoverHeroFlightShuttle,
                                                placeholderBuilder:
                                                    buildComicCoverHeroPlaceholder,
                                                child: OverflowBox(
                                                  alignment: Alignment.center,
                                                  minWidth: heroCardWidth,
                                                  maxWidth: heroCardWidth,
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      metrics.imageTranslateX,
                                                      0,
                                                    ),
                                                    child: SizedBox(
                                                      width: heroCardWidth,
                                                      height: _heroCardHeight,
                                                      child: imageChild,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _CarouselCardOverlay(
                                                entry: entry,
                                                isHidden:
                                                    _activeOverlayHeroTag ==
                                                    heroTag,
                                                heroTag: heroTag,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int index = 0; index < _recommendationCount; index++)
              AnimatedContainer(
                key: ValueKey('discover_daily_recommendation_indicator_$index'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: index == _currentPage ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AnimekoCarouselPagePhysics extends PageScrollPhysics {
  const _AnimekoCarouselPagePhysics({super.parent});

  static const SpringDescription _mediumSnapSpring = SpringDescription(
    mass: 1.0,
    stiffness: 1500,
    damping: 77.46,
  );

  @override
  _AnimekoCarouselPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _AnimekoCarouselPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => _mediumSnapSpring;
}

class _AnimekoEmphasizedCurve extends Curve {
  const _AnimekoEmphasizedCurve();

  static const Curve _segment1 = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve _segment2 = Cubic(0.05, 0.7, 0.1, 1.0);
  static const double _split = 0.166666;

  @override
  double transformInternal(double t) {
    if (t <= 0.0) {
      return 0.0;
    }
    if (t >= 1.0) {
      return 1.0;
    }
    if (t < _split) {
      final localT = t / _split;
      return _segment1.transform(localT) * 0.4;
    }
    final localT = (t - _split) / (1.0 - _split);
    return 0.4 + (_segment2.transform(localT) * 0.6);
  }
}

class _CarouselCardOverlay extends StatefulWidget {
  const _CarouselCardOverlay({
    required this.entry,
    required this.isHidden,
    required this.heroTag,
  });

  final DiscoverDailyRecommendationEntry entry;
  final bool isHidden;
  final String heroTag;

  @override
  State<_CarouselCardOverlay> createState() => _CarouselCardOverlayState();
}

class _CarouselCardOverlayState extends State<_CarouselCardOverlay> {
  static const Duration _overlayRevealDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisible = !widget.isHidden;
    final revealDuration = isVisible ? _overlayRevealDuration : Duration.zero;
    return AnimatedOpacity(
      key: ValueKey('discover_daily_recommendation_overlay_${widget.heroTag}'),
      opacity: isVisible ? 1.0 : 0.0,
      duration: revealDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 0.05),
        duration: revealDuration,
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.61),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.entry.comic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselCardLayoutMetrics {
  const _CarouselCardLayoutMetrics({
    required this.clipScaleX,
    required this.imageTranslateX,
    required this.cardScale,
    required this.cardOpacity,
    required this.outerTranslateX,
  });

  final double clipScaleX;
  final double imageTranslateX;
  final double cardScale;
  final double cardOpacity;
  final double outerTranslateX;

  double clippedWidth(double heroCardWidth) {
    return (heroCardWidth * clipScaleX).clamp(0.0, heroCardWidth);
  }

  double visibleWidth({
    required double heroCardWidth,
    required double viewportWidth,
  }) {
    final width = clippedWidth(heroCardWidth);
    if (width <= 0 || cardOpacity <= 0.001) {
      return 0;
    }
    final left = outerTranslateX;
    final right = left + width;
    final visibleLeft = math.max(0.0, left);
    final visibleRight = math.min(viewportWidth, right);
    return math.max(0.0, visibleRight - visibleLeft);
  }
}
