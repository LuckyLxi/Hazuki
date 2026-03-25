part of '../../main.dart';

/// 专栏漫画列表页
/// 初始数据来自发现页预加载的 [section.comics]，
/// 若 [section.viewMoreUrl] 不为空则支持上滑分页继续加载
class DiscoverSectionPage extends StatefulWidget {
  const DiscoverSectionPage({super.key, required this.section});

  final ExploreSection section;

  @override
  State<DiscoverSectionPage> createState() => _DiscoverSectionPageState();
}

class _DiscoverSectionPageState extends State<DiscoverSectionPage> {
  final ScrollController _scrollController = ScrollController();

  /// 展示的漫画列表（初始包含发现页预加载数据）
  late final List<ExploreComic> _comics;

  bool _loadingMore = false;
  bool _hasMore = true;
  bool _showBackToTop = false;
  int _currentPage = 0;
  String? _errorMessage;

  List<CategoryRankingOption> _sortOptions = const <CategoryRankingOption>[];
  String? _selectedSortValue;
  bool _sortLoading = false;

  @override
  void initState() {
    super.initState();
    _comics = List<ExploreComic>.from(widget.section.comics);
    // 无 viewMoreUrl 则不支持分页
    if (widget.section.viewMoreUrl == null) {
      _hasMore = false;
    }
    _scrollController.addListener(_onScroll);
    unawaited(_loadSortOptions());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听：距底部 300px 时触发加载更多
  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final pos = _scrollController.position;
    final nextShowBackToTop = pos.pixels > 520;
    if (nextShowBackToTop != _showBackToTop && mounted) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }

    if (!_hasMore || _loadingMore) return;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      unawaited(_loadMore());
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadMore() async {
    final viewMoreUrl = widget.section.viewMoreUrl;
    if (viewMoreUrl == null || _loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
      _errorMessage = null;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await HazukiSourceService.instance
          .loadCategoryComicsByViewMore(
            viewMoreUrl: viewMoreUrl,
            page: nextPage,
            order: _selectedSortValue ?? 'mr',
          );

      if (!mounted) return;

      setState(() {
        if (nextPage == 1) {
          _comics
            ..clear()
            ..addAll(result.comics);
        } else {
          final existedIds = _comics.map((e) => e.id).toSet();
          final incoming = result.comics
              .where((e) => e.id.isEmpty || !existedIds.contains(e.id))
              .toList();
          _comics.addAll(incoming);
        }
        _currentPage = nextPage;
        // 没有更多数据 or 已达最大页
        // 注意：用原始返回数量判断是否还有下一页，避免因为去重后 incoming 为空而误判结束
        final maxPage = result.maxPage;
        _hasMore =
            result.comics.isNotEmpty && (maxPage == null || nextPage < maxPage);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n(context).discoverSectionLoadFailed('$e');
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadSortOptions() async {
    final viewMoreUrl = widget.section.viewMoreUrl;
    if (viewMoreUrl == null) {
      return;
    }

    setState(() {
      _sortLoading = true;
    });

    try {
      final options = await HazukiSourceService.instance
          .loadCategoryRankingOptionsByViewMore(viewMoreUrl: viewMoreUrl);
      if (!mounted) return;
      setState(() {
        _sortOptions = options;
        _selectedSortValue = options.isEmpty ? null : options.first.value;
      });
      // 排序选项准备好后，按当前排序刷新第一页
      setState(() {
        _comics.clear();
        _currentPage = 0;
        _hasMore = true;
        _errorMessage = null;
      });
      unawaited(_loadMore());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sortOptions = const <CategoryRankingOption>[];
        _selectedSortValue = 'mr';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sortLoading = false;
        });
      }
    }
  }

  void _onSelectSortOption(String value) {
    if (_selectedSortValue == value || _loadingMore) {
      return;
    }
    setState(() {
      _selectedSortValue = value;
      _errorMessage = null;
      _comics.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    unawaited(_loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(widget.section.title),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_sortLoading || _sortOptions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _sortLoading
                        ? const SizedBox(
                            height: 30,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final option in _sortOptions)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(option.label),
                                      selected:
                                          _selectedSortValue == option.value,
                                      onSelected: (_) =>
                                          _onSelectSortOption(option.value),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              Expanded(
                child: _comics.isEmpty
                    ? (_loadingMore || _sortLoading)
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const HazukiStickerLoadingIndicator(size: 72),
                                  const SizedBox(height: 10),
                                  Text(strings.commonLoading),
                                ],
                              ),
                            )
                          : Center(child: Text(strings.discoverSectionEmpty))
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        itemCount: _comics.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.57,
                            ),
                        itemBuilder: (context, index) {
                          final comic = _comics[index];
                          final heroTag = _comicCoverHeroTag(
                            comic,
                            salt:
                                'discover-more-${widget.section.title}-$index',
                          );
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ComicDetailPage(
                                    comic: comic,
                                    heroTag: heroTag,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Hero(
                                    tag: heroTag,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: comic.cover.isEmpty
                                          ? Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Center(
                                                child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                ),
                                              ),
                                            )
                                          : HazukiCachedImage(
                                              url: comic.cover,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              loading: Container(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                alignment: Alignment.center,
                                                child: const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                              error: Container(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  comic.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (comic.subTitle.isNotEmpty)
                                  Text(
                                    comic.subTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_loadingMore && _comics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HazukiStickerLoadingIndicator(size: 72),
                      const SizedBox(height: 8),
                      Text(strings.commonLoading),
                    ],
                  ),
                ),
            ],
          ),
          if (_errorMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _loadMore,
                          child: Text(strings.commonRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                    child: FloatingActionButton(
                      heroTag: 'discover_section_back_to_top',
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.vertical_align_top_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
