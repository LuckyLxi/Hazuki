import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'discover_section_page.dart';

class DiscoverSectionBlock extends StatefulWidget {
  const DiscoverSectionBlock({
    super.key,
    required this.section,
    required this.sectionIndex,
    required this.loadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final ExploreSection section;
  final int sectionIndex;
  final bool loadingMore;
  final bool hasMore;
  final Future<void> Function() onLoadMore;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

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
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();

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
                        ),
                      ),
                    );
                  },
                  child: Text(strings.discoverMore),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: ListView.separated(
              controller: _scrollController,
              key: PageStorageKey<String>(
                'discover-section-${widget.sectionIndex}-${widget.section.title}',
              ),
              scrollDirection: Axis.horizontal,
              itemCount:
                  widget.section.comics.length + (widget.loadingMore ? 1 : 0),
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
                final comic = widget.section.comics[index];
                final heroTag = widget.comicCoverHeroTagBuilder(
                  comic,
                  salt:
                      'discover-${widget.sectionIndex}-${widget.section.title}-$index',
                );
                return SizedBox(
                  width: 130,
                  child: ComicCoverTile(
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
