import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'discover_section_page.dart';

class DiscoverSectionBlock extends StatefulWidget {
  const DiscoverSectionBlock({
    super.key,
    required this.section,
    required this.sectionIndex,
    required this.layout,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
    required this.sourceService,
  });

  final ExploreSection section;
  final int sectionIndex;
  final DiscoverSectionLayout layout;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function() onLoadMore;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final SourceDiscoverGateway sourceService;

  @override
  State<DiscoverSectionBlock> createState() => _DiscoverSectionBlockState();
}

class _DiscoverSectionBlockState extends State<DiscoverSectionBlock> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        widget.loadingMore ||
        !widget.hasMore) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final useWindowsLayout =
        Theme.of(context).platform == TargetPlatform.windows;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.section.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (widget.section.comics.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscoverSectionPage(
                          section: widget.section,
                          comicDetailPageBuilder: widget.comicDetailPageBuilder,
                          comicCoverHeroTagBuilder:
                              widget.comicCoverHeroTagBuilder,
                          sourceService: widget.sourceService,
                        ),
                      ),
                    );
                  },
                  child: Text(strings.discoverMore),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (useWindowsLayout)
            _buildCoverGrid(context, placeholderColor: placeholderColor)
          else
            switch (widget.layout) {
              DiscoverSectionLayout.horizontal => _buildHorizontalList(
                context,
                placeholderColor: placeholderColor,
              ),
              DiscoverSectionLayout.list => _buildVerticalList(
                context,
                placeholderColor: placeholderColor,
              ),
              DiscoverSectionLayout.grid2 => _buildCoverGrid(
                context,
                placeholderColor: placeholderColor,
                crossAxisCount: 2,
              ),
              DiscoverSectionLayout.grid3 => _buildCoverGrid(
                context,
                placeholderColor: placeholderColor,
                crossAxisCount: 3,
              ),
            },
        ],
      ),
    );
  }

  Widget _buildHorizontalList(
    BuildContext context, {
    required Color placeholderColor,
  }) {
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();
    return SizedBox(
      height: 228,
      child: ListView.separated(
        controller: _scrollController,
        key: PageStorageKey<String>(_pageStorageKey('horizontal')),
        scrollDirection: Axis.horizontal,
        itemCount: widget.section.comics.length + (widget.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index >= widget.section.comics.length) {
            return const SizedBox(
              width: 64,
              child: Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Center(
                  child: SizedBox.square(
                    dimension: 48,
                    child: LoadingIndicatorM3E(),
                  ),
                ),
              ),
            );
          }
          return SizedBox(
            width: 130,
            child: _buildCoverTile(
              context,
              index,
              coverCacheWidth: coverCacheWidth,
              placeholderColor: placeholderColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalList(
    BuildContext context, {
    required Color placeholderColor,
  }) {
    const coverWidth = 88.0;
    const coverHeight = 124.0;
    final coverCacheWidth =
        (coverWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return ListView.separated(
      key: PageStorageKey<String>(_pageStorageKey('list')),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.section.comics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final comic = widget.section.comics[index];
        final heroTag = _heroTag(comic, index);
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => openComicDetail(
            context,
            comic: comic,
            heroTag: heroTag,
            pageBuilder: widget.comicDetailPageBuilder,
          ),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Hero(
                  tag: heroTag,
                  flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
                  placeholderBuilder: buildComicCoverHeroPlaceholder,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: comic.cover.isEmpty
                        ? ColoredBox(
                            color: placeholderColor,
                            child: const SizedBox(
                              width: coverWidth,
                              height: coverHeight,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          )
                        : HazukiCachedImage(
                            url: comic.cover,
                            sourceKey: comic.sourceKey,
                            width: coverWidth,
                            height: coverHeight,
                            fit: BoxFit.cover,
                            cacheWidth: coverCacheWidth,
                            animateOnLoad: true,
                            filterQuality: FilterQuality.low,
                            deferLoadingWhileScrolling: true,
                            useShimmerLoading: false,
                            loading: SizedBox(
                              width: coverWidth,
                              height: coverHeight,
                              child: ColoredBox(color: placeholderColor),
                            ),
                            error: SizedBox(
                              width: coverWidth,
                              height: coverHeight,
                              child: ColoredBox(
                                color: placeholderColor,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
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
                      if (comic.sourceKey == 'picacg' &&
                          comic.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        PicacgComicTags(
                          sourceKey: comic.sourceKey,
                          tags: comic.tags,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverGrid(
    BuildContext context, {
    required Color placeholderColor,
    int? crossAxisCount,
  }) {
    const spacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final estimatedWidth = crossAxisCount == null
            ? 160.0
            : (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
        final coverCacheWidth =
            (estimatedWidth * MediaQuery.devicePixelRatioOf(context)).round();
        final delegate = crossAxisCount == null
            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 0.57,
              )
            : SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 0.57,
              );
        return GridView.builder(
          key: PageStorageKey<String>(
            _pageStorageKey(
              crossAxisCount == null ? 'adaptive' : 'grid$crossAxisCount',
            ),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          addAutomaticKeepAlives: false,
          itemCount: widget.section.comics.length,
          gridDelegate: delegate,
          itemBuilder: (context, index) => _buildCoverTile(
            context,
            index,
            coverCacheWidth: coverCacheWidth,
            placeholderColor: placeholderColor,
          ),
        );
      },
    );
  }

  Widget _buildCoverTile(
    BuildContext context,
    int index, {
    required int coverCacheWidth,
    required Color placeholderColor,
  }) {
    final comic = widget.section.comics[index];
    final heroTag = _heroTag(comic, index);
    return ComicCoverTile(
      comic: comic,
      heroTag: heroTag,
      coverCacheWidth: coverCacheWidth,
      placeholderColor: placeholderColor,
      onTap: () => openComicDetail(
        context,
        comic: comic,
        heroTag: heroTag,
        pageBuilder: widget.comicDetailPageBuilder,
      ),
    );
  }

  String _heroTag(ExploreComic comic, int index) {
    return widget.comicCoverHeroTagBuilder(
      comic,
      salt: 'discover-${widget.sectionIndex}-${widget.section.title}-$index',
    );
  }

  String _pageStorageKey(String layout) =>
      'discover-section-$layout-${widget.sectionIndex}-${widget.section.title}';
}
