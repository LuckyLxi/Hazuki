import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

/// 专栏漫画列表页
/// 若 [section.viewMoreUrl] 不为空，则进入页后加载该页面自己的第一页数据；
/// 若为空，则直接展示 [section.comics]
class DiscoverSectionPage extends StatefulWidget {
  const DiscoverSectionPage({
    super.key,
    required this.section,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ExploreSection section;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverSectionPage> createState() => _DiscoverSectionPageState();
}

class _DiscoverSectionPageState extends State<DiscoverSectionPage> {
  static const int _gridCrossAxisCount = 3;
  static const double _gridSpacing = 10;

  final ScrollController _scrollController = ScrollController();

  /// 展示的漫画列表
  late final List<ExploreComic> _comics;

  bool _loadingMore = false;
  bool _showLoadMoreFooter = false;
  bool _hasMore = true;
  bool _showBackToTop = false;
  int _currentPage = 0;
  String? _errorMessage;

  List<CategoryRankingOption> _sortOptions = const <CategoryRankingOption>[];
  String? _selectedSortValue;
  bool _sortLoading = false;
  int _deferredInitialLoadGeneration = 0;

  void _scheduleInitialBootstrap() {
    final viewMoreUrl = widget.section.viewMoreUrl;
    if (viewMoreUrl == null) {
      return;
    }
    final generation = ++_deferredInitialLoadGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _deferredInitialLoadGeneration) {
        return;
      }
      unawaited(_loadSortOptions());
    });
  }

  @override
  void initState() {
    super.initState();
    _comics = widget.section.viewMoreUrl == null
        ? List<ExploreComic>.from(widget.section.comics)
        : <ExploreComic>[];
    _sortLoading = widget.section.viewMoreUrl != null;
    // 无 viewMoreUrl 则不支持分页
    if (widget.section.viewMoreUrl == null) {
      _hasMore = false;
    }
    _scrollController.addListener(_onScroll);
    _scheduleInitialBootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _comicEntryKey(ExploreComic comic, int index) {
    final comicId = comic.id.trim();
    if (comicId.isNotEmpty) {
      return 'comic:$comicId';
    }
    final cover = comic.cover.trim();
    if (cover.isNotEmpty) {
      return 'cover:$cover';
    }
    return 'fallback:${comic.title}|$index';
  }

  /// 滚动监听：距底部 300px 时触发加载更多
  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final pos = _scrollController.position;
    final nextShowBackToTop = pos.pixels > 520;
    final shouldRevealInitialLoadFooter =
        _loadingMore &&
        !_showLoadMoreFooter &&
        _currentPage == 0 &&
        _comics.isNotEmpty &&
        pos.pixels >= pos.maxScrollExtent - 240;
    if (mounted &&
        (nextShowBackToTop != _showBackToTop ||
            shouldRevealInitialLoadFooter)) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
        if (shouldRevealInitialLoadFooter) {
          _showLoadMoreFooter = true;
        }
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

    final nextPage = _currentPage + 1;
    final showFooter = nextPage > 1 && _comics.isNotEmpty;

    setState(() {
      _loadingMore = true;
      _showLoadMoreFooter = showFooter;
      _errorMessage = null;
    });

    try {
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
        final maxPage = result.maxPage;
        _hasMore =
            result.comics.isNotEmpty && (maxPage == null || nextPage < maxPage);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.discoverSectionLoadFailed('$e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _showLoadMoreFooter = false;
        });
      }
    }
  }

  Future<void> _loadSortOptions() async {
    final viewMoreUrl = widget.section.viewMoreUrl;
    if (viewMoreUrl == null) {
      return;
    }

    if (!_sortLoading) {
      setState(() {
        _sortLoading = true;
      });
    }

    try {
      final options = await HazukiSourceService.instance
          .loadCategoryRankingOptionsByViewMore(viewMoreUrl: viewMoreUrl);
      if (!mounted) return;

      setState(() {
        _sortOptions = options;
        _selectedSortValue = options.isEmpty ? null : options.first.value;
        _currentPage = 0;
        _hasMore = true;
        _errorMessage = null;
      });

      unawaited(_loadMore());
    } catch (e) {
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
      _currentPage = 0;
      _hasMore = true;
      _showLoadMoreFooter = false;
      _comics.clear();
    });
    unawaited(_loadMore());
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return WindowsComicDetailHost(
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(widget.section.title),
          enableBlur: false,
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
                                    const HazukiSandyLoadingIndicator(
                                      size: 168,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(strings.commonLoading),
                                  ],
                                ),
                              )
                            : Center(child: Text(strings.discoverSectionEmpty))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final contentWidth = constraints.maxWidth - 32;
                            final coverWidth =
                                (contentWidth -
                                    (_gridCrossAxisCount - 1) * _gridSpacing) /
                                _gridCrossAxisCount;
                            final coverCacheWidth =
                                (coverWidth *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round();

                            return GridView.builder(
                              controller: _scrollController,
                              addAutomaticKeepAlives: false,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                12,
                              ),
                              itemCount: _comics.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _gridCrossAxisCount,
                                    mainAxisSpacing: _gridSpacing,
                                    crossAxisSpacing: _gridSpacing,
                                    childAspectRatio: 0.57,
                                  ),
                              itemBuilder: (context, index) {
                                final comic = _comics[index];
                                final heroTag = widget.comicCoverHeroTagBuilder(
                                  comic,
                                  salt:
                                      'discover-more-${widget.section.title}-$index',
                                );
                                final entryKey = _comicEntryKey(comic, index);
                                return _DiscoverSectionComicTile(
                                  key: ValueKey<String>('tile-$entryKey'),
                                  comic: comic,
                                  heroTag: heroTag,
                                  coverCacheWidth: coverCacheWidth,
                                  placeholderColor:
                                      colorScheme.surfaceContainerHighest,
                                  titleStyle: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium,
                                  subtitleStyle: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                  onTap: () => openComicDetail(
                                    context,
                                    comic: comic,
                                    heroTag: heroTag,
                                    pageBuilder: widget.comicDetailPageBuilder,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_showLoadMoreFooter)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: HazukiLoadMoreFooter(verticalPadding: 4),
                ),
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
              child: RepaintBoundary(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverSectionComicTile extends StatelessWidget {
  const _DiscoverSectionComicTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.coverCacheWidth,
    required this.placeholderColor,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.onTap,
  });

  final ExploreComic comic;
  final String heroTag;
  final int coverCacheWidth;
  final Color placeholderColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        unawaited(onTap());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                clipBehavior: Clip.hardEdge,
                borderRadius: BorderRadius.circular(8),
                child: comic.cover.isEmpty
                    ? ColoredBox(
                        color: placeholderColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : HazukiCachedImage(
                        url: comic.cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        cacheWidth: coverCacheWidth,
                        animateOnLoad: true,
                        filterQuality: FilterQuality.low,
                        deferLoadingWhileScrolling: true,
                        useShimmerLoading: false,
                        loading: SizedBox.expand(
                          child: ColoredBox(color: placeholderColor),
                        ),
                        error: ColoredBox(
                          color: placeholderColor,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
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
            style: titleStyle,
          ),
          if (comic.subTitle.isNotEmpty)
            Text(
              comic.subTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
        ],
      ),
    );
  }
}
