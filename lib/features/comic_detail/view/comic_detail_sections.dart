import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailLoadingView extends StatelessWidget {
  const ComicDetailLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazukiSandyLoadingIndicator(size: 136),
          const SizedBox(height: 10),
          Text(l10n(context).comicDetailLoading),
        ],
      ),
    );
  }
}

class ComicDetailInfoTab extends StatefulWidget {
  const ComicDetailInfoTab({
    super.key,
    required this.details,
    required this.skeletonColor,
    required this.isActiveInTabView,
    required this.shouldAnimateResolvedContent,
  });

  final ComicDetailsData? details;
  final Color skeletonColor;
  final bool isActiveInTabView;
  final bool shouldAnimateResolvedContent;

  @override
  State<ComicDetailInfoTab> createState() => _ComicDetailInfoTabState();
}

class _ComicDetailInfoTabState extends State<ComicDetailInfoTab> {
  // Tracks whether the entrance animation has already played once.
  // Survives tab switches because Flutter preserves State objects as long as
  // the widget type and position in the tree are unchanged.
  bool _hasAnimated = false;

  Widget _buildMetaSection(BuildContext context, ComicDetailsData details) {
    final actions = ComicDetailScope.of(context).actions;
    return ComicDetailMetaSection(
      details: details,
      onCopyId: (id) => unawaited(actions.copyComicId(context, id)),
      onMetaValuePressed: (v) => actions.openSearchForKeyword(context, v),
      onMetaValueLongPress: (v) => unawaited(actions.copyMetaValue(context, v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActiveInTabView) {
      return const SizedBox.expand();
    }
    final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
      context,
    );
    if (widget.details == null) {
      return CustomScrollView(
        key: const PageStorageKey<String>('comic-detail-info-tab-loading'),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(handle: overlapHandle),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _ComicDetailInfoSkeleton(
                skeletonColor: widget.skeletonColor,
              ),
            ),
          ),
        ],
      );
    }

    final details = widget.details!;
    // Only animate on the very first active render with loaded content.
    final shouldAnimate = widget.shouldAnimateResolvedContent && !_hasAnimated;
    if (shouldAnimate) {
      // Set synchronously 鈥?no setState needed since we only ever go false鈫抰rue
      // and this flag never drives a rebuild on its own.
      _hasAnimated = true;
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('comic-detail-info-tab'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverOverlapInjector(handle: overlapHandle),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: ComicDetailEntranceReveal(
              key: ValueKey<String>('comic-detail-info-${details.id}'),
              beginOffset: const Offset(0, 20),
              enabled: shouldAnimate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details.description.isNotEmpty) ...[
                    Text(
                      l10n(context).comicDetailSummary,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    _ExpandableDescription(text: details.description),
                  ],
                  if (details.id.trim().isNotEmpty ||
                      details.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMetaSection(context, details),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ComicDetailInfoSkeleton extends StatelessWidget {
  const _ComicDetailInfoSkeleton({required this.skeletonColor});

  final Color skeletonColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComicDetailSkeletonBlock(
          color: skeletonColor,
          width: 92,
          height: 18,
          radius: 9,
        ),
        const SizedBox(height: 14),
        ComicDetailSkeletonBlock(color: skeletonColor, height: 16, radius: 8),
        const SizedBox(height: 10),
        ComicDetailSkeletonBlock(
          color: skeletonColor,
          width: MediaQuery.sizeOf(context).width * 0.72,
          height: 16,
          radius: 8,
        ),
        const SizedBox(height: 10),
        ComicDetailSkeletonBlock(
          color: skeletonColor,
          width: MediaQuery.sizeOf(context).width * 0.54,
          height: 16,
          radius: 8,
        ),
        const SizedBox(height: 18),
        ...List<Widget>.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 10),
            child: ComicDetailSkeletonBlock(
              color: skeletonColor,
              width:
                  MediaQuery.sizeOf(context).width *
                  (index.isEven ? 0.9 : 0.76),
              height: 16,
              radius: 8,
            ),
          ),
        ),
      ],
    );
  }
}

class ComicDetailRelatedTab extends StatefulWidget {
  const ComicDetailRelatedTab({
    super.key,
    required this.details,
    required this.heroTagPrefix,
    required this.isActiveInTabView,
    required this.isDesktopPanel,
    required this.onCloseRequested,
    required this.pageBuilder,
  });

  final ComicDetailsData? details;
  final String heroTagPrefix;
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
    final mediaQuery = MediaQuery.of(context);
    final tileWidth =
        (mediaQuery.size.width -
            (gridPadding * 2) -
            (crossSpacing * (crossAxisCount - 1))) /
        crossAxisCount;
    final thumbnailCacheWidth = (tileWidth * mediaQuery.devicePixelRatio)
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
              final heroTag = '${widget.heroTagPrefix}_related_$index';
              final child = InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (widget.isDesktopPanel) {
                    unawaited(
                      openComicDetail(
                        context,
                        comic: comic,
                        heroTag: heroTag,
                        pageBuilder: widget.pageBuilder,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => widget.pageBuilder(comic, heroTag),
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
                                  sourceKey: comic.sourceKey,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  keepInMemory: false,
                                  cacheWidth: thumbnailCacheWidth,
                                  loading: Container(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                  ),
                                  error: Container(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              );

              return child;
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

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});
  final String text;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: 6,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.hardEdge,
              child: SelectionArea(
                child: Text(
                  widget.text,
                  style: textStyle,
                  maxLines: _expanded ? null : (isOverflowing ? 6 : null),
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.clip,
                ),
              ),
            ),
            if (isOverflowing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _expanded
                            ? l10n(context).comicDetailCollapse
                            : l10n(context).comicDetailExpand,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        turns: _expanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
