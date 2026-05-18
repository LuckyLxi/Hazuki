import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/search_focus_coordinator.dart';
import '../state/search_results_controller.dart';
import '../support/search_shared.dart';
import 'search_bar_shell.dart';
import 'search_id_extract_pill.dart';
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

  final ScrollController _scrollController = ScrollController();

  bool _showBackToTop = false;
  bool _comicIdSearchEnhance = false;
  bool _pendingExtractedComicIdHide = false;
  String? _extractedComicId;

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
        listenable: Listenable.merge([_resultsController, _focusCoordinator]),
        builder: (context, _) => PopScope(
          canPop: true,
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
                      // 提前捕获，防止计时器并发时状态已为 null
                      final id = _extractedComicId;
                      if (id == null) return;
                      _pendingExtractedComicIdHide = false;
                      _focusCoordinator.syncText(id);
                      _hideExtractedComicId();
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
      sourceService: sl<HazukiSourceService>(),
      searchPageLoader: widget.searchPageLoader,
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _sourceService.addListener(_handleSourceChanged);
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
        _loadComicIdSearchEnhance().whenComplete(() {
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
    _sourceService.removeListener(_handleSourceChanged);
    // 页面退出时清除额外底部偏移，避免影响其他页面的提示药丸
    hazukiPromptPlacementController.setExtraBottomPadding(0);
    _scrollController.dispose();
    _resultsController.dispose();
    _focusCoordinator.dispose();
  }

  Future<void> _loadComicIdSearchEnhance() async {
    final enabled = await isComicIdSearchEnhanceEnabled();
    if (!mounted) {
      return;
    }
    _updateSearchResultsState(() {
      _comicIdSearchEnhance = enabled && _sourceService.isActiveJmSource;
      _extractedComicId = _extractComicIdFromFocusedInput(
        _focusCoordinator.text,
      );
    });
  }

  void _handleSourceChanged() {
    if (!mounted) {
      return;
    }
    _updateSearchResultsState(() {
      if (!_sourceService.isActiveJmSource) {
        _comicIdSearchEnhance = false;
        _extractedComicId = null;
        _syncPromptAnchor(false);
      }
    });
    if (_sourceService.isActiveJmSource) {
      unawaited(_loadComicIdSearchEnhance());
    }
  }

  bool get _searchInputFocused => _focusCoordinator.primaryFocusNode.hasFocus;

  String? _extractComicIdFromFocusedInput(String value) {
    if (!_comicIdSearchEnhance || !_searchInputFocused) {
      return null;
    }
    return extractBestComicId(value);
  }

  void _hideExtractedComicId() {
    _pendingExtractedComicIdHide = false;
    if (_extractedComicId == null) {
      _syncPromptAnchor(false);
      return;
    }
    _updateSearchResultsState(() => _extractedComicId = null);
    _syncPromptAnchor(false);
  }

  /// 同步提示药丸的底部偏移，避免被搜索 ID 药丸遮挡
  void _syncPromptAnchor(bool pillVisible) {
    // 药丸高度约 36px + 底部定位 12px，间距约 6px
    hazukiPromptPlacementController.setExtraBottomPadding(
      pillVisible ? 36.0 : 0.0,
    );
  }

  void _scheduleHideExtractedComicIdIfUnfocused() {
    if (_pendingExtractedComicIdHide) {
      return;
    }
    _pendingExtractedComicIdHide = true;
    // 延迟需大于 InkWell 的点击响应时间，避免药丸 onTap 前状态已被清空
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_pendingExtractedComicIdHide) {
        return;
      }
      _pendingExtractedComicIdHide = false;
      if (!_searchInputFocused) {
        _hideExtractedComicId();
      }
    });
  }

  void _syncExtractedComicIdWithFocus(String value) {
    _pendingExtractedComicIdHide = false;
    final id = _extractComicIdFromFocusedInput(value);
    if (id != _extractedComicId) {
      _updateSearchResultsState(() => _extractedComicId = id);
      _syncPromptAnchor(id != null);
    }
  }

  void _handleSearchFocusChanged() {
    if (_searchInputFocused) {
      _syncExtractedComicIdWithFocus(_focusCoordinator.text);
    } else {
      _scheduleHideExtractedComicIdIfUnfocused();
    }
  }

  void _handleMetricsChanged() {
    if (!mounted) {
      return;
    }
    final wasKeyboardVisible = _focusCoordinator.keyboardVisible;
    _focusCoordinator.syncKeyboardVisibility();
    if (wasKeyboardVisible && !_focusCoordinator.keyboardVisible) {
      _scheduleHideExtractedComicIdIfUnfocused();
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
    _hideExtractedComicId();
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
    _hideExtractedComicId();
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
      onTap: () => _syncExtractedComicIdWithFocus(controller.text),
      onClear: onClear,
      onSubmit: () => unawaited(_submitSearch()),
      onSubmitted: (value) => unawaited(_submitSearch(submittedText: value)),
      onChanged: onChanged,
    );
  }

  void _updateExtractedId(String value) {
    _syncExtractedComicIdWithFocus(value);
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
          _updateExtractedId(value);
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
        await _dismissSearchInputIfFocused();
        if (!mounted) {
          return;
        }
        if (_resultsController.canRetry) {
          _resultsController.logRuntimeRetryRequested('search_results_page');
        }
        await _resultsController.search(
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
    final orderLabels = searchOrderLabels(
      context,
      sourceKey: _sourceService.activeSourceKey,
    );
    return hazukiFrostedAppBar(
      context: context,
      enableBlur: false,
      title: _buildSearchResultsAppBarTitle(),
      actions: [
        PopupMenuButton<String>(
          tooltip: _currentSearchOrderLabel,
          onOpened: () {
            unawaited(_dismissSearchInputIfFocused());
          },
          onSelected: (order) {
            unawaited(_dismissSearchInputIfFocused());
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
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleSearchResultsScrollNotification,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            unawaited(() async {
                              await _dismissSearchInputIfFocused();
                              if (!mounted) {
                                return;
                              }
                              await _resultsController.search(
                                context,
                                keyword: _searchKeyword,
                                page: 1,
                              );
                            }());
                          },
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
              onPressed: () {
                unawaited(() async {
                  await _dismissSearchInputIfFocused();
                  if (!mounted) {
                    return;
                  }
                  await _scrollToTop();
                }());
              },
              child: const Icon(Icons.keyboard_arrow_up),
            ),
          ),
        ),
      ),
    );
  }
}
