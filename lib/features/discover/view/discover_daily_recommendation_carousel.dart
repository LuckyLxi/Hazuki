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
    required this.recommendations,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final List<DiscoverDailyRecommendationEntry> recommendations;
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
  int _currentPage = 0;
  bool _detailOpen = false;
  String? _activeOverlayHeroTag;
  bool _isHovered = false;
  bool _isUserScrolling = false;
  bool _isNormalizingLoopBoundary = false;
  final Map<int, String> _reportedCardSnapshots = <int, String>{};
  final Map<int, String> _reportedImageStates = <int, String>{};

  bool get _isLooping => widget.recommendations.length > 1;

  int get _loopedItemCount => _isLooping
      ? widget.recommendations.length + 5
      : widget.recommendations.length;

  int get _initialPhysicalPage => _isLooping ? 2 : 0;

  int _physicalPageForLogical(int logicalPage) {
    if (!_isLooping) {
      return logicalPage;
    }
    return logicalPage + 2;
  }

  int _logicalPageForPhysical(int physicalPage) {
    if (widget.recommendations.isEmpty) {
      return 0;
    }
    if (!_isLooping) {
      return physicalPage.clamp(0, widget.recommendations.length - 1);
    }
    final normalized = (physicalPage - 2) % widget.recommendations.length;
    return normalized < 0
        ? normalized + widget.recommendations.length
        : normalized;
  }

  @override
  void initState() {
    super.initState();
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
    _startAutoPlay(trigger: 'init_state');
  }

  @override
  void dispose() {
    _cancelAutoPlay(trigger: 'dispose');
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
        'recommendationCount': widget.recommendations.length,
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
    if (!mounted || widget.recommendations.isEmpty) {
      return;
    }
    final nextLogicalPage = _logicalPageForPhysical(page);
    final previousLogicalPage = _currentPage;
    setState(() {
      _currentPage = nextLogicalPage;
    });
    _logCarouselEvent(
      'Discover carousel page changed',
      content: {
        'physicalPage': page,
        'fromLogicalPage': previousLogicalPage,
        'toLogicalPage': nextLogicalPage,
        'isLoopGhost':
            _isLooping &&
            (page <= 1 || page >= widget.recommendations.length + 2),
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
    final itemCount = widget.recommendations.length;
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
        (physicalIndex <= 1 ||
            physicalIndex >= widget.recommendations.length + 2);
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
      if (mounted) {
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
        _startAutoPlay(trigger: 'detail_closed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  : (pageExtent / availableWidth).clamp(0.74, 0.94).toDouble();
              final coverCacheWidth =
                  heroCardWidth * MediaQuery.devicePixelRatioOf(context);

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
                      final effectiveIndex = widget.recommendations.isEmpty
                          ? 0
                          : _logicalPageForPhysical(index);
                      final entry = widget.recommendations[effectiveIndex];
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
                            imageTranslateX =
                                heroCardWidth * parallaxRatio * progress;
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
                                  (progress - incomingExpansionHold) /
                                  (1.0 - incomingExpansionHold);
                              clipScaleX = 1.0;
                              desiredLeft = _lerp(lockedRightLeft, 0.0, phase);
                            }

                            imageTranslateX =
                                heroCardWidth *
                                parallaxRatio *
                                (1.0 - progress);
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
                                  (progress - incomingExpansionHold) /
                                  (1.0 - incomingExpansionHold);
                              index1ClipScaleX = 1.0;
                              index1DesiredLeft = _lerp(
                                lockedRightLeft,
                                0.0,
                                phase,
                              );
                            }

                            final index1ClippedWidth =
                                (heroCardWidth * index1ClipScaleX).clamp(
                                  0.0,
                                  heroCardWidth,
                                );
                            final index1RightEdge =
                                index1DesiredLeft + index1ClippedWidth;

                            final revealProgress =
                                ((progress - trailingSmallRevealDelay) /
                                        (1.0 - trailingSmallRevealDelay))
                                    .clamp(0.0, 1.0);
                            clipScaleX = _lerp(
                              0.0,
                              narrowRatio,
                              revealProgress,
                            );
                            imageTranslateX =
                                heroCardWidth * parallaxRatio * delta;
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

                          final clippedWidth = (heroCardWidth * clipScaleX)
                              .clamp(0.0, heroCardWidth);
                          _reportCardLayout(
                            physicalIndex: index,
                            logicalIndex: effectiveIndex,
                            delta: delta,
                            clipScaleX: clipScaleX,
                            clippedWidth: clippedWidth,
                            outerTranslateX: outerTranslateX,
                            imageTranslateX: imageTranslateX,
                            cardOpacity: cardOpacity,
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
                                  deferLoadingWhileScrolling: true,
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
                            offset: Offset(outerTranslateX, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Opacity(
                                opacity: cardOpacity.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: cardScale,
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
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
                                                      imageTranslateX,
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
                                                isActive:
                                                    _activeOverlayHeroTag ==
                                                    heroTag,
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
            for (int index = 0; index < widget.recommendations.length; index++)
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
  const _CarouselCardOverlay({required this.entry, required this.isActive});

  final DiscoverDailyRecommendationEntry entry;
  final bool isActive;

  @override
  State<_CarouselCardOverlay> createState() => _CarouselCardOverlayState();
}

class _CarouselCardOverlayState extends State<_CarouselCardOverlay> {
  bool _isVisible = true;
  Animation<double>? _secondaryAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final secondary = route?.secondaryAnimation;
    if (_secondaryAnimation != secondary) {
      _secondaryAnimation?.removeStatusListener(_onStatusChanged);
      _secondaryAnimation = secondary;
      _secondaryAnimation?.addStatusListener(_onStatusChanged);
    }
    _syncVisibilityWithRoute();
  }

  @override
  void didUpdateWidget(covariant _CarouselCardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncVisibilityWithActiveState();
    }
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (!widget.isActive) {
      return;
    }
    if (status == AnimationStatus.dismissed) {
      _updateVisibility(true);
      return;
    }
    _updateVisibility(false);
  }

  void _syncVisibilityWithActiveState() {
    if (!widget.isActive) {
      _updateVisibility(true);
      return;
    }
    // Active overlay stays hidden during the Hero flight and only reappears
    // after the pushed route is fully dismissed.
    _updateVisibility(false);
  }

  void _syncVisibilityWithRoute() {
    if (!widget.isActive) {
      _updateVisibility(true);
      return;
    }
    _updateVisibility(_secondaryAnimation?.status == AnimationStatus.dismissed);
  }

  void _updateVisibility(bool visible) {
    if (_isVisible == visible) {
      return;
    }
    setState(() {
      _isVisible = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revealDuration = _isVisible
        ? const Duration(milliseconds: 280)
        : Duration.zero;
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: revealDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _isVisible ? Offset.zero : const Offset(0, 0.05),
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
