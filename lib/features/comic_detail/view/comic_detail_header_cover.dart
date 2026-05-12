import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
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
  });

  final String heroTag;
  final String displayCoverUrl;
  final String sourceKey;
  final Color skeletonColor;
  final int headerCoverCacheWidth;
  final int headerCoverCacheHeight;
  final double coverBorderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 135,
        height: 190,
        child: InkWell(
          borderRadius: BorderRadius.circular(coverBorderRadius),
          onTap: onTap,
          child: Hero(
            tag: heroTag,
            flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
            placeholderBuilder: buildComicCoverHeroPlaceholder,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(coverBorderRadius),
              child: displayCoverUrl.isNotEmpty
                  ? HazukiCachedImage(
                      url: displayCoverUrl,
                      sourceKey: sourceKey,
                      fit: BoxFit.cover,
                      keepInMemory: true,
                      cacheWidth: headerCoverCacheWidth,
                      cacheHeight: headerCoverCacheHeight,
                    )
                  : Container(
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
