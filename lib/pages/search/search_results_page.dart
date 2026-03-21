part of '../../main.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.initialKeyword,
    this.initialOrder = 'mr',
  });

  final String initialKeyword;
  final String initialOrder;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _collapsedSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _collapsedSearchFocusNode = FocusNode();

  String _searchKeyword = '';
  String? _searchErrorMessage;
  List<ExploreComic> _searchComics = const [];
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _searchHasMore = true;
  bool _showBackToTop = false;
  int _searchPage = 1;
  int? _searchMaxPage;
  int _searchRequestToken = 0;
  String _searchOrder = 'mr';
  double _searchRevealProgress = 0;
  bool _collapsedSearchExpanded = false;
  double _lastViewInsetsBottom = 0;
  bool _awaitingCollapsedSearchFocus = false;
  bool _flyingSearchToTop = false;
  final GlobalKey _collapsedSearchKey = GlobalKey();
  AnimationController? _flyController;
  OverlayEntry? _flyOverlay;

  bool get _showCollapsedSearch => _searchRevealProgress >= 0.94;

  @override
  void initState() {
    super.initState();
    _searchOrder = _searchOrderLabels.containsKey(widget.initialOrder)
        ? widget.initialOrder
        : 'mr';
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchFocusNode.removeListener(_onFocusChanged);
    _collapsedSearchFocusNode.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    _collapsedSearchController.dispose();
    _searchFocusNode.dispose();
    _collapsedSearchFocusNode.dispose();
    _flyController?.dispose();
    _flyOverlay?.remove();
    super.dispose();
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
      setState(() {
        _collapsedSearchExpanded = false;
      });
      return;
    }

    setState(() {});
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
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
      setState(() {
        _collapsedSearchExpanded = false;
      });
    }
  }

  void _expandCollapsedSearch() {
    if (!_showCollapsedSearch) {
      return;
    }
    setState(() {
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
    final nextReveal = (position.pixels / _searchAppBarRevealOffset).clamp(
      0.0,
      1.0,
    );
    final nextShowBackToTop = position.pixels > 520;
    final shouldLoadMore =
        position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent - 260;

    // 当折叠搜索框区域不再可见时（页面向上滚动），自动收起展开状态
    final nextShowCollapsed = nextReveal >= 0.94;
    if (!nextShowCollapsed && _collapsedSearchExpanded) {
      _collapsedSearchFocusNode.unfocus();
      _collapsedSearchExpanded = false;
      _awaitingCollapsedSearchFocus = false;
    }

    if ((nextReveal - _searchRevealProgress).abs() >= 0.01 ||
        nextShowBackToTop != _showBackToTop) {
      setState(() {
        _searchRevealProgress = nextReveal;
        _showBackToTop = nextShowBackToTop;
      });
    }

    if (shouldLoadMore) {
      unawaited(_loadMoreSearch());
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
    setState(() {
      _searchRequestToken++;
      _searchKeyword = '';
      _searchErrorMessage = null;
      _searchComics = const [];
      _searchLoading = false;
      _searchLoadingMore = false;
      _searchHasMore = true;
      _searchPage = 1;
      _searchMaxPage = null;
    });
    _searchFocusNode.requestFocus();
    if (_collapsedSearchExpanded) {
      setState(() {
        _collapsedSearchExpanded = false;
        _awaitingCollapsedSearchFocus = false;
      });
    }
  }

  void _onSearchOrderSelected(String order) {
    if (!_searchOrderLabels.containsKey(order) || order == _searchOrder) {
      return;
    }
    setState(() {
      _searchOrder = order;
    });
    if (_searchKeyword.isNotEmpty) {
      unawaited(_search(keyword: _searchKeyword, page: 1));
    }
  }

  String get _currentSearchOrderLabel =>
      _searchOrderLabels[_searchOrder] ?? '最新';

  Future<SearchComicsResult> _loadSearchPage({
    required String keyword,
    required int page,
    required String order,
  }) {
    return HazukiSourceService.instance
        .searchComics(keyword: keyword, page: page, order: order)
        .timeout(
          _searchLoadTimeout,
          onTimeout: () {
            throw Exception('搜索超时，请稍后重试');
          },
        );
  }

  Future<void> _search({
    required String keyword,
    required int page,
    bool append = false,
    bool silentRefresh = false,
  }) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }

    final requestToken = ++_searchRequestToken;
    final isLoadMore = append;

    setState(() {
      _searchKeyword = normalized;
      _searchErrorMessage = null;
      if (!isLoadMore && !silentRefresh) {
        _searchPage = 1;
        _searchMaxPage = null;
        _searchHasMore = true;
        _searchComics = const [];
      }
      if (isLoadMore) {
        _searchLoadingMore = true;
      } else if (!silentRefresh) {
        _searchLoading = true;
      }
    });

    try {
      final result = await _loadSearchPage(
        keyword: normalized,
        page: page,
        order: _searchOrder,
      );
      if (!mounted || requestToken != _searchRequestToken) {
        return;
      }

      setState(() {
        final previousCount = _searchComics.length;
        if (append) {
          final merged = <String, ExploreComic>{
            for (final comic in _searchComics)
              if (comic.id.isNotEmpty) comic.id: comic,
          };
          for (final comic in result.comics) {
            if (comic.id.isNotEmpty) {
              merged[comic.id] = comic;
            }
          }
          _searchComics = merged.values.toList();
        } else {
          _searchComics = result.comics;
        }
        _searchPage = page;
        _searchMaxPage = result.maxPage;
        final reachedMaxPage =
            result.maxPage != null && page >= result.maxPage!;
        final noNewItems = append && _searchComics.length == previousCount;
        _searchHasMore =
            !reachedMaxPage && result.comics.isNotEmpty && !noNewItems;
        _searchErrorMessage = null;
      });
    } catch (e) {
      if (!mounted || requestToken != _searchRequestToken) {
        return;
      }
      setState(() {
        _searchErrorMessage = '搜索失败：$e';
      });
    } finally {
      if (mounted && requestToken == _searchRequestToken) {
        setState(() {
          if (isLoadMore) {
            _searchLoadingMore = false;
          } else if (!silentRefresh) {
            _searchLoading = false;
          }
        });
      }
    }
  }

  Future<void> _loadMoreSearch() async {
    if (_searchKeyword.isEmpty ||
        _searchLoading ||
        _searchLoadingMore ||
        !_searchHasMore ||
        (_searchMaxPage != null && _searchPage >= _searchMaxPage!)) {
      return;
    }

    if (_searchComics.isEmpty) {
      return;
    }

    await _search(keyword: _searchKeyword, page: _searchPage + 1, append: true);
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
      final navigator = Navigator.of(context);
      final details = await HazukiSourceService.instance
          .loadComicDetails(comicId)
          .timeout(const Duration(seconds: 25));
      if (!mounted) {
        return true;
      }

      final comic = ExploreComic(
        id: details.id,
        title: details.title.trim().isEmpty ? keyword.trim() : details.title,
        subTitle: details.subTitle,
        cover: details.cover,
      );
      await _addSearchHistory(keyword);
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ComicDetailPage(
            comic: comic,
            heroTag: _comicCoverHeroTag(comic, salt: 'search-id-direct'),
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitSearch() async {
    final activeController = _collapsedSearchFocusNode.hasFocus
        ? _collapsedSearchController
        : _searchController;
    final keyword = await _normalizeSubmittedKeyword(
      activeController.text,
      controller: activeController,
    );

    _syncSearchText(keyword);

    // 从折叠搜索框提交时，收起搜索框并执行飞行动画
    final submittedFromCollapsed = _collapsedSearchExpanded;
    if (_collapsedSearchExpanded) {
      _collapsedSearchFocusNode.unfocus();
      _collapsedSearchExpanded = false;
      _awaitingCollapsedSearchFocus = false;
    }
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
    final requestToken = ++_searchRequestToken;

    if (idKeyword != null) {
      setState(() {
        _searchKeyword = keyword;
        _searchErrorMessage = null;
        _searchComics = const [];
        _searchLoading = true;
        _searchLoadingMore = false;
        _searchHasMore = true;
        _searchPage = 1;
        _searchMaxPage = null;
      });
    }

    final openedById = await _tryOpenComicDetailByKeywordId(keyword);
    if (!openedById) {
      await _addSearchHistory(keyword);
    }

    if (!mounted || requestToken != _searchRequestToken) {
      return;
    }

    if (openedById) {
      setState(() {
        _searchLoading = false;
      });
      return;
    }

    await _search(keyword: keyword, page: 1);
  }

  /// 执行从应用栏折叠搜索框到顶部搜索框的飞行动画
  void _animateSearchFlyToTop() {
    // 在 setState 重建之前获取折叠搜索框的屏幕位置
    final collapsedBox =
        _collapsedSearchKey.currentContext?.findRenderObject() as RenderBox?;
    if (collapsedBox == null || !collapsedBox.attached) {
      unawaited(_scrollToTop());
      return;
    }

    final startOffset = collapsedBox.localToGlobal(Offset.zero);
    final startSize = collapsedBox.size;

    // 计算目标位置（顶部搜索框在应用栏下方的位置）
    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = kToolbarHeight + mediaQuery.padding.top;
    const targetLeft = 16.0;
    final targetTop = appBarHeight + 14.0;
    final targetWidth = mediaQuery.size.width - 32.0;
    const targetHeight = 56.0;

    // 预先捕获主题信息，避免在 Overlay 中访问错误的 context
    final bgColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final searchText = _searchController.text;

    setState(() {
      _flyingSearchToTop = true;
    });

    // 初始化动画控制器
    _flyController?.dispose();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // 创建 Overlay 飞行动画
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

    // 同时滚动到顶部
    unawaited(_scrollToTop());

    // 开始飞行动画，完成后清理
    _flyController!.forward().then((_) {
      _flyOverlay?.remove();
      _flyOverlay = null;
      if (mounted) {
        setState(() {
          _flyingSearchToTop = false;
        });
      }
    });
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchRevealProgress);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: IgnorePointer(
        // 当顶部搜索框已滚出可见区域或飞行动画进行中时，禁用交互
        ignoring: _showCollapsedSearch || _flyingSearchToTop,
        child: Opacity(
          opacity: _flyingSearchToTop ? 0 : (1 - hideProgress),
          child: Transform.translate(
            offset: Offset(0, -10 * hideProgress),
            child: Transform.scale(
              scale: 1 - 0.04 * hideProgress,
              alignment: Alignment.topCenter,
              child: HeroMode(
                enabled: !_showCollapsedSearch,
                child: Hero(
                  tag: _discoverSearchHeroTag,
                  child: SizedBox(
                    height: 56,
                    child: SearchBar(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      hintText: '搜索漫画',
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 16),
                      ),
                      leading: const Icon(Icons.search),
                      trailing: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                                reverseCurve: Curves.easeInCubic,
                              ),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _searchController.text.isNotEmpty
                              ? IconButton(
                                  key: const ValueKey('results-clear'),
                                  tooltip: '清空',
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.close),
                                )
                              : IconButton(
                                  key: const ValueKey('results-submit'),
                                  tooltip: '搜索',
                                  onPressed: () => unawaited(_submitSearch()),
                                  icon: const Icon(Icons.arrow_forward),
                                ),
                        ),
                      ],
                      onSubmitted: (_) => unawaited(_submitSearch()),
                      onChanged: (value) {
                        _syncSearchText(value, updateExpanded: false);
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSearchBox() {
    final collapsedWidth = _collapsedSearchExpanded ? 320.0 : 180.0;

    return HeroMode(
      enabled: _showCollapsedSearch && !_collapsedSearchExpanded,
      child: Hero(
        tag: _discoverSearchHeroTag,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _showCollapsedSearch ? collapsedWidth : 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: _showCollapsedSearch
                    ? Offset.zero
                    : const Offset(-0.08, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: _showCollapsedSearch ? 1 : 0.94,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: (_showCollapsedSearch && !_flyingSearchToTop)
                        ? 1
                        : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showCollapsedSearch,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _expandCollapsedSearch,
                        child: SizedBox(
                          key: _collapsedSearchKey,
                          height: 40,
                          child: SearchBar(
                            focusNode: _collapsedSearchFocusNode,
                            controller: _collapsedSearchController,
                            hintText: '搜索漫画',
                            elevation: const WidgetStatePropertyAll(0),
                            backgroundColor: WidgetStatePropertyAll(
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 12),
                            ),
                            leading: const Icon(Icons.search, size: 18),
                            trailing: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutBack,
                                      reverseCurve: Curves.easeInCubic,
                                    ),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child:
                                    _collapsedSearchController.text.isNotEmpty
                                    ? IconButton(
                                        key: const ValueKey(
                                          'collapsed-results-clear',
                                        ),
                                        tooltip: '清空',
                                        onPressed: _clearSearch,
                                        icon: const Icon(Icons.close),
                                      )
                                    : IconButton(
                                        key: const ValueKey(
                                          'collapsed-results-submit',
                                        ),
                                        tooltip: '搜索',
                                        onPressed: () =>
                                            unawaited(_submitSearch()),
                                        icon: const Icon(Icons.arrow_forward),
                                      ),
                              ),
                            ],
                            onTap: _expandCollapsedSearch,
                            onSubmitted: (_) => unawaited(_submitSearch()),
                            onChanged: (value) {
                              _syncSearchText(value, updateCollapsed: false);
                              if (!_collapsedSearchExpanded) {
                                setState(() {
                                  _collapsedSearchExpanded = true;
                                });
                                return;
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultState() {
    if (_searchKeyword.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text('输入关键词开始搜索')),
      );
    }

    if (_searchLoading && _searchComics.isEmpty) {
      return const SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HazukiStickerLoadingIndicator(size: 120),
              SizedBox(height: 12),
              Text('正在搜索...'),
            ],
          ),
        ),
      );
    }

    if (_searchErrorMessage != null && _searchComics.isEmpty) {
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_searchErrorMessage!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(_submitSearch()),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchComics.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('什么也没搜到')));
    }

    return const SizedBox.shrink();
  }

  Widget _buildSearchComicItem(ExploreComic comic, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final heroTag = _comicCoverHeroTag(
            comic,
            salt: 'search-${_searchKeyword.trim()}-$index',
          );
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ComicDetailPage(comic: comic, heroTag: heroTag),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Hero(
                tag: _comicCoverHeroTag(
                  comic,
                  salt: 'search-${_searchKeyword.trim()}-$index',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: comic.cover.isEmpty
                      ? Container(
                          width: 72,
                          height: 102,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported_outlined),
                        )
                      : HazukiCachedImage(
                          url: comic.cover,
                          width: 72,
                          height: 102,
                          fit: BoxFit.cover,
                          loading: Container(
                            width: 72,
                            height: 102,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          error: Container(
                            width: 72,
                            height: 102,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (comic.subTitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        comic.subTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_collapsedSearchExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 先收起展开的搜索框，使 Hero 动画正常工作
        setState(() {
          _collapsedSearchExpanded = false;
          _awaitingCollapsedSearchFocus = false;
        });
        _collapsedSearchFocusNode.unfocus();
        // 延迟到下一帧执行返回，确保 Hero 动画生效
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: hazukiFrostedAppBar(
          context: context,
          titleSpacing: _collapsedSearchExpanded
              ? 8
              : NavigationToolbar.kMiddleSpacing,
          title: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: _collapsedSearchExpanded
                    ? const SizedBox(key: ValueKey('appbar-title-hidden'))
                    : const Text('搜索', key: ValueKey('appbar-title-search')),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: _showCollapsedSearch && !_collapsedSearchExpanded
                    ? 12
                    : 0,
              ),
              Flexible(child: _buildCollapsedSearchBox()),
            ],
          ),
          actions: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: _collapsedSearchExpanded
                  ? const SizedBox(
                      key: ValueKey('search-actions-hidden'),
                      width: 12,
                    )
                  : PopupMenuButton<String>(
                      key: const ValueKey('search-actions-sort'),
                      tooltip: '排序',
                      initialValue: _searchOrder,
                      onSelected: _onSearchOrderSelected,
                      itemBuilder: (context) => _searchOrderLabels.entries
                          .map(
                            (entry) => CheckedPopupMenuItem<String>(
                              value: entry.key,
                              checked: _searchOrder == entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.sort_rounded),
                            const SizedBox(width: 4),
                            Text(_currentSearchOrderLabel),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              itemCount: _searchComics.length + 3,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildTopSearchBox();
                }
                if (index == 1) {
                  final emptyState =
                      _searchComics.isEmpty ||
                      (_searchLoading && _searchComics.isEmpty) ||
                      (_searchErrorMessage != null && _searchComics.isEmpty);
                  if (emptyState || _searchKeyword.isEmpty) {
                    return _buildSearchResultState();
                  }
                  return const SizedBox(height: 4);
                }

                final resultIndex = index - 2;
                if (resultIndex < _searchComics.length) {
                  final comic = _searchComics[resultIndex];
                  return _buildSearchComicItem(comic, resultIndex);
                }

                if (resultIndex == _searchComics.length) {
                  if (_searchLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HazukiStickerLoadingIndicator(size: 72),
                            SizedBox(height: 8),
                            Text('加载中...'),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox(height: 8);
                }

                return const SizedBox.shrink();
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSlide(
                offset: _showBackToTop ? Offset.zero : const Offset(0, 0.24),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: _showBackToTop ? 1 : 0.86,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _showBackToTop ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showBackToTop,
                      child: FloatingActionButton.small(
                        heroTag: 'search_back_to_top',
                        onPressed: () => unawaited(_scrollToTop()),
                        child: const Icon(Icons.vertical_align_top_rounded),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
