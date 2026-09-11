import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

class ComicDetailRelatedTile extends StatelessWidget {
  const ComicDetailRelatedTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.onOpen,
    required this.thumbnailCacheWidth,
  });

  final ExploreComic comic;
  final String heroTag;
  final VoidCallback onOpen;
  final int thumbnailCacheWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpen,
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
                        sourceKey: comic.sourceKey,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        // Windows restores a previous detail by rebuilding it.
                        // Retaining displayed related covers lets the restored
                        // grid paint them on its first frame.
                        keepInMemory: true,
                        cacheWidth: thumbnailCacheWidth,
                        animateOnLoad: true,
                        loadAnimationBeginScale: 1,
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
  }
}
