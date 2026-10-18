import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/images/comic_cover_handoff.dart';
import 'package:hazuki/widgets/widgets.dart';

class ComicDetailHeaderCover extends StatelessWidget {
  const ComicDetailHeaderCover({
    super.key,
    required this.heroTag,
    required this.displayCoverUrl,
    required this.sourceKey,
    required this.skeletonColor,
    required this.headerCoverCacheWidth,
    required this.headerCoverCacheHeight,
    required this.coverBorderRadius,
    required this.onTap,
    this.width = 135,
    this.height = 190,
  });

  final String heroTag;
  final String displayCoverUrl;
  final String sourceKey;
  final Color skeletonColor;
  final int headerCoverCacheWidth;
  final int headerCoverCacheHeight;
  final double coverBorderRadius;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final handoff = ComicCoverHandoffScope.find(context, heroTag);
    final coverImage = displayCoverUrl.isEmpty
        ? null
        : HazukiCachedImage(
            url: displayCoverUrl,
            sourceKey: handoff?.sourceKey ?? sourceKey,
            fit: BoxFit.cover,
            keepInMemory: true,
            cacheWidth: headerCoverCacheWidth,
            cacheHeight: headerCoverCacheHeight,
          );
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: InkWell(
          borderRadius: BorderRadius.circular(coverBorderRadius),
          onTap: onTap,
          child: ComicCoverHero(
            tag: heroTag,
            image: coverImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(coverBorderRadius),
              child: handoff != null
                  ? ComicCoverHandoffImage(
                      handoff: handoff,
                      coverUrl: displayCoverUrl,
                      cacheWidth: headerCoverCacheWidth,
                      cacheHeight: headerCoverCacheHeight,
                    )
                  : coverImage ??
                        Container(
                          color: skeletonColor,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}
