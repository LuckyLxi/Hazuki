import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/discover_daily_recommendation_service.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import '../search/search.dart';
import 'discover_section_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.comicDetailPageBuilder,
    this.usePinnedSearchInAppBar = false,
    this.dailyRecommendations = const <DiscoverDailyRecommendationEntry>[],
    this.onSearchMorphProgressChanged,
    this.onSearchTap,
    this.allowInitialLoad = true,
    this.hideLoadingUntilInitialLoadAllowed = false,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final bool usePinnedSearchInAppBar;
  final List<DiscoverDailyRecommendationEntry> dailyRecommendations;
  final ValueChanged<double>? onSearchMorphProgressChanged;
  final VoidCallback? onSearchTap;
  final bool allowInitialLoad;
  final bool hideLoadingUntilInitialLoadAllowed;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _discoverLoadTimeout = Duration(seconds: 20);
  static const _searchMorphDistance = kToolbarHeight;
  static const _initialVisibleSectionCount = 1;
  static const _sectionRevealBatchSize = 1;

  final ScrollController _scrollController = ScrollController();

  List<ExploreSection> _sections = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _refreshing = false;
  double _searchMorphProgress = 0;
  int _visibleSectionCount = 0;
  int _sectionRevealGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onSearchMorphProgressChanged?.call(_effectiveSearchMorphProgress);
    });
    if (widget.allowInitialLoad) {
      unawaited(_loadInitial());
    }
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onSearchMorphProgressChanged !=
        widget.onSearchMorphProgressChanged) {
      widget.onSearchMorphProgressChanged?.call(_effectiveSearchMorphProgress);
    }
    if (oldWidget.usePinnedSearchInAppBar != widget.usePinnedSearchInAppBar) {
      widget.onSearchMorphProgressChanged?.call(_effectiveSearchMorphProgress);
    }
    if (!oldWidget.allowInitialLoad &&
        widget.allowInitialLoad &&
        _initialLoading) {
      unawaited(_loadInitial());
    }
  }

  @override
  void dispose() {
    _sectionRevealGeneration++;
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _scheduleRemainingSectionReveal(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _sectionRevealGeneration) {
        return;
      }
      if (_visibleSectionCount >= _sections.length) {
        return;
      }

      setState(() {
        _visibleSectionCount = math.min(
          _visibleSectionCount + _sectionRevealBatchSize,
          _sections.length,
        );
      });

      if (_visibleSectionCount < _sections.length) {
        _scheduleRemainingSectionReveal(generation);
      }
    });
  }

  void _handleScroll() {
    if (widget.usePinnedSearchInAppBar) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    final pixels = _scrollController.position.pixels.clamp(
      0.0,
      double.infinity,
    );
    final progress = (pixels / _searchMorphDistance).clamp(0.0, 1.0);
    if ((progress - _searchMorphProgress).abs() < 0.001) {
      return;
    }
    setState(() {
      _searchMorphProgress = progress;
    });
    widget.onSearchMorphProgressChanged?.call(progress);
  }

  double get _effectiveSearchMorphProgress =>
      widget.usePinnedSearchInAppBar ? 1 : _searchMorphProgress;

  Future<List<ExploreSection>> _loadSections({bool forceRefresh = false}) {
    return HazukiSourceService.instance
        .loadExploreSections(forceRefresh: forceRefresh)
        .timeout(
          _discoverLoadTimeout,
          onTimeout: () {
            throw Exception('discover_load_timeout');
          },
        );
  }

  Future<void> _loadInitial() async {
    final strings = AppLocalizations.of(context)!;
    List<ExploreSection>? loadedSections;
    String? errorMessage;
    try {
      loadedSections = await _loadSections();
    } catch (e) {
      errorMessage = e.toString().contains('discover_load_timeout')
          ? strings.discoverLoadTimeout
          : strings.discoverLoadFailed('$e');
    }

    if (!mounted) {
      return;
    }

    int? revealGeneration;
    setState(() {
      _sectionRevealGeneration++;
      if (loadedSections != null) {
        _sections = loadedSections;
        _errorMessage = null;
        _visibleSectionCount = math.min(
          _initialVisibleSectionCount,
          loadedSections.length,
        );
        if (_visibleSectionCount < loadedSections.length) {
          revealGeneration = _sectionRevealGeneration;
        }
      } else {
        _sections = const [];
        _errorMessage = errorMessage;
        _visibleSectionCount = 0;
      }
      _initialLoading = false;
    });

    if (revealGeneration != null) {
      _scheduleRemainingSectionReveal(revealGeneration!);
    }
  }

  Future<void> _refreshDiscover() async {
    if (_refreshing) {
      return;
    }
    if (HazukiSourceService.instance.sourceRuntimeState.canRetry) {
      HazukiSourceService.instance.logRuntimeRetryRequested('discover_page');
    }

    setState(() {
      _refreshing = true;
    });

    final strings = AppLocalizations.of(context)!;
    List<ExploreSection>? refreshedSections;
    String? errorMessage;
    try {
      refreshedSections = await _loadSections(forceRefresh: true);
    } catch (e) {
      errorMessage = e.toString().contains('discover_load_timeout')
          ? strings.discoverLoadTimeout
          : strings.discoverLoadFailed('$e');
    }

    if (!mounted) {
      return;
    }

    final revealProgressively = _sections.isEmpty;
    int? revealGeneration;
    setState(() {
      _sectionRevealGeneration++;
      if (refreshedSections != null) {
        _sections = refreshedSections;
        _errorMessage = null;
        _visibleSectionCount = revealProgressively
            ? math.min(_initialVisibleSectionCount, refreshedSections.length)
            : refreshedSections.length;
        if (_visibleSectionCount < refreshedSections.length) {
          revealGeneration = _sectionRevealGeneration;
        }
      } else {
        _errorMessage = errorMessage;
      }
      _refreshing = false;
    });

    if (revealGeneration != null) {
      _scheduleRemainingSectionReveal(revealGeneration!);
    }
  }

  void _openSearch() {
    if (widget.onSearchTap != null) {
      widget.onSearchTap!.call();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(
          initialKeyword: null,
          comicDetailPageBuilder: (comic, heroTag) =>
              widget.comicDetailPageBuilder(comic, heroTag),
          comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
        ),
      ),
    );
  }

  Widget _buildSearchBox({
    required double height,
    required double borderRadius,
    required double horizontalPadding,
    required VoidCallback? onTap,
    required bool heroEnabled,
    double opacity = 1,
  }) {
    return Opacity(
      opacity: opacity,
      child: HeroMode(
        enabled: heroEnabled,
        child: Hero(
          tag: discoverSearchHeroTag,
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onTap,
            child: IgnorePointer(
              child: SizedBox(
                height: height,
                child: SearchBar(
                  hintText: AppLocalizations.of(context)!.searchHint,
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: horizontalPadding),
                  ),
                  leading: const Icon(Icons.search),
                  trailing: const [Icon(Icons.arrow_forward)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchMorphProgress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: 1 - hideProgress,
        child: Transform.translate(
          offset: Offset(0, -10 * hideProgress),
          child: Transform.scale(
            scale: 1 - 0.04 * hideProgress,
            alignment: Alignment.topCenter,
            child: _buildSearchBox(
              height: 56,
              borderRadius: 16,
              horizontalPadding: 16,
              onTap: _searchMorphProgress >= 0.96 ? null : _openSearch,
              heroEnabled: _searchMorphProgress < 0.96,
            ),
          ),
        ),
      ),
    );
  }

  bool get _showRecommendationCarousel =>
      widget.usePinnedSearchInAppBar && widget.dailyRecommendations.isNotEmpty;

  int get _headerItemCount =>
      (widget.usePinnedSearchInAppBar ? 0 : 1) +
      (_showRecommendationCarousel ? 1 : 0);

  Widget _buildDailyRecommendationCarousel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _DiscoverDailyRecommendationCarousel(
        recommendations: widget.dailyRecommendations,
        comicDetailPageBuilder: widget.comicDetailPageBuilder,
        comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
      ),
    );
  }

  Widget _buildHeaderItem(int index) {
    var currentIndex = index;
    if (!widget.usePinnedSearchInAppBar) {
      if (currentIndex == 0) {
        return _buildTopSearchBox();
      }
      currentIndex -= 1;
    }
    if (_showRecommendationCarousel && currentIndex == 0) {
      return _buildDailyRecommendationCarousel();
    }
    return const SizedBox.shrink();
  }

  Widget _buildDiscoverStateView() {
    final strings = AppLocalizations.of(context)!;
    final sourceRuntimeState = HazukiSourceService.instance.sourceRuntimeState;
    final showBlockingLoading =
        _initialLoading || (_refreshing && _sections.isEmpty);
    late final Widget child;

    if (showBlockingLoading) {
      if (shouldShowSourceRuntimeStatusCard(sourceRuntimeState)) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('discover-source-runtime-loading'),
          state: sourceRuntimeState,
          minHeight: 360,
        );
      } else if (!widget.allowInitialLoad &&
          widget.hideLoadingUntilInitialLoadAllowed) {
        child = const SizedBox(
          key: ValueKey('discover-placeholder'),
          height: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('discover-loading'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HazukiSandyLoadingIndicator(size: 136),
                const SizedBox(height: 10),
                Text(strings.commonLoading),
              ],
            ),
          ),
        );
      }
    } else if (_errorMessage != null && _sections.isEmpty) {
      if (shouldShowSourceRuntimeStatusCard(
        sourceRuntimeState,
        fallbackError: _errorMessage,
      )) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('discover-source-runtime-error'),
          state: sourceRuntimeState,
          fallbackError: _errorMessage,
          onRetry: _refreshDiscover,
          minHeight: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('discover-error'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_errorMessage!, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _refreshDiscover,
                  child: Text(strings.commonRetry),
                ),
              ],
            ),
          ),
        );
      }
    } else if (_sections.isEmpty) {
      child = SizedBox(
        key: const ValueKey('discover-empty'),
        height: 220,
        child: Center(child: Text(strings.discoverEmpty)),
      );
    } else {
      child = const SizedBox(key: ValueKey('discover-hidden'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            ...<Widget?>[currentChild].whereType<Widget>(),
          ],
        );
      },
      child: child,
    );
  }

  Widget _buildDiscoverSection(ExploreSection section, int sectionIndex) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(section.title, style: theme.textTheme.titleMedium),
              ),
              if (section.comics.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscoverSectionPage(
                          section: section,
                          comicDetailPageBuilder: widget.comicDetailPageBuilder,
                          comicCoverHeroTagBuilder:
                              widget.comicCoverHeroTagBuilder,
                        ),
                      ),
                    );
                  },
                  child: Text(strings.discoverMore),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: ListView.separated(
              key: PageStorageKey<String>(
                'discover-section-$sectionIndex-${section.title}',
              ),
              scrollDirection: Axis.horizontal,
              itemCount: section.comics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comic = section.comics[index];
                final heroTag = widget.comicCoverHeroTagBuilder(
                  comic,
                  salt: 'discover-$sectionIndex-${section.title}-$index',
                );
                return SizedBox(
                  width: 130,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      unawaited(
                        openComicDetail(
                          context,
                          comic: comic,
                          heroTag: heroTag,
                          pageBuilder: widget.comicDetailPageBuilder,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              clipBehavior: Clip.hardEdge,
                              borderRadius: BorderRadius.circular(8),
                              child: comic.cover.isEmpty
                                  ? ColoredBox(
                                      color: placeholderColor,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                                    )
                                  : HazukiCachedImage(
                                      url: comic.cover,
                                      fit: BoxFit.cover,
                                      width: 130,
                                      cacheWidth: coverCacheWidth,
                                      animateOnLoad: true,
                                      filterQuality: FilterQuality.low,
                                      deferLoadingWhileScrolling: true,
                                      loading: SizedBox.expand(
                                        child: ColoredBox(
                                          color: placeholderColor,
                                        ),
                                      ),
                                      error: ColoredBox(
                                        color: placeholderColor,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          comic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (comic.subTitle.isNotEmpty)
                          Text(
                            comic.subTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HazukiSourceService.instance,
      builder: (context, _) {
        final visibleSectionCount = math.min(
          _visibleSectionCount,
          _sections.length,
        );
        final hasSections = visibleSectionCount > 0;

        return HazukiPullToRefresh(
          onRefresh: _refreshDiscover,
          edgeOffset: 56,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            itemCount: hasSections
                ? visibleSectionCount + _headerItemCount
                : _headerItemCount + 1,
            itemBuilder: (context, index) {
              if (index < _headerItemCount) {
                return _buildHeaderItem(index);
              }
              if (!hasSections) {
                return _buildDiscoverStateView();
              }
              final sectionIndex = index - _headerItemCount;
              return _buildDiscoverSection(
                _sections[sectionIndex],
                sectionIndex,
              );
            },
          ),
        );
      },
    );
  }
}

class _DiscoverDailyRecommendationCarousel extends StatefulWidget {
  const _DiscoverDailyRecommendationCarousel({
    required this.recommendations,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final List<DiscoverDailyRecommendationEntry> recommendations;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<_DiscoverDailyRecommendationCarousel> createState() =>
      _DiscoverDailyRecommendationCarouselState();
}

class _DiscoverDailyRecommendationCarouselState
    extends State<_DiscoverDailyRecommendationCarousel> {
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
  bool _isHovered = false;
  bool _isUserScrolling = false;
  bool _isNormalizingLoopBoundary = false;
  final Map<int, String> _reportedCardSnapshots = <int, String>{};
  final Map<int, String> _reportedImageStates = <int, String>{};

  bool get _isLooping => widget.recommendations.length > 1;

  int get _loopedItemCount => _isLooping
      ? widget.recommendations.length + 2
      : widget.recommendations.length;

  int get _initialPhysicalPage => _isLooping ? 1 : 0;

  int _physicalPageForLogical(int logicalPage) {
    if (!_isLooping) {
      return logicalPage;
    }
    return logicalPage + 1;
  }

  int _logicalPageForPhysical(int physicalPage) {
    if (widget.recommendations.isEmpty) {
      return 0;
    }
    if (!_isLooping) {
      return physicalPage.clamp(0, widget.recommendations.length - 1);
    }
    final normalized = (physicalPage - 1) % widget.recommendations.length;
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
    if (!mounted) {
      return;
    }
    if (widget.recommendations.isEmpty) {
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
            (page == 0 || page == widget.recommendations.length + 1),
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
    if (settledPage == 0) {
      _logCarouselEvent(
        'Discover carousel loop boundary detected',
        content: {
          'settledPhysicalPage': settledPage,
          'jumpTargetPhysicalPage': widget.recommendations.length,
          'settledLogicalPage': _logicalPageForPhysical(settledPage),
          'jumpTargetLogicalPage': _logicalPageForPhysical(
            widget.recommendations.length,
          ),
        },
      );
      _scheduleLoopBoundaryJump(widget.recommendations.length);
      return;
    }
    if (settledPage == widget.recommendations.length + 1) {
      _logCarouselEvent(
        'Discover carousel loop boundary detected',
        content: {
          'settledPhysicalPage': settledPage,
          'jumpTargetPhysicalPage': 1,
          'settledLogicalPage': _logicalPageForPhysical(settledPage),
          'jumpTargetLogicalPage': _logicalPageForPhysical(1),
        },
      );
      _scheduleLoopBoundaryJump(1);
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
        (physicalIndex == 0 ||
            physicalIndex == widget.recommendations.length + 1);
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
    _detailOpen = true;
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
        _detailOpen = false;
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
                        builder: (context, child) {
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
                            final revealProgress =
                                ((progress - trailingSmallRevealDelay) /
                                        (1.0 - trailingSmallRevealDelay))
                                    .clamp(0.0, 1.0);
                            clipScaleX = _lerp(
                              0.0,
                              narrowRatio,
                              revealProgress,
                            );
                            imageTranslateX = _lerp(
                              heroCardWidth * parallaxRatio,
                              0.0,
                              revealProgress,
                            );
                            cardScale = 1.0;
                            cardOpacity = clipScaleX <= 0.001 ? 0.0 : 1.0;
                            final currentX = _lerp(
                              availableWidth,
                              heroCardWidth + _itemSpacing,
                              revealProgress,
                            );
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
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: OverflowBox(
                                        alignment: Alignment.center,
                                        minWidth: heroCardWidth,
                                        maxWidth: heroCardWidth,
                                        child: Transform.translate(
                                          offset: Offset(imageTranslateX, 0),
                                          child: child,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: heroCardWidth,
                          height: _heroCardHeight,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () => unawaited(
                                _openRecommendation(context, entry, heroTag),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Hero(
                                    tag: heroTag,
                                    flightShuttleBuilder:
                                        buildComicCoverHeroFlightShuttle,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: entry.comic.cover.trim().isEmpty
                                          ? ColoredBox(color: placeholderColor)
                                          : HazukiCachedImage(
                                              url: entry.comic.cover,
                                              fit: BoxFit.cover,
                                              cacheWidth: coverCacheWidth
                                                  .round(),
                                              animateOnLoad: true,
                                              filterQuality: FilterQuality.low,
                                              deferLoadingWhileScrolling: true,
                                              loading: SizedBox.expand(
                                                child: ColoredBox(
                                                  color: placeholderColor,
                                                ),
                                              ),
                                              error: ColoredBox(
                                                color: placeholderColor,
                                              ),
                                              onStateChanged: (url, state) {
                                                _reportImageState(
                                                  physicalIndex: index,
                                                  logicalIndex: effectiveIndex,
                                                  heroTag: heroTag,
                                                  imageUrl: url,
                                                  state: state,
                                                );
                                              },
                                            ),
                                    ),
                                  ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.author,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.92,
                                                ),
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.comic.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
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
                          ),
                        ),
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
