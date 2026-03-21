part of '../../main.dart';

class _ComicDetailLoadingView extends StatelessWidget {
  const _ComicDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HazukiStickerLoadingIndicator(size: 112),
          SizedBox(height: 10),
          Text('加载中...'),
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
                    '简介',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(details!.description),
                ],
                if (details!.id.trim().isNotEmpty || details!.tags.isNotEmpty) ...[
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
      return const Center(child: Text('暂无相关漫画'));
    }

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
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).push(
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
                              child: Icon(Icons.image_not_supported_outlined),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            error: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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
      },
    );
  }
}
