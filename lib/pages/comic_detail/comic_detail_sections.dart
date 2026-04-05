part of '../comic_detail_page.dart';

class _ComicDetailLoadingView extends StatelessWidget {
  const _ComicDetailLoadingView();

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

class _ComicDetailInfoTab extends StatelessWidget {
  const _ComicDetailInfoTab({
    required this.details,
    required this.skeletonColor,
    required this.metaSectionBuilder,
  });

  final ComicDetailsData? details;
  final Color skeletonColor;
  final Widget Function(ComicDetailsData details) metaSectionBuilder;

  @override
  Widget build(BuildContext context) {
    if (details == null) {
      return ListView(
        key: const PageStorageKey<String>('comic-detail-info-tab-loading'),
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 100, color: skeletonColor),
          const SizedBox(height: 16),
          Container(height: 60, color: skeletonColor),
        ],
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('comic-detail-info-tab'),
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details!.description.isNotEmpty) ...[
                  Text(
                    l10n(context).comicDetailSummary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  _ExpandableDescription(text: details!.description),
                ],
                if (details!.id.trim().isNotEmpty ||
                    details!.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  metaSectionBuilder(details!),
                ],
              ],
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

class _ComicDetailRelatedTab extends StatelessWidget {
  const _ComicDetailRelatedTab({
    required this.details,
    required this.heroTagPrefix,
  });

  final ComicDetailsData? details;
  final String heroTagPrefix;

  @override
  Widget build(BuildContext context) {
    if (details == null) {
      return const _ComicDetailLoadingView();
    }

    if (details!.recommend.isEmpty) {
      return Center(child: Text(l10n(context).comicDetailNoRelatedComics));
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

    return GridView.builder(
      key: const PageStorageKey<String>('comic-detail-related-tab'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: details!.recommend.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.57,
      ),
      itemBuilder: (context, index) {
        final comic = details!.recommend[index];
        final heroTag = '${heroTagPrefix}_related_$index';
        final child = InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ComicDetailPage(comic: comic, heroTag: heroTag),
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
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          )
                        : HazukiCachedImage(
                            url: comic.cover,
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
                              child: const Icon(Icons.broken_image_outlined),
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

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 350 + (index.clamp(0, 10)) * 60),
          curve: Curves.easeOutBack,
          builder: (context, value, animationChild) {
            return Transform.scale(
              scale: 0.85 + 0.15 * value,
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: animationChild,
                ),
              ),
            );
          },
          child: child,
        );
      },
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
