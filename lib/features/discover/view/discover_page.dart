import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/navigation_tags.dart';

import '../state/discover_page_controller.dart';
import 'discover_daily_recommendation_carousel.dart';
import 'discover_page_body.dart';
import 'discover_page_sections.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.sourceService,
    required this.recommendationSource,
    required this.recommendationService,
    required this.comicDetailPageBuilder,
    this.usePinnedSearchInAppBar = false,
    this.dailyRecommendationState =
        const DiscoverDailyRecommendationState.disabled(),
    this.onSearchMorphProgressChanged,
    this.onSearchTap,
    this.searchPageBuilder,
    this.onRequestLogin,
    this.allowInitialLoad = true,
    this.hideLoadingUntilInitialLoadAllowed = false,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final SourceDiscoverGateway sourceService;
  final SourceRecommendationGateway recommendationSource;
  final DiscoverDailyRecommendationService recommendationService;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final bool usePinnedSearchInAppBar;
  final DiscoverDailyRecommendationState dailyRecommendationState;
  final ValueChanged<double>? onSearchMorphProgressChanged;
  final VoidCallback? onSearchTap;
  final WidgetBuilder? searchPageBuilder;
  final Future<void> Function()? onRequestLogin;
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
    _controller = DiscoverPageController(
      sourceService: widget.sourceService,
      // 源切换时后台触发刷新，重新加载当前源的发现页数据
      onSourceSwitched: () {
        if (mounted) {
          unawaited(_triggerRefresh());
        }
      },
    );
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
    final pageBuilder = widget.searchPageBuilder;
    if (pageBuilder == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: pageBuilder));
  }

  Future<void> _requestLogin() async {
    final requestLogin = widget.onRequestLogin;
    if (requestLogin == null) {
      return;
    }
    await requestLogin();
    if (!mounted || _controller.showLoginRequired) {
      return;
    }
    if (_controller.sections.isEmpty) {
      await _triggerRefresh();
    }
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
        sourceService: widget.recommendationSource,
        recommendationService: widget.recommendationService,
      ),
    );
  }

  Widget _buildHeaderItem(BuildContext context, int index) {
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
    return DiscoverPageBody(
      controller: _controller,
      scrollController: _scrollController,
      headerItemCount: _headerItemCount,
      headerItemBuilder: _buildHeaderItem,
      onRefresh: _triggerRefresh,
      onLoginPressed: widget.onRequestLogin == null
          ? null
          : () {
              unawaited(_requestLogin());
            },
      allowInitialLoad: widget.allowInitialLoad,
      hideLoadingUntilInitialLoadAllowed:
          widget.hideLoadingUntilInitialLoadAllowed,
      comicDetailPageBuilder: widget.comicDetailPageBuilder,
      comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
      sourceService: widget.sourceService,
    );
  }
}
