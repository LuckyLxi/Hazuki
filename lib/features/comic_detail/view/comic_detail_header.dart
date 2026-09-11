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
    this.isDesktop = false,
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
  final bool isDesktop;

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

    if (isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final theme = Theme.of(context);
          final coverWidth = wide ? 210.0 : 135.0;
          final coverHeight = wide ? 296.0 : 190.0;
          final cover = ComicDetailHeaderCover(
            heroTag: heroTag,
            displayCoverUrl: displayCoverUrl,
            sourceKey: details?.sourceKey ?? '',
            skeletonColor: skeletonColor,
            headerCoverCacheWidth: (coverWidth * devicePixelRatio).round(),
            headerCoverCacheHeight: (coverHeight * devicePixelRatio).round(),
            coverBorderRadius: coverBorderRadius,
            width: coverWidth,
            height: coverHeight,
            onTap: displayCoverUrl.isEmpty
                ? null
                : () => unawaited(
                    actions.showCoverPreview(context, displayCoverUrl),
                  ),
          );
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                displayTitle,
                key: headerTitleKey,
                style:
                    (wide
                            ? theme.textTheme.headlineMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
              ),
              if (displaySubTitle.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  displaySubTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          );
          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComicDetailHeaderFavoriteRow(
                details: details,
                favoriteRowKey: favoriteRowKey,
                skeletonColor: skeletonColor,
                viewsText: viewsText,
                shouldAnimateInitialDetailReveal:
                    shouldAnimateInitialDetailReveal,
                favoriteButtonWidth: wide ? 200 : constraints.maxWidth * 0.48,
                isDesktop: true,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ComicDetailHeaderActionRow(
                  details: details,
                  actionButtonsKey: actionButtonsKey,
                  shouldAnimateInitialDetailReveal:
                      shouldAnimateInitialDetailReveal,
                ),
              ),
            ],
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(width: 36),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 28),
                            controls,
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cover,
                          const SizedBox(width: 20),
                          Expanded(child: title),
                        ],
                      ),
                      const SizedBox(height: 20),
                      controls,
                    ],
                  ),
          );
        },
      );
    }

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
