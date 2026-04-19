part of 'search_results_page.dart';

extension _SearchResultsLifecycleActionsExtension on _SearchResultsPageState {
  void _initializeSearchResultsPage() {
    _resultsController = SearchResultsController(
      initialOrder: widget.initialOrder,
      searchPageLoader: widget.searchPageLoader,
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusCoordinator.syncKeyboardVisibility();
      _focusCoordinator.attachRouteAutoFocus(
        context,
        showKeyboard: _showKeyboardOnEnter,
      );
      unawaited(_submitSearch());
    });
  }

  void _disposeSearchResultsPage() {
    _scrollController.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _resultsController.dispose();
    _focusCoordinator.dispose();
    _flyController?.dispose();
    _flyOverlay?.remove();
  }

  void _handleMetricsChanged() {
    if (!mounted) {
      return;
    }
    _focusCoordinator.syncKeyboardVisibility();
  }

  Future<void> _requestExpandedSearchFocus({bool showKeyboard = true}) {
    return _focusCoordinator.requestPrimarySearchFocus(
      context,
      showKeyboard: showKeyboard,
    );
  }

  void _expandCollapsedSearch() {
    if (!_showCollapsedSearch) {
      return;
    }
    _focusCoordinator.enterCollapsedMode(context);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final nextReveal = (position.pixels / searchAppBarRevealOffset).clamp(
      0.0,
      1.0,
    );
    final nextShowBackToTop = position.pixels > 520;
    final shouldLoadMore =
        position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 260;

    final nextShowCollapsed = nextReveal >= 0.94;
    if (!nextShowCollapsed && _focusCoordinator.collapsedSearchExpanded) {
      _focusCoordinator.exitCollapsedMode();
    }

    if ((nextReveal - _searchRevealProgress).abs() >= 0.01 ||
        nextShowBackToTop != _showBackToTop) {
      _updateSearchResultsState(() {
        _searchRevealProgress = nextReveal;
        _showBackToTop = nextShowBackToTop;
      });
    }

    if (shouldLoadMore) {
      unawaited(_resultsController.loadMoreSearch(context));
    }
  }

  Future<void> _scrollToTop({bool focusSearch = false}) async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (focusSearch && mounted) {
      await _requestExpandedSearchFocus();
    }
  }

  void _clearSearch() {
    _focusCoordinator.clearText();
    _resultsController.clearSearchData();
    unawaited(_requestExpandedSearchFocus());
    _focusCoordinator.exitCollapsedMode();
  }

  Future<void> _onSearchOrderSelected(String order) async {
    final orderLabels = searchOrderLabels(context);
    if (!orderLabels.containsKey(order) || order == _searchOrder) {
      return;
    }

    _focusCoordinator.exitCollapsedMode();

    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollToTop();
    }

    if (!mounted) {
      return;
    }

    _resultsController.setSearchOrder(order);
    if (_searchKeyword.isNotEmpty) {
      await _resultsController.search(
        context,
        keyword: _searchKeyword,
        page: 1,
      );
    }
  }

  String get _currentSearchOrderLabel {
    final strings = AppLocalizations.of(context)!;
    return searchOrderLabels(context)[_searchOrder] ??
        strings.searchOrderLatest;
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _focusCoordinator.exitCollapsedMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}
