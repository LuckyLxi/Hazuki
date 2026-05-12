import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../support/discover_daily_recommendation_carousel_support.dart';
import 'discover_daily_recommendation_carousel_controllers.dart';
import 'discover_daily_recommendation_carousel_widgets.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

part 'discover_daily_recommendation_carousel_detail.dart';
part 'discover_daily_recommendation_carousel_interaction.dart';
part 'discover_daily_recommendation_carousel_recommendations.dart';

class DiscoverDailyRecommendationCarousel extends StatefulWidget {
  const DiscoverDailyRecommendationCarousel({
    super.key,
    required this.displayedRecommendations,
    this.pendingRecommendations = const <DiscoverDailyRecommendationEntry>[],
    this.isPendingReady = false,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
    this.sourceService,
    this.recommendationService,
    this.windowsComicDetailController,
  });

  final List<DiscoverDailyRecommendationEntry> displayedRecommendations;
  final List<DiscoverDailyRecommendationEntry> pendingRecommendations;
  final bool isPendingReady;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final HazukiSourceService? sourceService;
  final DiscoverDailyRecommendationService? recommendationService;
  final WindowsComicDetailController? windowsComicDetailController;

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
  static const Curve _autoPlayCurve = DiscoverCarouselAutoPlayCurve();

  late final CarouselAutoPlayController _autoPlay;
  late final CarouselLoopPageController _loopController;
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

  DiscoverCarouselLoopMetrics get _loopMetrics =>
      DiscoverCarouselLoopMetrics(recommendationCount: _recommendationCount);

  int get _loopedItemCount => _loopMetrics.loopedItemCount;

  int get _initialPhysicalPage => _loopMetrics.initialPhysicalPage;

  int _physicalPageForLogical(int logicalPage) {
    return _loopMetrics.physicalPageForLogical(logicalPage);
  }

  int _logicalPageForPhysical(int physicalPage) {
    return _loopMetrics.logicalPageForPhysical(physicalPage);
  }

  int _normalizeLogicalPage(int logicalPage) {
    return _loopMetrics.normalizeLogicalPage(logicalPage);
  }

  PageController get _pageController => _loopController.pageController;

  HazukiSourceService get _sourceService =>
      widget.sourceService ?? sl<HazukiSourceService>();
  DiscoverDailyRecommendationService get _recommendationService =>
      widget.recommendationService ?? sl<DiscoverDailyRecommendationService>();
  WindowsComicDetailController get _windowsController =>
      widget.windowsComicDetailController ??
      WindowsComicDetailController.instance;

  void _setCarouselState(VoidCallback fn) {
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _autoPlay = CarouselAutoPlayController();
    _loopController = CarouselLoopPageController(
      onBoundaryJumpApplied: () =>
          _scheduleProtectedItemRelease(trigger: 'loop_boundary_jump'),
      onLog: (title, {content}) => _logCarouselEvent(title, content: content),
    );
    if (useWindowsComicDetailPanel) {
      _windowsController.addListener(_handleWindowsDetailControllerChanged);
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
    _loopController.initPageController(
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
    _autoPlay.dispose();
    _overlayRevealTimer?.cancel();
    _detachRouteAnimation();
    if (useWindowsComicDetailPanel) {
      _windowsController.removeListener(_handleWindowsDetailControllerChanged);
    }
    _logCarouselEvent(
      'Discover carousel disposed',
      content: {
        'reportedCardCount': _reportedCardSnapshots.length,
        'reportedImageCount': _reportedImageStates.length,
      },
    );
    _loopController.dispose();
    super.dispose();
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
                  _loopController.rebuildPageController(
                    currentPage: currentPage,
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
                    physics: const DiscoverCarouselPagePhysics(),
                    itemCount: _loopedItemCount,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      final effectiveIndex = _logicalPageForPhysical(index);
                      final entry = _resolvedRecommendationEntry(
                        effectiveIndex,
                      );
                      final heroTag = widget.comicCoverHeroTagBuilder(
                        entry.comic,
                        salt: '$discoverDailyHeroSaltPrefix$effectiveIndex',
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
                                  sourceKey: entry.comic.sourceKey,
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

                          return DiscoverDailyRecommendationCarouselCard(
                            physicalIndex: index,
                            entry: entry,
                            heroTag: heroTag,
                            heroCardWidth: heroCardWidth,
                            heroCardHeight: _heroCardHeight,
                            clippedWidth: clippedWidth,
                            outerTranslateX: metrics.outerTranslateX,
                            imageTranslateX: metrics.imageTranslateX,
                            cardScale: metrics.cardScale,
                            cardOpacity: metrics.cardOpacity,
                            hideOverlay: _activeOverlayHeroTag == heroTag,
                            imageChild: imageChild,
                            onTap: () => unawaited(
                              _openRecommendation(context, entry, heroTag),
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
        DiscoverDailyRecommendationIndicators(
          count: _recommendationCount,
          currentIndex: _currentPage,
        ),
      ],
    );
  }
}
