part of '../../main.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    this.onSearchMorphProgressChanged,
    this.onSearchTap,
  });

  final ValueChanged<double>? onSearchMorphProgressChanged;
  final VoidCallback? onSearchTap;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _discoverLoadTimeout = Duration(seconds: 20);
  static const _searchMorphDistance = kToolbarHeight;

  final ScrollController _scrollController = ScrollController();

  List<ExploreSection> _sections = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _refreshing = false;
  double _searchMorphProgress = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onSearchMorphProgressChanged?.call(_searchMorphProgress);
    });
    unawaited(_loadInitial());
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onSearchMorphProgressChanged !=
        widget.onSearchMorphProgressChanged) {
      widget.onSearchMorphProgressChanged?.call(_searchMorphProgress);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final pixels = _scrollController.position.pixels.clamp(
      0.0,
      double.infinity,
    );
    final progress = (pixels / _searchMorphDistance).clamp(0.0, 1.0);
    if ((progress - _searchMorphProgress).abs() < 0.001) {
      return;
    }
    setState(() {
      _searchMorphProgress = progress;
    });
    widget.onSearchMorphProgressChanged?.call(progress);
  }

  Future<List<ExploreSection>> _loadSections({bool forceRefresh = false}) {
    return HazukiSourceService.instance
        .loadExploreSections(forceRefresh: forceRefresh)
        .timeout(
          _discoverLoadTimeout,
          onTimeout: () {
            throw Exception('发现页加载超时，请下拉重试');
          },
        );
  }

  Future<void> _loadInitial() async {
    try {
      final sections = await _loadSections();
      if (!mounted) {
        return;
      }
      setState(() {
        _sections = sections;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '发现页加载失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDiscover() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      final sections = await _loadSections(forceRefresh: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _sections = sections;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '发现页加载失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _openSearch() {
    if (widget.onSearchTap != null) {
      widget.onSearchTap!.call();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  Widget _buildSearchBox({
    required double height,
    required double borderRadius,
    required double horizontalPadding,
    required VoidCallback? onTap,
    required bool heroEnabled,
    double opacity = 1,
  }) {
    return Opacity(
      opacity: opacity,
      child: HeroMode(
        enabled: heroEnabled,
        child: Hero(
          tag: _discoverSearchHeroTag,
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onTap,
            child: IgnorePointer(
              child: SizedBox(
                height: height,
                child: SearchBar(
                  hintText: '搜索漫画',
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: horizontalPadding),
                  ),
                  leading: const Icon(Icons.search),
                  trailing: const [Icon(Icons.arrow_forward)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchMorphProgress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: 1 - hideProgress,
        child: Transform.translate(
          offset: Offset(0, -10 * hideProgress),
          child: Transform.scale(
            scale: 1 - 0.04 * hideProgress,
            alignment: Alignment.topCenter,
            child: _buildSearchBox(
              height: 56,
              borderRadius: 16,
              horizontalPadding: 16,
              onTap: _searchMorphProgress >= 0.96 ? null : _openSearch,
              heroEnabled: _searchMorphProgress < 0.96,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverView() {
    if (_initialLoading) {
      return const SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HazukiStickerLoadingIndicator(size: 112),
              SizedBox(height: 10),
              Text('加载中...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _sections.isEmpty) {
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refreshDiscover,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sections.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('当前漫画源暂无发现页内容')),
      );
    }

    return Column(
      children: [
        for (final section in _sections) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (section.comics.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscoverSectionPage(section: section),
                      ),
                    );
                  },
                  child: const Text('查看更多'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: section.comics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comic = section.comics[index];
                return SizedBox(
                  width: 130,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final heroTag = _comicCoverHeroTag(
                        comic,
                        salt: 'discover-${section.title}-$index',
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ComicDetailPage(comic: comic, heroTag: heroTag),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: _comicCoverHeroTag(
                              comic,
                              salt: 'discover-${section.title}-$index',
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: comic.cover.isEmpty
                                  ? Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                                    )
                                  : HazukiCachedImage(
                                      url: comic.cover,
                                      fit: BoxFit.cover,
                                      width: 130,
                                      loading: Container(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      error: Container(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
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
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshDiscover,
      edgeOffset: 56,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        children: [_buildTopSearchBox(), _buildDiscoverView()],
      ),
    );
  }
}
