import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/source_presentation.dart';

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
    required this.displayCoverUrl,
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
  final String displayCoverUrl;
  final GlobalKey headerTitleKey;
  final GlobalKey favoriteRowKey;
  final GlobalKey actionButtonsKey;
  final bool shouldAnimateInitialDetailReveal;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final actions = scope.actions;

    final coverBorderRadius = comicCoverHeroBorderRadius(heroTag, fallback: 10);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

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
                convertChineseText(context, displayTitle),
                key: headerTitleKey,
                style:
                    (wide
                            ? theme.textTheme.headlineMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
              ),
            ],
          );
          final animatedTitle = shouldAnimateInitialDetailReveal
              ? AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  clipBehavior: Clip.hardEdge,
                  child: title,
                )
              : title;
          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ComicDetailHeaderFavoriteRow(
                details: details,
                favoriteRowKey: favoriteRowKey,
                skeletonColor: skeletonColor,
                shouldAnimateInitialDetailReveal:
                    shouldAnimateInitialDetailReveal,
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
                            animatedTitle,
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
                          Expanded(child: animatedTitle),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final contentWidth = constraints.maxWidth;
        final coverWidth = (contentWidth * 0.37).clamp(104.0, 128.0);
        final coverHeight = coverWidth * 190 / 135;
        final status =
            sourceFeature(
              details?.sourceKey ?? '',
              'showComicStatus',
              context: context,
            )
            ? details?.tags.entries
                      .where(
                        (entry) =>
                            entry.key.trim().toLowerCase() == 'status' ||
                            entry.key.trim() == '状态',
                      )
                      .expand((entry) => entry.value)
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .firstOrNull ??
                  ''
            : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
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
                    headerCoverCacheWidth: (coverWidth * devicePixelRatio)
                        .round(),
                    headerCoverCacheHeight: (coverHeight * devicePixelRatio)
                        .round(),
                    coverBorderRadius: coverBorderRadius,
                    width: coverWidth,
                    height: coverHeight,
                    onTap: displayCoverUrl.isEmpty
                        ? null
                        : () => unawaited(
                            actions.showCoverPreview(context, displayCoverUrl),
                          ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: convertChineseText(context, displayTitle),
                          child: Text(
                            convertChineseText(context, displayTitle),
                            key: headerTitleKey,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.55,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (status.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ComicDetailHeaderFavoriteRow(
                details: details,
                favoriteRowKey: favoriteRowKey,
                skeletonColor: skeletonColor,
                shouldAnimateInitialDetailReveal:
                    shouldAnimateInitialDetailReveal,
              ),
              const SizedBox(height: 8),
              ComicDetailHeaderActionRow(
                details: details,
                actionButtonsKey: actionButtonsKey,
                shouldAnimateInitialDetailReveal:
                    shouldAnimateInitialDetailReveal,
                useMobileStyle: true,
              ),
            ],
          ),
        );
      },
    );
  }
}
