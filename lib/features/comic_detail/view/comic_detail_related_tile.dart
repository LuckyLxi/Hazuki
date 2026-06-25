import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';

class ComicDetailRelatedTile extends StatelessWidget {
  const ComicDetailRelatedTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.isDesktopPanel,
    required this.pageBuilder,
    required this.thumbnailCacheWidth,
  });

  final ExploreComic comic;
  final String heroTag;
  final bool isDesktopPanel;
  final Widget Function(ExploreComic comic, String heroTag) pageBuilder;
  final int thumbnailCacheWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (isDesktopPanel) {
          unawaited(
            openComicDetail(
              context,
              comic: comic,
              heroTag: heroTag,
              pageBuilder: pageBuilder,
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => pageBuilder(comic, heroTag)),
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
                        sourceKey: comic.sourceKey,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        keepInMemory: false,
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
