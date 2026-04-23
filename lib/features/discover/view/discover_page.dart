import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/search/search.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../state/discover_page_controller.dart';
import 'discover_daily_recommendation_carousel.dart';
import 'discover_page_sections.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.comicDetailPageBuilder,
    this.usePinnedSearchInAppBar = false,
    this.dailyRecommendationState =
        const DiscoverDailyRecommendationState.disabled(),
    this.onSearchMorphProgressChanged,
    this.onSearchTap,
    this.allowInitialLoad = true,
    this.hideLoadingUntilInitialLoadAllowed = false,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final bool usePinnedSearchInAppBar;
  final DiscoverDailyRecommendationState dailyRecommendationState;
  final ValueChanged<double>? onSearchMorphProgressChanged;
  final VoidCallback? onSearchTap;
  final bool allowInitialLoad;
  final bool hideLoadingUntilInitialLoadAllowed;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _searchMorphDistance = kToolbarHeight;

  late final DiscoverPageController _controller;
  final ScrollController _scrollController = ScrollController();
  double _searchMorphProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverPageController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSearchMorphProgressChanged?.call(_effectiveSearchMorphProgress);
    });
    if (widget.allowInitialLoad) {
      unawaited(_triggerLoadInitial());
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
        _controller.initialLoading) {
      unawaited(_triggerLoadInitial());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _triggerLoadInitial() async {
    final strings = AppLocalizations.of(context)!;
    await _controller.loadInitial(
      timeoutMessage: strings.discoverLoadTimeout,
      loadFailedMessage: strings.discoverLoadFailed,
    );
  }

  Future<void> _triggerRefresh() async {
    final strings = AppLocalizations.of(context)!;
    await _controller.refresh(
      timeoutMessage: strings.discoverLoadTimeout,
      loadFailedMessage: strings.discoverLoadFailed,
    );
  }

  void _handleScroll() {
    if (widget.usePinnedSearchInAppBar) return;
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels.clamp(
      0.0,
      double.infinity,
    );
    final progress = (pixels / _searchMorphDistance).clamp(0.0, 1.0);
    if ((progress - _searchMorphProgress).abs() < 0.001) return;
    setState(() {
      _searchMorphProgress = progress;
    });
    widget.onSearchMorphProgressChanged?.call(progress);
  }

  double get _effectiveSearchMorphProgress =>
      widget.usePinnedSearchInAppBar ? 1 : _searchMorphProgress;

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
      widget.usePinnedSearchInAppBar &&
      widget.dailyRecommendationState.displayedRecommendations.isNotEmpty;

  int get _headerItemCount =>
      (widget.usePinnedSearchInAppBar ? 0 : 1) +
      (_showRecommendationCarousel ? 1 : 0);

  Widget _buildDailyRecommendationCarousel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DiscoverDailyRecommendationCarousel(
        displayedRecommendations:
            widget.dailyRecommendationState.displayedRecommendations,
        pendingRecommendations:
            widget.dailyRecommendationState.pendingRecommendations,
        isPendingReady: widget.dailyRecommendationState.isPendingReady,
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
      listenable: Listenable.merge([_controller, HazukiSourceService.instance]),
      builder: (context, _) {
        final visibleSectionCount = math.min(
          _controller.visibleSectionCount,
          _controller.sections.length,
        );
        final hasSections = visibleSectionCount > 0;

        return HazukiPullToRefresh(
          onRefresh: _triggerRefresh,
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
                  initialLoading: _controller.initialLoading,
                  refreshing: _controller.refreshing,
                  sections: _controller.sections,
                  errorMessage: _controller.errorMessage,
                  allowInitialLoad: widget.allowInitialLoad,
                  hideLoadingUntilInitialLoadAllowed:
                      widget.hideLoadingUntilInitialLoadAllowed,
                  onRetry: _triggerRefresh,
                );
              }
              final sectionIndex = index - _headerItemCount;
              return DiscoverSectionBlock(
                section: _controller.sections[sectionIndex],
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
