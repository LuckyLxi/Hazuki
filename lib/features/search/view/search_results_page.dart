import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/search_focus_coordinator.dart';
import '../state/search_results_controller.dart';
import '../support/search_shared.dart';
import 'search_bar_shell.dart';
import 'search_id_extract_pill.dart';
import 'search_results_shell_widgets.dart';
import 'search_results_widgets.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.initialKeyword,
    this.initialOrder = 'mr',
    this.entryIntent = SearchEntryIntent.externalKeyword,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
    this.searchPageLoader,
  });

  final String initialKeyword;
  final String initialOrder;
  final SearchEntryIntent entryIntent;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final SearchPageLoader? searchPageLoader;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final SearchResultsController _resultsController;
  late final SearchFocusCoordinator _focusCoordinator = SearchFocusCoordinator(
    isMounted: () => mounted,
    initialText: widget.initialKeyword,
  );

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _collapsedSearchKey = GlobalKey();

  bool _showBackToTop = false;
  double _searchRevealProgress = 0;
  bool _flyingSearchToTop = false;
  String? _extractedComicId;
  AnimationController? _flyController;
  OverlayEntry? _flyOverlay;

  bool get _showCollapsedSearch => _searchRevealProgress >= 0.94;
  String get _searchKeyword => _resultsController.searchKeyword;
  String? get _searchErrorMessage => _resultsController.searchErrorMessage;
  List<ExploreComic> get _searchComics => _resultsController.searchComics;
  bool get _searchLoading => _resultsController.searchLoading;
  bool get _searchLoadingMore => _resultsController.searchLoadingMore;
  String get _searchOrder => _resultsController.searchOrder;
  bool get _collapsedSearchExpanded =>
      _focusCoordinator.collapsedSearchExpanded;
  bool get _showKeyboardOnEnter => widget.entryIntent.showKeyboardOnEnter;

  @override
  void initState() {
    super.initState();
    _initializeSearchResultsPage();
  }

  @override
  void dispose() {
    _disposeSearchResultsPage();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _handleMetricsChanged();
  }

  void _updateSearchResultsState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    return WindowsComicDetailHost(
      child: ListenableBuilder(
        listenable: Listenable.merge([_resultsController, _focusCoordinator]),
        builder: (context, _) => PopScope(
          canPop: !_focusCoordinator.collapsedSearchExpanded,
          onPopInvokedWithResult: _handlePopInvoked,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: _buildSearchResultsAppBar(),
            body: Stack(
              children: [
                _buildSearchResultsBody(),
                _buildSearchBackToTopButton(),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: SearchIdExtractPill(
                    extractedId: _extractedComicId,
                    onApply: () {
                      final id = _extractedComicId;
                      if (id == null) return;
                      _focusCoordinator.syncText(id);
                      _updateSearchResultsState(() => _extractedComicId = null);
                      unawaited(_submitSearch(submittedText: id));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        forceShowKeyboard: true,
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
    _updateSearchResultsState(() => _extractedComicId = null);
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

  String? _normalizeComicIdKeyword(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (RegExp(r'^\d{2,}$').hasMatch(normalized)) {
      return normalized;
    }
    if (RegExp(r'^jm\d{2,}$').hasMatch(normalized)) {
      return normalized;
    }
    return null;
  }

  Future<bool> _tryOpenComicDetailByKeywordId(String keyword) async {
    final comicId = _normalizeComicIdKeyword(keyword);
    if (comicId == null) {
      return false;
    }

    try {
      final details = await _resultsController.loadComicById(comicId);
      if (!mounted) {
        return true;
      }

      final comic = ExploreComic(
        id: details.id,
        title: details.title.trim().isEmpty ? keyword.trim() : details.title,
        subTitle: details.subTitle,
        cover: details.cover,
        sourceKey: details.sourceKey,
      );
      await addSearchHistory(keyword);
      if (!mounted) {
        return true;
      }
      await _focusCoordinator.dismissKeyboard(context);
      if (!mounted) {
        return true;
      }
      await openComicDetail(
        context,
        comic: comic,
        heroTag: widget.comicCoverHeroTagBuilder(
          comic,
          salt: 'search-id-direct',
        ),
        pageBuilder: widget.comicDetailPageBuilder,
        replaceCurrentRoute: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitSearch({String? submittedText}) async {
    final activeController = _focusCoordinator.activeController;
    final rawKeyword = submittedText ?? activeController.text;
    _focusCoordinator.syncText(rawKeyword);
    final keyword = await normalizeSubmittedKeyword(
      rawKeyword,
      controller: activeController,
    );

    _focusCoordinator.syncText(keyword);

    final submittedFromCollapsed = _focusCoordinator.collapsedSearchExpanded;
    _focusCoordinator.exitCollapsedMode();
    if (submittedFromCollapsed) {
      _animateSearchFlyToTop();
    }

    if (!mounted) {
      return;
    }

    if (keyword.isEmpty) {
      _clearSearch();
      return;
    }

    final idKeyword = _normalizeComicIdKeyword(keyword);
    final requestToken = idKeyword != null
        ? _resultsController.prepareDirectIdLookup(keyword)
        : -1;

    final openedById = await _tryOpenComicDetailByKeywordId(keyword);
    if (!openedById) {
      await addSearchHistory(keyword);
    }

    if (!mounted ||
        (requestToken != -1 &&
            !_resultsController.isCurrentRequest(requestToken))) {
      return;
    }

    if (openedById) {
      if (requestToken != -1) {
        _resultsController.finishDirectIdLookup(requestToken);
      }
      return;
    }

    await _resultsController.search(context, keyword: keyword, page: 1);
  }

  void _animateSearchFlyToTop() {
    final collapsedBox =
        _collapsedSearchKey.currentContext?.findRenderObject() as RenderBox?;
    if (collapsedBox == null || !collapsedBox.attached) {
      unawaited(_scrollToTop());
      return;
    }

    final startOffset = collapsedBox.localToGlobal(Offset.zero);
    final startSize = collapsedBox.size;

    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = kToolbarHeight + mediaQuery.padding.top;
    const targetLeft = 16.0;
    final targetTop = appBarHeight + 14.0;
    final targetWidth = mediaQuery.size.width - 32.0;
    const targetHeight = 56.0;

    final bgColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final searchText = _focusCoordinator.text;

    _updateSearchResultsState(() {
      _flyingSearchToTop = true;
    });

    _flyController?.dispose();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _flyOverlay?.remove();
    _flyOverlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _flyController!,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_flyController!.value);
          final left = lerpDouble(startOffset.dx, targetLeft, t)!;
          final top = lerpDouble(startOffset.dy, targetTop, t)!;
          final width = lerpDouble(startSize.width, targetWidth, t)!;
          final height = lerpDouble(startSize.height, targetHeight, t)!;
          final radius = lerpDouble(14, 16, t)!;
          final padding = lerpDouble(12, 16, t)!;
          final iconSize = lerpDouble(18, 24, t)!;

          return Positioned(
            left: left,
            top: top,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
                padding: EdgeInsets.symmetric(horizontal: padding),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.search, size: iconSize, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        searchText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    Overlay.of(context).insert(_flyOverlay!);
    unawaited(_scrollToTop());

    _flyController!.forward().then((_) {
      _flyOverlay?.remove();
      _flyOverlay = null;
      if (mounted) {
        _updateSearchResultsState(() {
          _flyingSearchToTop = false;
        });
      }
    });
  }

  Widget _buildSearchBar({
    Key? key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String clearKey,
    required String submitKey,
    required VoidCallback onClear,
    required ValueChanged<String> onChanged,
    bool compact = false,
  }) {
    return SearchBarShell(
      key: key,
      controller: controller,
      focusNode: focusNode,
      clearKey: clearKey,
      submitKey: submitKey,
      compact: compact,
      onClear: onClear,
      onSubmit: () => unawaited(_submitSearch()),
      onSubmitted: (value) => unawaited(_submitSearch(submittedText: value)),
      onChanged: onChanged,
    );
  }

  void _updateExtractedId(String value) {
    final id = extractBestComicId(value);
    if (id != _extractedComicId) {
      _updateSearchResultsState(() => _extractedComicId = id);
    }
  }

  Widget _buildTopSearchBox() {
    return SearchResultsTopSearchBox(
      revealProgress: _searchRevealProgress,
      showCollapsedSearch: _showCollapsedSearch,
      flyingSearchToTop: _flyingSearchToTop,
      searchBar: _buildSearchBar(
        key: const ValueKey('search-results-primary-search-bar'),
        controller: _focusCoordinator.primaryController,
        focusNode: _focusCoordinator.primaryFocusNode,
        clearKey: 'results-clear',
        submitKey: 'results-submit',
        onClear: _clearSearch,
        onChanged: (value) {
          _focusCoordinator.syncText(value, updatePrimary: false);
          _updateExtractedId(value);
        },
      ),
    );
  }

  Widget _buildSearchResultsAppBarTitle() {
    return SearchResultsAppBarTitle(
      showCollapsedSearch: _showCollapsedSearch,
      collapsedSearchExpanded: _collapsedSearchExpanded,
      flyingSearchToTop: _flyingSearchToTop,
      searchKeyword: _searchKeyword,
      collapsedSearchKey: _collapsedSearchKey,
      collapsedSearchBar: _buildSearchBar(
        key: const ValueKey('search-results-collapsed-search-bar'),
        controller: _focusCoordinator.collapsedController,
        focusNode: _focusCoordinator.collapsedFocusNode,
        clearKey: 'results-collapsed-clear',
        submitKey: 'results-collapsed-submit',
        compact: true,
        onClear: _clearSearch,
        onChanged: (value) {
          _focusCoordinator.syncText(value, updateCollapsed: false);
          _updateExtractedId(value);
        },
      ),
      onExpandCollapsedSearch: _expandCollapsedSearch,
    );
  }

  Widget _buildSearchResultState() {
    return SearchResultsStateView(
      searchKeyword: _searchKeyword,
      searchLoading: _searchLoading,
      searchComics: _searchComics,
      searchErrorMessage: _searchErrorMessage,
      sourceRuntimeState: _resultsController.sourceRuntimeState,
      onRetry: () {
        if (_resultsController.canRetry) {
          _resultsController.logRuntimeRetryRequested('search_results_page');
        }
        return _resultsController.search(
          context,
          keyword: _searchKeyword,
          page: 1,
        );
      },
    );
  }

  Widget _buildSearchComicItem(ExploreComic comic, int index) {
    final heroTag = widget.comicCoverHeroTagBuilder(
      comic,
      salt: 'search-results',
    );
    return SearchComicListItem(
      comic: comic,
      heroTag: heroTag,
      index: index,
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
    );
  }

  PreferredSizeWidget _buildSearchResultsAppBar() {
    final orderLabels = searchOrderLabels(context);
    return hazukiFrostedAppBar(
      context: context,
      enableBlur: false,
      title: _buildSearchResultsAppBarTitle(),
      actions: [
        PopupMenuButton<String>(
          tooltip: _currentSearchOrderLabel,
          onSelected: (order) {
            unawaited(_onSearchOrderSelected(order));
          },
          itemBuilder: (context) => [
            for (final entry in orderLabels.entries)
              PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Expanded(child: Text(entry.value)),
                    if (entry.key == _searchOrder)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSearchOrderLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.swap_vert, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsBody() {
    final strings = AppLocalizations.of(context)!;
    return HazukiPullToRefresh(
      onRefresh: () async {
        if (_searchKeyword.isEmpty) {
          await _submitSearch();
          return;
        }
        await _resultsController.search(
          context,
          keyword: _searchKeyword,
          page: 1,
          silentRefresh: _searchComics.isNotEmpty,
        );
      },
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _buildTopSearchBox(),
          const SizedBox(height: 6),
          if (_searchComics.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchKeyword,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _currentSearchOrderLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          _buildSearchResultState(),
          if (_searchComics.isNotEmpty) ...[
            for (int i = 0; i < _searchComics.length; i++)
              _buildSearchComicItem(_searchComics[i], i),
          ],
          if (_searchLoadingMore) const HazukiLoadMoreFooter(),
          if (_searchErrorMessage != null && _searchComics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchErrorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => unawaited(
                          _resultsController.search(
                            context,
                            keyword: _searchKeyword,
                            page: 1,
                          ),
                        ),
                        child: Text(strings.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(height: _searchLoadingMore ? 16 : 80),
        ],
      ),
    );
  }

  Widget _buildSearchBackToTopButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: IgnorePointer(
        ignoring: !_showBackToTop,
        child: AnimatedSlide(
          offset: _showBackToTop ? Offset.zero : const Offset(0, 1.2),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showBackToTop ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: FloatingActionButton(
              onPressed: () => unawaited(_scrollToTop()),
              child: const Icon(Icons.keyboard_arrow_up),
            ),
          ),
        ),
      ),
    );
  }
}
