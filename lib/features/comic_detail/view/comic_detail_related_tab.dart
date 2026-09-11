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
    required this.onOpenComic,
  });

  final ComicDetailsData? details;
  final bool isActiveInTabView;
  final void Function(ExploreComic comic, String heroTag) onOpenComic;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = Theme.of(context).platform == TargetPlatform.windows;
        final gridPadding = isDesktop ? 24.0 : 16.0;
        final crossSpacing = isDesktop ? 16.0 : 10.0;
        final availableWidth = constraints.maxWidth - gridPadding * 2;
        final crossAxisCount = isDesktop
            ? ((availableWidth + crossSpacing) / (160 + crossSpacing))
                  .ceil()
                  .clamp(1, 20)
            : 3;
        final tileWidth =
            (availableWidth - (crossSpacing * (crossAxisCount - 1))) /
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
              padding: EdgeInsets.all(gridPadding),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final comic = details.recommend[index];
                  final heroTag = comicCoverHeroTag(
                    comic,
                    salt: 'related-$index',
                  );
                  return ComicDetailRelatedTile(
                    comic: comic,
                    heroTag: heroTag,
                    onOpen: () => widget.onOpenComic(comic, heroTag),
                    thumbnailCacheWidth: thumbnailCacheWidth,
                  );
                }, childCount: details.recommend.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: isDesktop ? 20 : 10,
                  crossAxisSpacing: crossSpacing,
                  mainAxisExtent: isDesktop
                      ? tileWidth / 0.7 +
                            MediaQuery.textScalerOf(context).scale(64) +
                            6
                      : null,
                  childAspectRatio: 0.57,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
