import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/discover_section_page_controller.dart';
import 'discover_comic_tile.dart';

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

  late final DiscoverSectionPageController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverSectionPageController(
      viewMoreUrl: widget.section.viewMoreUrl,
      initialComics: widget.section.viewMoreUrl == null
          ? widget.section.comics
          : null,
    );
    _scrollController.addListener(_onScroll);
    _scheduleInitialBootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleInitialBootstrap() {
    final viewMoreUrl = widget.section.viewMoreUrl;
    if (viewMoreUrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_triggerLoadSortOptionsAndInitial());
    });
  }

  Future<void> _triggerLoadSortOptionsAndInitial() async {
    if (widget.section.viewMoreUrl == null) return;
    final strings = AppLocalizations.of(context)!;
    await _controller.loadSortOptionsAndInitial(
      loadFailedMessage: strings.discoverSectionLoadFailed,
    );
  }

  Future<void> _triggerLoadMore() async {
    await _controller.loadMore();
  }

  void _onSelectSortOption(String value) {
    unawaited(_controller.selectSortOption(value: value));
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nextShowBackToTop = pos.pixels > 520;

    final shouldRevealInitialLoadFooter =
        _controller.loadingMore &&
        !_controller.showLoadMoreFooter &&
        _controller.currentPage == 0 &&
        _controller.comics.isNotEmpty &&
        pos.pixels >= pos.maxScrollExtent - 240;

    if (nextShowBackToTop != _showBackToTop) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }
    if (shouldRevealInitialLoadFooter) {
      _controller.revealLoadMoreFooter();
    }

    if (!_controller.hasMore || _controller.loadingMore) return;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      unawaited(_triggerLoadMore());
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  String _comicEntryKey(ExploreComic comic, int index) {
    final comicId = comic.id.trim();
    if (comicId.isNotEmpty) return 'comic:$comicId';
    final cover = comic.cover.trim();
    if (cover.isNotEmpty) return 'cover:$cover';
    return 'fallback:${comic.title}|$index';
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
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    if (_controller.sortOptions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final option in _controller.sortOptions)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(option.label),
                                      selected:
                                          _controller.selectedSortValue ==
                                          option.value,
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
                      child: _controller.comics.isEmpty
                          ? (_controller.loadingMore || _controller.sortLoading)
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
                                : Center(
                                    child: Text(strings.discoverSectionEmpty),
                                  )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final contentWidth = constraints.maxWidth - 32;
                                final coverWidth =
                                    (contentWidth -
                                        (_gridCrossAxisCount - 1) *
                                            _gridSpacing) /
                                    _gridCrossAxisCount;
                                final coverCacheWidth =
                                    (coverWidth *
                                            MediaQuery.devicePixelRatioOf(
                                              context,
                                            ))
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
                                  itemCount: _controller.comics.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: _gridCrossAxisCount,
                                        mainAxisSpacing: _gridSpacing,
                                        crossAxisSpacing: _gridSpacing,
                                        childAspectRatio: 0.57,
                                      ),
                                  itemBuilder: (context, index) {
                                    final comic = _controller.comics[index];
                                    final heroTag = widget.comicCoverHeroTagBuilder(
                                      comic,
                                      salt:
                                          'discover-more-${widget.section.title}-$index',
                                    );
                                    final entryKey = _comicEntryKey(
                                      comic,
                                      index,
                                    );
                                    return DiscoverComicCoverTile(
                                      key: ValueKey<String>('tile-$entryKey'),
                                      comic: comic,
                                      heroTag: heroTag,
                                      coverCacheWidth: coverCacheWidth,
                                      placeholderColor:
                                          colorScheme.surfaceContainerHighest,
                                      onTap: () => openComicDetail(
                                        context,
                                        comic: comic,
                                        heroTag: heroTag,
                                        pageBuilder:
                                            widget.comicDetailPageBuilder,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
                if (_controller.showLoadMoreFooter)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: IgnorePointer(
                      child: HazukiLoadMoreFooter(verticalPadding: 4),
                    ),
                  ),
                if (_controller.errorMessage != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
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
                                  _controller.errorMessage!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _triggerLoadMore,
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
                      offset: _showBackToTop
                          ? Offset.zero
                          : const Offset(0, 0.24),
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
                              child: const Icon(
                                Icons.vertical_align_top_rounded,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
