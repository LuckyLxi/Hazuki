import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';

import 'comic_detail_related_tile.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailRelatedTab extends StatefulWidget {
  const ComicDetailRelatedTab({
    super.key,
    required this.details,
    required this.isActiveInTabView,
    required this.isDesktopPanel,
    required this.onCloseRequested,
    required this.pageBuilder,
  });

  final ComicDetailsData? details;
  final bool isActiveInTabView;
  final bool isDesktopPanel;
  final VoidCallback? onCloseRequested;
  final Widget Function(ExploreComic comic, String heroTag) pageBuilder;

  @override
  State<ComicDetailRelatedTab> createState() => _ComicDetailRelatedTabState();
}

class _ComicDetailRelatedTabState extends State<ComicDetailRelatedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.isActiveInTabView) {
      return const SizedBox.expand();
    }
    final details = widget.details;
    final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
      context,
    );

    if (details == null) {
      return CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(handle: overlapHandle),
          const SliverFillRemaining(child: ComicDetailLoadingView()),
        ],
      );
    }

    if (details.recommend.isEmpty) {
      return CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(handle: overlapHandle),
          SliverFillRemaining(
            child: Center(
              child: Text(l10n(context).comicDetailNoRelatedComics),
            ),
          ),
        ],
      );
    }

    const crossAxisCount = 3;
    const gridPadding = 16.0;
    const crossSpacing = 10.0;
    final mediaSize = MediaQuery.sizeOf(context);
    final tileWidth =
        (mediaSize.width -
            (gridPadding * 2) -
            (crossSpacing * (crossAxisCount - 1))) /
        crossAxisCount;
    final thumbnailCacheWidth =
        (tileWidth * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(120, 480)
            .toInt();

    return CustomScrollView(
      key: const PageStorageKey<String>('comic-detail-related-tab'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(handle: overlapHandle),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final comic = details.recommend[index];
              final heroTag = comicCoverHeroTag(comic, salt: 'related-$index');
              return ComicDetailRelatedTile(
                comic: comic,
                heroTag: heroTag,
                isDesktopPanel: widget.isDesktopPanel,
                pageBuilder: widget.pageBuilder,
                thumbnailCacheWidth: thumbnailCacheWidth,
              );
            }, childCount: details.recommend.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.57,
            ),
          ),
        ),
      ],
    );
  }
}
