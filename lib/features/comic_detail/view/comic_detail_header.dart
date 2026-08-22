import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_header_action_row.dart';
import 'comic_detail_header_cover.dart';
import 'comic_detail_header_favorite_row.dart';

class ComicDetailHeaderSection extends StatelessWidget {
  const ComicDetailHeaderSection({
    super.key,
    required this.heroTag,
    required this.details,
    required this.skeletonColor,
    required this.displayTitle,
    required this.displaySubTitle,
    required this.displayCoverUrl,
    required this.viewsText,
    required this.headerTitleKey,
    required this.favoriteRowKey,
    required this.actionButtonsKey,
    required this.shouldAnimateInitialDetailReveal,
  });

  final String heroTag;
  final ComicDetailsData? details;
  final Color skeletonColor;
  final String displayTitle;
  final String displaySubTitle;
  final String displayCoverUrl;
  final String viewsText;
  final GlobalKey headerTitleKey;
  final GlobalKey favoriteRowKey;
  final GlobalKey actionButtonsKey;
  final bool shouldAnimateInitialDetailReveal;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final actions = scope.actions;

    final detailsReady = details != null;
    final coverBorderRadius = comicCoverHeroBorderRadius(heroTag, fallback: 10);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final headerCoverCacheWidth = (135 * devicePixelRatio)
        .round()
        .clamp(135, 640)
        .toInt();
    final headerCoverCacheHeight = (190 * devicePixelRatio)
        .round()
        .clamp(190, 900)
        .toInt();
    final favoriteButtonWidth = MediaQuery.sizeOf(context).width / 2.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ComicDetailHeaderCover(
              heroTag: heroTag,
              displayCoverUrl: displayCoverUrl,
              sourceKey: details?.sourceKey ?? '',
              skeletonColor: skeletonColor,
              headerCoverCacheWidth: headerCoverCacheWidth,
              headerCoverCacheHeight: headerCoverCacheHeight,
              coverBorderRadius: coverBorderRadius,
              onTap: displayCoverUrl.isEmpty
                  ? null
                  : () => unawaited(
                      actions.showCoverPreview(context, displayCoverUrl),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    key: headerTitleKey,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (displaySubTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(displaySubTitle),
                  ],
                ],
              ),
            ),
          ],
        ),
        AnimatedContainer(
          duration: shouldAnimateInitialDetailReveal
              ? const Duration(milliseconds: 320)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          height: shouldAnimateInitialDetailReveal
              ? (detailsReady ? 22 : 14)
              : 22,
        ),
        ComicDetailHeaderFavoriteRow(
          details: details,
          favoriteRowKey: favoriteRowKey,
          skeletonColor: skeletonColor,
          viewsText: viewsText,
          shouldAnimateInitialDetailReveal: shouldAnimateInitialDetailReveal,
          favoriteButtonWidth: favoriteButtonWidth,
        ),
        const SizedBox(height: 8),
        ComicDetailHeaderActionRow(
          details: details,
          actionButtonsKey: actionButtonsKey,
          shouldAnimateInitialDetailReveal: shouldAnimateInitialDetailReveal,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
