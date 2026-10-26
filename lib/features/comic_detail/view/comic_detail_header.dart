import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/shared/source_presentation.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_header_action_row.dart';
import 'comic_detail_header_cover.dart';
import 'comic_detail_header_favorite_row.dart';

/// 标题下方的插件短标签。插件未提供 headerBadges 时，
/// 兼容旧的 showComicStatus：从「状态」标签取第一个值显示。
class ComicDetailHeaderBadges extends StatelessWidget {
  const ComicDetailHeaderBadges({super.key, required this.details});

  final ComicDetailsData? details;

  List<(String, ComicHeaderBadgeTone)> _resolve(BuildContext context) {
    final details = this.details;
    if (details == null) return const [];
    final locale = Localizations.localeOf(context).toLanguageTag();
    final badges =
        ComicDetailScope.of(context).favorite.headerBadgesOverride ??
        details.headerBadges;
    if (badges.isNotEmpty) {
      return [
        for (final badge in badges)
          if (localizeSourcePluginText(badge.text, locale).trim()
              case final text when text.isNotEmpty)
            (text, badge.tone),
      ];
    }
    if (!sourceFeature(
      details.sourceKey,
      'showComicStatus',
      context: context,
    )) {
      return const [];
    }
    final status = details.tags.entries
        .where(
          (entry) =>
              entry.key.trim().toLowerCase() == 'status' ||
              entry.key.trim() == '状态',
        )
        .expand((entry) => entry.value)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    return status == null ? const [] : [(status, ComicHeaderBadgeTone.primary)];
  }

  bool hasContent(BuildContext context) => _resolve(context).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (text, tone) in _resolve(context))
          Builder(
            builder: (context) {
              final (foreground, background) = switch (tone) {
                ComicHeaderBadgeTone.normal => (
                  colors.onSurfaceVariant,
                  colors.surfaceContainerHighest,
                ),
                ComicHeaderBadgeTone.primary => (
                  colors.primary,
                  colors.primary.withValues(alpha: 0.08),
                ),
                ComicHeaderBadgeTone.warning => (
                  colors.tertiary,
                  colors.tertiary.withValues(alpha: 0.1),
                ),
                ComicHeaderBadgeTone.error => (
                  colors.error,
                  colors.error.withValues(alpha: 0.08),
                ),
              };
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

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
          final badges = ComicDetailHeaderBadges(details: details);
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
              if (badges.hasContent(context)) ...[
                const SizedBox(height: 12),
                badges,
              ],
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
        final contentWidth = constraints.maxWidth;
        final coverWidth = (contentWidth * 0.37).clamp(104.0, 128.0);
        final coverHeight = coverWidth * 190 / 135;
        final badges = ComicDetailHeaderBadges(details: details);
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
                        if (badges.hasContent(context)) ...[
                          const SizedBox(height: 10),
                          badges,
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
