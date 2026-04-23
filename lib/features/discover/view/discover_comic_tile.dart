import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

/// Shared comic cover tile used in both the discover section horizontal list
/// and the section detail grid page.
class DiscoverComicCoverTile extends StatelessWidget {
  const DiscoverComicCoverTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.coverCacheWidth,
    required this.placeholderColor,
    required this.onTap,
  });

  final ExploreComic comic;
  final String heroTag;
  final int coverCacheWidth;
  final Color placeholderColor;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => unawaited(onTap()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                clipBehavior: Clip.hardEdge,
                borderRadius: BorderRadius.circular(8),
                child: comic.cover.isEmpty
                    ? ColoredBox(
                        color: placeholderColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : HazukiCachedImage(
                        url: comic.cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        cacheWidth: coverCacheWidth,
                        animateOnLoad: true,
                        filterQuality: FilterQuality.low,
                        deferLoadingWhileScrolling: true,
                        useShimmerLoading: false,
                        loading: SizedBox.expand(
                          child: ColoredBox(color: placeholderColor),
                        ),
                        error: ColoredBox(
                          color: placeholderColor,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
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
            style: textTheme.bodyMedium,
          ),
          if (comic.subTitle.isNotEmpty)
            Text(
              comic.subTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
