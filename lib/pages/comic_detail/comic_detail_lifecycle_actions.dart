part of '../comic_detail_page.dart';

extension _ComicDetailLifecycleActionsExtension on _ComicDetailPageState {
  void _initializeComicDetailPage() {
    _appBarScrollNotifier = ValueNotifier<_ComicDetailScrollState>(
      const _ComicDetailScrollState(),
    );
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    _appBarComicTitle = widget.comic.title;
    _future = HazukiSourceService.instance
        .loadComicDetails(widget.comic.id)
        .timeout(const Duration(seconds: 30));
    _scrollController.addListener(_handleScroll);
    unawaited(_warmupReaderImages());
    unawaited(_loadDynamicColorSetting());
    unawaited(_loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _updateAppBarSolidProgress();
    });
    unawaited(_recordHistory());

    // 记录打开漫画详情页事件
    HazukiSourceService.instance.addApplicationLog(
      level: 'info',
      title: 'ComicDetail opened',
      content: {
        'comicId': widget.comic.id,
        'title': widget.comic.title,
        'heroTag': widget.heroTag,
        'coverUrl': widget.comic.cover,
      },
      source: 'comic_detail',
    );
  }

  void _disposeComicDetailPage() {
    // 记录关闭漫画详情页事件（Hero 动画此时开始反向播放）
    HazukiSourceService.instance.addApplicationLog(
      level: 'info',
      title: 'ComicDetail disposed',
      content: {
        'comicId': widget.comic.id,
        'title': widget.comic.title,
        'heroTag': widget.heroTag,
        'mountedAtDispose': mounted,
      },
      source: 'comic_detail',
    );

    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _appBarScrollNotifier.dispose();
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
    const titleCollapseOffset = 186.0;

    final nextProgress = ((offset - fadeStart) / fadeDistance).clamp(0.0, 1.0);
    final titleCollapsed = offset >= titleCollapseOffset;

    final scrollState = _appBarScrollNotifier.value;
    final progressChanged =
        (scrollState.appBarSolidProgress - nextProgress).abs() >= 0.02;
    final titleChanged = titleCollapsed != scrollState.showCollapsedComicTitle;

    if (!progressChanged && !titleChanged) {
      return false;
    }

    _appBarScrollNotifier.value = scrollState.copyWith(
      appBarSolidProgress: nextProgress,
      showCollapsedComicTitle: titleCollapsed,
    );
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
}
