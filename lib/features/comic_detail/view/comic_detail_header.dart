import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/navigation_tags.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../support/comic_detail_scope.dart';
import '../support/comic_detail_session_controller.dart';
import 'comic_detail_favorite_dialog.dart';
import 'comic_detail_view_primitives.dart';

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
    final session = scope.session;
    final actions = scope.actions;
    final favorite = scope.favorite;

    final detailsReady = details != null;
    final theme = Theme.of(context);
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
    final favoriteButtonWidth = MediaQuery.of(context).size.width / 2.2;
    final statsText = [
      if (details?.likesCount.isNotEmpty ?? false)
        l10n(context).comicDetailLikesCount(details!.likesCount),
      if (viewsText.isNotEmpty) l10n(context).comicDetailViewsCount(viewsText),
    ].join(' / ');

    if (displayCoverUrl.isNotEmpty) {
      registerComicCoverHeroUrl(heroTag, displayCoverUrl);
    }

    final favoriteActive =
        favorite.favoriteOverride ?? details?.isFavorite ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: 135,
                height: 190,
                child: InkWell(
                  borderRadius: BorderRadius.circular(coverBorderRadius),
                  onTap: displayCoverUrl.isEmpty
                      ? null
                      : () => unawaited(
                          actions.showCoverPreview(context, displayCoverUrl),
                        ),
                  child: Hero(
                    tag: heroTag,
                    flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
                    placeholderBuilder: buildComicCoverHeroPlaceholder,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(coverBorderRadius),
                      child: displayCoverUrl.isNotEmpty
                          ? HazukiCachedImage(
                              url: displayCoverUrl,
                              fit: BoxFit.cover,
                              keepInMemory: true,
                              cacheWidth: headerCoverCacheWidth,
                              cacheHeight: headerCoverCacheHeight,
                            )
                          : Container(
                              color: skeletonColor,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            ),
                    ),
                  ),
                ),
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
        Padding(
          key: favoriteRowKey,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: SizedBox(
            height: 48,
            child: AnimatedSlide(
              offset: shouldAnimateInitialDetailReveal
                  ? (detailsReady ? Offset.zero : const Offset(0, -0.08))
                  : Offset.zero,
              duration: shouldAnimateInitialDetailReveal
                  ? const Duration(milliseconds: 320)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: detailsReady
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: ComicDetailEntranceReveal(
                                key: const ValueKey('comic-detail-stats'),
                                beginOffset: const Offset(0, 12),
                                enabled: shouldAnimateInitialDetailReveal,
                                child: Text(
                                  statsText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ComicDetailSkeletonBlock(
                                  color: skeletonColor,
                                  width: 112,
                                  height: 12,
                                ),
                                const SizedBox(height: 8),
                                ComicDetailSkeletonBlock(
                                  color: skeletonColor,
                                  width: 84,
                                  height: 12,
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(
                    width: favoriteButtonWidth,
                    child: AbsorbPointer(
                      absorbing: !detailsReady || favorite.isBusy,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (detailsReady) {
                            unawaited(
                              favorite.showFoldersDialog(context, details!, (
                                vm,
                              ) {
                                final themedData = scope.theme.buildDetailTheme(
                                  Theme.of(context),
                                );
                                return Theme(
                                  data: themedData,
                                  child: FavoriteFoldersMorphDialog(
                                    viewModel: vm,
                                  ),
                                );
                              }),
                            );
                          }
                        },
                        icon: Icon(
                          favoriteActive
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: Text(
                          favoriteActive
                              ? l10n(context).comicDetailUnfavorite
                              : l10n(context).comicDetailFavorite,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: favoriteActive
                              ? theme.colorScheme.primaryContainer
                              : null,
                          foregroundColor: favoriteActive
                              ? theme.colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: actionButtonsKey,
          height: 48,
          child: AnimatedSlide(
            offset: shouldAnimateInitialDetailReveal
                ? (detailsReady ? Offset.zero : const Offset(0, -0.08))
                : Offset.zero,
            duration: shouldAnimateInitialDetailReveal
                ? const Duration(milliseconds: 320)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            child: Row(
              children: [
                AbsorbPointer(
                  absorbing: !detailsReady,
                  child: IconButton(
                    tooltip: l10n(context).comicDetailChapters,
                    onPressed: () {
                      if (detailsReady) {
                        actions.showChaptersPanel(context, details!);
                      }
                    },
                    icon: const Icon(Icons.format_list_bulleted_rounded),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: !detailsReady,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (detailsReady) {
                          unawaited(actions.openReader(context, details!));
                        }
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(_buildReaderButtonLabel(context, session)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _buildReaderButtonLabel(
    BuildContext context,
    ComicDetailSessionController session,
  ) {
    if (details == null) return l10n(context).comicDetailRead;
    final lastReadProgress = session.lastReadProgress;
    if (lastReadProgress != null &&
        details!.chapters.length > 1 &&
        lastReadProgress['index'] is int &&
        (lastReadProgress['index'] as int) >= 1 &&
        details!.chapters.containsKey(lastReadProgress['epId'])) {
      final title = lastReadProgress['title'] as String? ?? '';
      return l10n(context).comicDetailContinueReading(title);
    }
    return l10n(context).comicDetailRead;
  }
}
