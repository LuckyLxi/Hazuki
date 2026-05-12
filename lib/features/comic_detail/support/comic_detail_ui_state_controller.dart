import 'package:flutter/material.dart';

import 'comic_detail_reveal_registry.dart';

class ComicDetailUiStateController extends ChangeNotifier {
  ComicDetailUiStateController({
    required String comicId,
    required bool? shouldAnimateInitialRevealOverride,
    required TickerProvider vsync,
    required ScrollController scrollController,
  }) : _comicId = comicId,
       _shouldAnimateInitialRevealOverride = shouldAnimateInitialRevealOverride,
       _vsync = vsync,
       _scrollController = scrollController;

  final String _comicId;
  final bool? _shouldAnimateInitialRevealOverride;
  final TickerProvider _vsync;
  final ScrollController _scrollController;

  bool _disposed = false;

  late final ValueNotifier<double> _appBarSolidProgressNotifier;
  late final ValueNotifier<bool> _collapsedTitleNotifier;
  late final TabController _tabController;
  late final bool _shouldAnimateInitialDetailReveal;
  String _appBarComicTitle = '';
  String _appBarUpdateTime = '';
  int _lastTabIndex = 0;
  bool _isAnimatingCommentsFullscreen = false;
  bool _hasInfoEntranceAnimated = false;

  ValueNotifier<double> get appBarSolidProgressNotifier =>
      _appBarSolidProgressNotifier;
  ValueNotifier<bool> get collapsedTitleNotifier => _collapsedTitleNotifier;
  TabController get tabController => _tabController;
  bool get shouldAnimateInitialDetailReveal =>
      _shouldAnimateInitialDetailReveal;
  String get appBarComicTitle => _appBarComicTitle;
  String get appBarUpdateTime => _appBarUpdateTime;
  bool get hasInfoEntranceAnimated => _hasInfoEntranceAnimated;

  void initialize({required String initialAppBarTitle}) {
    _shouldAnimateInitialDetailReveal =
        _shouldAnimateInitialRevealOverride ??
        !wasComicDetailIdAnimated(_comicId.trim());
    _appBarSolidProgressNotifier = ValueNotifier<double>(0);
    _collapsedTitleNotifier = ValueNotifier<bool>(false);
    _tabController = TabController(length: 3, vsync: _vsync)
      ..addListener(_handleTabChanged);
    _appBarComicTitle = initialAppBarTitle;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        _updateAppBarSolidProgress();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController.removeListener(_handleScroll);
    _appBarSolidProgressNotifier.dispose();
    _collapsedTitleNotifier.dispose();
    super.dispose();
  }

  void updateAppBarMetadata({
    required String title,
    required String updateTime,
  }) {
    if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) return;
      _appBarComicTitle = title;
      _appBarUpdateTime = updateTime;
      notifyListeners();
    });
  }

  void markComicDetailRevealHandled(String resolvedId) {
    markComicDetailIdAnimated(_comicId.trim());
    markComicDetailIdAnimated(resolvedId.trim());
  }

  // Intentionally does NOT call notifyListeners(): matches the previous
  // local `_hasAnimated` field on InfoTab, which never drove a rebuild.
  void markInfoEntranceAnimated() {
    _hasInfoEntranceAnimated = true;
  }

  Future<void> ensureCommentsTabFullscreen() async {
    if (_disposed ||
        _tabController.index != 1 ||
        !_scrollController.hasClients ||
        _isAnimatingCommentsFullscreen) {
      return;
    }

    final position = _scrollController.position;
    final targetOffset = position.maxScrollExtent.clamp(0.0, double.infinity);
    final currentOffset = position.pixels.clamp(0.0, targetOffset);
    if (targetOffset <= 0 || currentOffset >= targetOffset - 1) return;

    _isAnimatingCommentsFullscreen = true;
    try {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAnimatingCommentsFullscreen = false;
    }
  }

  Map<String, Object?> buildCommentsTabDebugState() {
    final hasClients = _scrollController.hasClients;
    final position = hasClients ? _scrollController.position : null;
    return {
      'outerHasClients': hasClients,
      'outerPixels': position?.pixels.round(),
      'outerMinScrollExtent': position?.minScrollExtent.round(),
      'outerMaxScrollExtent': position?.maxScrollExtent.round(),
      'outerViewportDimension': position?.viewportDimension.round(),
      'outerAnimatingCommentsFullscreen': _isAnimatingCommentsFullscreen,
      'outerTabIndex': _tabController.index,
    };
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_lastTabIndex == nextIndex) return;
    _lastTabIndex = nextIndex;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleScroll() {
    _updateAppBarSolidProgress();
  }

  bool _updateAppBarSolidProgress() {
    if (!_scrollController.hasClients) return false;

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

    if (!progressChanged && !titleChanged) return false;

    if (progressChanged) _appBarSolidProgressNotifier.value = nextProgress;
    if (titleChanged) _collapsedTitleNotifier.value = titleCollapsed;
    return true;
  }
}
