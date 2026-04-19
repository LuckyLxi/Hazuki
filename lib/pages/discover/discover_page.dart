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
import 'discover_daily_recommendation_carousel.dart';
import 'discover_page_sections.dart';

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

  bool get _showRecommendationCarousel =>
      widget.usePinnedSearchInAppBar && widget.dailyRecommendations.isNotEmpty;

  int get _headerItemCount =>
      (widget.usePinnedSearchInAppBar ? 0 : 1) +
      (_showRecommendationCarousel ? 1 : 0);

  Widget _buildDailyRecommendationCarousel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DiscoverDailyRecommendationCarousel(
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
        return DiscoverTopSearchBox(
          searchMorphProgress: _searchMorphProgress,
          onOpenSearch: _openSearch,
        );
      }
      currentIndex -= 1;
    }
    if (_showRecommendationCarousel && currentIndex == 0) {
      return _buildDailyRecommendationCarousel();
    }
    return const SizedBox.shrink();
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
                return DiscoverStateView(
                  initialLoading: _initialLoading,
                  refreshing: _refreshing,
                  sections: _sections,
                  errorMessage: _errorMessage,
                  allowInitialLoad: widget.allowInitialLoad,
                  hideLoadingUntilInitialLoadAllowed:
                      widget.hideLoadingUntilInitialLoadAllowed,
                  onRetry: _refreshDiscover,
                );
              }
              final sectionIndex = index - _headerItemCount;
              return DiscoverSectionBlock(
                section: _sections[sectionIndex],
                sectionIndex: sectionIndex,
                comicDetailPageBuilder: widget.comicDetailPageBuilder,
                comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
              );
            },
          ),
        );
      },
    );
  }
}
