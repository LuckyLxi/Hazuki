part of '../comic_detail_page.dart';

extension _ComicDetailLifecycleActionsExtension on _ComicDetailPageState {
  void _initializeComicDetailPage() {
    _shouldAnimateInitialDetailReveal = !_ComicDetailPageState
        ._animatedComicDetailIds
        .contains(widget.comic.id.trim());
    _appBarSolidProgressNotifier = ValueNotifier<double>(0);
    _collapsedTitleNotifier = ValueNotifier<bool>(false);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    _appBarComicTitle = widget.comic.title;
    _future = HazukiSourceService.instance
        .loadComicDetails(widget.comic.id)
        .timeout(const Duration(seconds: 30));
    _scrollController.addListener(_handleScroll);
    unawaited(_warmupReaderImages());
    unawaited(_loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _updateAppBarSolidProgress();
    });
    unawaited(_recordHistory());
  }

  void _disposeComicDetailPage() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _appBarSolidProgressNotifier.dispose();
    _collapsedTitleNotifier.dispose();
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_lastTabIndex == nextIndex) {
      return;
    }
    _lastTabIndex = nextIndex;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleScroll() {
    _updateAppBarSolidProgress();
  }

  bool _updateAppBarSolidProgress() {
    if (!_scrollController.hasClients) {
      return false;
    }

    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    const fadeStart = 72.0;
    const fadeDistance = 132.0;
    const titleCollapseEnterOffset = 198.0;
    const titleCollapseExitOffset = 162.0;

    final nextProgress = ((offset - fadeStart) / fadeDistance).clamp(0.0, 1.0);
    final wasCollapsed = _collapsedTitleNotifier.value;
    final titleCollapsed = wasCollapsed
        ? offset >= titleCollapseExitOffset
        : offset >= titleCollapseEnterOffset;

    final progressChanged =
        (_appBarSolidProgressNotifier.value - nextProgress).abs() >= 0.02;
    final titleChanged = titleCollapsed != _collapsedTitleNotifier.value;

    if (!progressChanged && !titleChanged) {
      return false;
    }

    if (progressChanged) {
      _appBarSolidProgressNotifier.value = nextProgress;
    }
    if (titleChanged) {
      _collapsedTitleNotifier.value = titleCollapsed;
    }
    return true;
  }

  void _updateAppBarMetadata({
    required String title,
    required String updateTime,
  }) {
    if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) {
        return;
      }
      _updateComicDetailState(() {
        _appBarComicTitle = title;
        _appBarUpdateTime = updateTime;
      });
    });
  }

  void _markComicDetailRevealHandled(ComicDetailsData details) {
    final primaryId = widget.comic.id.trim();
    final resolvedId = details.id.trim();
    if (primaryId.isNotEmpty) {
      _ComicDetailPageState._animatedComicDetailIds.add(primaryId);
    }
    if (resolvedId.isNotEmpty) {
      _ComicDetailPageState._animatedComicDetailIds.add(resolvedId);
    }
  }
}
