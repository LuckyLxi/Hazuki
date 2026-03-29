part of 'search_results_page.dart';

extension _SearchResultsLifecycleActionsExtension on _SearchResultsPageState {
  void _initializeSearchResultsPage() {
    _resultsController = SearchResultsController(
      initialOrder: widget.initialOrder,
    );
    _searchController.text = widget.initialKeyword;
    _collapsedSearchController.text = widget.initialKeyword;
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onFocusChanged);
    _collapsedSearchFocusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_submitSearch());
    });
  }

  void _disposeSearchResultsPage() {
    _scrollController.removeListener(_onScroll);
    _searchFocusNode.removeListener(_onFocusChanged);
    _collapsedSearchFocusNode.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    _collapsedSearchController.dispose();
    _searchFocusNode.dispose();
    _collapsedSearchFocusNode.dispose();
    _resultsController.dispose();
    _flyController?.dispose();
    _flyOverlay?.remove();
  }

  void _onFocusChanged() {
    if (!mounted) {
      return;
    }

    final collapsedHasFocus = _collapsedSearchFocusNode.hasFocus;
    final keyboardVisible = _lastViewInsetsBottom > 0;

    if (collapsedHasFocus && _awaitingCollapsedSearchFocus) {
      _awaitingCollapsedSearchFocus = false;
    }

    if (!collapsedHasFocus &&
        _collapsedSearchExpanded &&
        !keyboardVisible &&
        !_awaitingCollapsedSearchFocus) {
      _updateSearchResultsState(() {
        _collapsedSearchExpanded = false;
      });
      return;
    }

    _updateSearchResultsState(() {});
  }

  void _handleMetricsChanged() {
    if (!mounted) {
      return;
    }

    final viewInsetsBottom = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final keyboardJustClosed =
        _lastViewInsetsBottom > 0 && viewInsetsBottom <= 0;
    _lastViewInsetsBottom = viewInsetsBottom;

    if (viewInsetsBottom > 0 && _awaitingCollapsedSearchFocus) {
      _awaitingCollapsedSearchFocus = false;
    }

    if (keyboardJustClosed &&
        _collapsedSearchExpanded &&
        _collapsedSearchFocusNode.hasFocus) {
      _awaitingCollapsedSearchFocus = false;
      _collapsedSearchFocusNode.unfocus();
      _updateSearchResultsState(() {
        _collapsedSearchExpanded = false;
      });
    }
  }

  void _expandCollapsedSearch() {
    if (!_showCollapsedSearch) {
      return;
    }
    _updateSearchResultsState(() {
      _collapsedSearchExpanded = true;
      _awaitingCollapsedSearchFocus = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _collapsedSearchFocusNode.requestFocus();
    });
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
    if (!nextShowCollapsed && _collapsedSearchExpanded) {
      _collapsedSearchFocusNode.unfocus();
      _collapsedSearchExpanded = false;
      _awaitingCollapsedSearchFocus = false;
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
      _searchFocusNode.requestFocus();
    }
  }

  void _syncSearchText(
    String value, {
    bool updateExpanded = true,
    bool updateCollapsed = true,
  }) {
    if (updateExpanded && _searchController.text != value) {
      _searchController.value = _searchController.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
    if (updateCollapsed && _collapsedSearchController.text != value) {
      _collapsedSearchController.value = _collapsedSearchController.value
          .copyWith(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
            composing: TextRange.empty,
          );
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _collapsedSearchController.clear();
    _resultsController.clearSearchData();
    _searchFocusNode.requestFocus();
    if (_collapsedSearchExpanded) {
      _updateSearchResultsState(() {
        _collapsedSearchExpanded = false;
        _awaitingCollapsedSearchFocus = false;
      });
    }
  }

  Future<void> _onSearchOrderSelected(String order) async {
    final orderLabels = searchOrderLabels(context);
    if (!orderLabels.containsKey(order) || order == _searchOrder) {
      return;
    }

    if (_collapsedSearchExpanded) {
      _collapsedSearchFocusNode.unfocus();
      _updateSearchResultsState(() {
        _collapsedSearchExpanded = false;
        _awaitingCollapsedSearchFocus = false;
      });
    }

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
    _updateSearchResultsState(() {
      _collapsedSearchExpanded = false;
      _awaitingCollapsedSearchFocus = false;
    });
    _collapsedSearchFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}
