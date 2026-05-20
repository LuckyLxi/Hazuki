import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/search_focus_coordinator.dart';
import '../state/search_id_extract_controller.dart';
import '../state/search_results_controller.dart';
import '../support/search_shared.dart';
import 'search_bar_shell.dart';
import 'search_results_page_widgets.dart';
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
    with WidgetsBindingObserver {
  late final SearchResultsController _resultsController;
  late final SearchFocusCoordinator _focusCoordinator = SearchFocusCoordinator(
    isMounted: () => mounted,
    initialText: widget.initialKeyword,
  );
  final HazukiSourceService _sourceService = sl<HazukiSourceService>();
  late final SearchIdExtractController _idExtractController =
      SearchIdExtractController(
        sourceService: _sourceService,
        isMounted: () => mounted,
        isInputFocused: () => _searchInputFocused,
        currentText: () => _focusCoordinator.text,
      );

  final ScrollController _scrollController = ScrollController();

  bool _showBackToTop = false;

  String get _searchKeyword => _resultsController.searchKeyword;
  String? get _searchErrorMessage => _resultsController.searchErrorMessage;
  List<ExploreComic> get _searchComics => _resultsController.searchComics;
  bool get _searchLoading => _resultsController.searchLoading;
  bool get _searchLoadingMore => _resultsController.searchLoadingMore;
  String get _searchOrder => _resultsController.searchOrder;
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
        listenable: Listenable.merge([
          _resultsController,
          _focusCoordinator,
          _idExtractController,
        ]),
        builder: (context, _) => PopScope(
          canPop: true,
          onPopInvokedWithResult: _handlePopInvoked,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: _buildSearchResultsAppBar(),
            body: Stack(
              children: [
                _buildSearchResultsBody(),
                SearchResultsBackToTopButton(
                  visible: _showBackToTop,
                  onPressed: _handleBackToTopPressed,
                ),
                SearchResultsIdExtractPill(
                  extractedId: _idExtractController.extractedId,
                  onApply: _applyExtractedComicId,
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
      sourceService: sl<HazukiSourceService>(),
      searchPageLoader: widget.searchPageLoader,
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _focusCoordinator.primaryFocusNode.addListener(_handleSearchFocusChanged);

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
      unawaited(
        _idExtractController.load().whenComplete(() {
          if (mounted) {
            unawaited(_submitSearch());
          }
        }),
      );
    });
  }

  void _disposeSearchResultsPage() {
    _focusCoordinator.primaryFocusNode.removeListener(
      _handleSearchFocusChanged,
    );
    _scrollController.removeListener(_onScroll);
    WidgetsBinding.instance.removeObserver(this);
    _idExtractController.dispose();
    _scrollController.dispose();
    _resultsController.dispose();
    _focusCoordinator.dispose();
  }

  bool get _searchInputFocused => _focusCoordinator.primaryFocusNode.hasFocus;

  void _handleSearchFocusChanged() {
    if (_searchInputFocused) {
      _idExtractController.syncWithFocus(_focusCoordinator.text);
    } else {
      _idExtractController.scheduleHideIfUnfocused();
    }
  }

  void _handleMetricsChanged() {
    if (!mounted) {
      return;
    }
    final wasKeyboardVisible = _focusCoordinator.keyboardVisible;
    _focusCoordinator.syncKeyboardVisibility();
    if (wasKeyboardVisible && !_focusCoordinator.keyboardVisible) {
      _idExtractController.scheduleHideIfUnfocused();
    }
  }

  Future<void> _dismissSearchInputIfFocused() async {
    if (!_searchInputFocused && !_focusCoordinator.keyboardVisible) {
      return;
    }
    await _focusCoordinator.dismissKeyboard(context, parkOnPage: true);
  }

  bool _handleSearchResultsScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final isDragStart =
        notification is ScrollStartNotification &&
        notification.dragDetails != null;
    final isUserScroll =
        notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle;
    if (isDragStart || isUserScroll) {
      unawaited(_dismissSearchInputIfFocused());
    }
    return false;
  }

  Future<void> _requestSearchFocus({bool showKeyboard = true}) {
    return _focusCoordinator.requestPrimarySearchFocus(
      context,
      showKeyboard: showKeyboard,
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final nextShowBackToTop = position.pixels > 520;
    final shouldLoadMore =
        position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 260;

    if (nextShowBackToTop != _showBackToTop) {
      _updateSearchResultsState(() {
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
      await _requestSearchFocus();
    }
  }

  void _clearSearch() {
    _focusCoordinator.clearText();
    _idExtractController.hide();
    _resultsController.clearSearchData();
    unawaited(_requestSearchFocus());
  }

  Future<void> _onSearchOrderSelected(String order) async {
    final orderLabels = searchOrderLabels(
      context,
      sourceKey: _sourceService.activeSourceKey,
    );
    if (!orderLabels.containsKey(order) || order == _searchOrder) {
      return;
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
    return searchOrderLabels(
          context,
          sourceKey: _sourceService.activeSourceKey,
        )[_searchOrder] ??
        strings.searchOrderLatest;
  }

  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop) {
      unawaited(_focusCoordinator.dismissKeyboard(context));
      return;
    }
  }

  String? _normalizeComicIdKeyword(String keyword) {
    return normalizeDirectComicIdKeyword(keyword);
  }

  Future<bool> _tryOpenComicDetailByKeywordId(String keyword) async {
    if (!_sourceService.isActiveJmSource) {
      return false;
    }
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
    _idExtractController.hide();
    final activeController = _focusCoordinator.activeController;
    final rawKeyword = submittedText ?? activeController.text;
    _focusCoordinator.syncText(rawKeyword);
    final keyword = await normalizeSubmittedKeyword(
      rawKeyword,
      controller: activeController,
    );

    _focusCoordinator.syncText(keyword);

    if (!mounted) {
      return;
    }

    if (keyword.isEmpty) {
      _clearSearch();
      return;
    }

    final idKeyword = _sourceService.isActiveJmSource
        ? _normalizeComicIdKeyword(keyword)
        : null;
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
      onTap: () => _idExtractController.syncWithFocus(controller.text),
      onClear: onClear,
      onSubmit: () => unawaited(_submitSearch()),
      onSubmitted: (value) => unawaited(_submitSearch(submittedText: value)),
      onChanged: onChanged,
    );
  }

  Widget _buildSearchResultsAppBarTitle() {
    return Hero(
      tag: discoverSearchHeroTag,
      child: _buildSearchBar(
        key: const ValueKey('search-results-app-bar-search-bar'),
        controller: _focusCoordinator.primaryController,
        focusNode: _focusCoordinator.primaryFocusNode,
        clearKey: 'results-clear',
        submitKey: 'results-submit',
        compact: true,
        onClear: _clearSearch,
        onChanged: (value) {
          _focusCoordinator.syncText(value, updatePrimary: false);
          _idExtractController.syncWithFocus(value);
        },
      ),
    );
  }

  Widget _buildSearchResultState() {
    return SearchResultsStateView(
      searchKeyword: _searchKeyword,
      searchLoading: _searchLoading,
      searchComics: _searchComics,
      searchErrorMessage: _searchErrorMessage,
      sourceRuntimeState: _resultsController.sourceRuntimeState,
      onRetry: () async {
        await _retrySearchFromCurrentKeyword();
      },
    );
  }

  Future<void> _retrySearchFromCurrentKeyword() async {
    await _dismissSearchInputIfFocused();
    if (!mounted) {
      return;
    }
    if (_resultsController.canRetry) {
      _resultsController.logRuntimeRetryRequested('search_results_page');
    }
    await _resultsController.search(context, keyword: _searchKeyword, page: 1);
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
        unawaited(() async {
          await _dismissSearchInputIfFocused();
          if (!mounted) {
            return;
          }
          await openComicDetail(
            context,
            comic: comic,
            heroTag: heroTag,
            pageBuilder: widget.comicDetailPageBuilder,
          );
        }());
      },
    );
  }

  PreferredSizeWidget _buildSearchResultsAppBar() {
    return SearchResultsAppBar(
      title: _buildSearchResultsAppBarTitle(),
      orderLabels: searchOrderLabels(
        context,
        sourceKey: _sourceService.activeSourceKey,
      ),
      currentOrderLabel: _currentSearchOrderLabel,
      searchOrder: _searchOrder,
      onOrderMenuOpened: () {
        unawaited(_dismissSearchInputIfFocused());
      },
      onOrderSelected: (order) {
        unawaited(_dismissSearchInputIfFocused());
        unawaited(_onSearchOrderSelected(order));
      },
    );
  }

  Widget _buildSearchResultsBody() {
    return SearchResultsBody(
      scrollController: _scrollController,
      searchKeyword: _searchKeyword,
      searchComics: _searchComics,
      searchLoadingMore: _searchLoadingMore,
      searchErrorMessage: _searchErrorMessage,
      currentSearchOrderLabel: _currentSearchOrderLabel,
      resultState: _buildSearchResultState(),
      onRefresh: _refreshSearchResults,
      onScrollNotification: _handleSearchResultsScrollNotification,
      itemBuilder: _buildSearchComicItem,
      onRetryPartialError: _retrySearchFromCurrentKeyword,
    );
  }

  Future<void> _refreshSearchResults() async {
    await _dismissSearchInputIfFocused();
    if (!mounted) {
      return;
    }
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
  }

  void _handleBackToTopPressed() {
    unawaited(() async {
      await _dismissSearchInputIfFocused();
      if (!mounted) {
        return;
      }
      await _scrollToTop();
    }());
  }

  void _applyExtractedComicId() {
    final id = _idExtractController.captureApplyId();
    if (id == null) return;
    _focusCoordinator.syncText(id);
    _idExtractController.hide();
    unawaited(_submitSearch(submittedText: id));
  }
}
