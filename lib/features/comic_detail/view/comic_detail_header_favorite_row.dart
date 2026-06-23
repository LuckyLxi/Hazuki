import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailHeaderFavoriteRow extends StatelessWidget {
  const ComicDetailHeaderFavoriteRow({
    super.key,
    required this.details,
    required this.favoriteRowKey,
    required this.skeletonColor,
    required this.viewsText,
    required this.shouldAnimateInitialDetailReveal,
    required this.favoriteButtonWidth,
  });

  final ComicDetailsData? details;
  final GlobalKey favoriteRowKey;
  final Color skeletonColor;
  final String viewsText;
  final bool shouldAnimateInitialDetailReveal;
  final double favoriteButtonWidth;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final favorite = scope.favorite;
    final theme = Theme.of(context);
    final showLikeButton = scope.supportsComicLikeAction;
    final detailsReady = details != null;
    final isPicacg = isHazukiPicacgSourceKey(details?.sourceKey ?? '');
    final copyMangaStatusText =
        isHazukiCopyMangaSourceKey(details?.sourceKey ?? '')
        ? _copyMangaStatusText(details)
        : '';
    final statsText = [
      if (copyMangaStatusText.isNotEmpty) copyMangaStatusText,
      if (details?.likesCount.isNotEmpty ?? false)
        l10n(context).comicDetailLikesCount(details!.likesCount),
      if (isPicacg && (details?.pageCount.isNotEmpty ?? false))
        l10n(context).comicDetailPagesCount(details!.pageCount)
      else if (viewsText.isNotEmpty && copyMangaStatusText.isEmpty)
        l10n(context).comicDetailViewsCount(viewsText),
    ].join(' / ');
    final favoriteActive =
        favorite.favoriteOverride ?? details?.isFavorite ?? false;
    final likedActive = favorite.likedOverride ?? details?.isLiked ?? false;

    return Padding(
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
                child: Row(
                  children: [
                    if (showLikeButton) ...[
                      SizedBox(
                        width: 48,
                        child: Tooltip(
                          message: likedActive
                              ? l10n(context).comicDetailUnlike
                              : l10n(context).comicDetailLike,
                          child: FilledButton(
                            onPressed: detailsReady && !favorite.isLikeBusy
                                ? () => unawaited(
                                    favorite.toggleLike(context, details!),
                                  )
                                : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 40),
                              fixedSize: const Size(48, 40),
                              backgroundColor: likedActive
                                  ? theme.colorScheme.primaryContainer
                                  : null,
                              foregroundColor: likedActive
                                  ? theme.colorScheme.onPrimaryContainer
                                  : null,
                            ),
                            child: Icon(
                              likedActive
                                  ? Icons.thumb_up_alt_rounded
                                  : Icons.thumb_up_alt_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: !detailsReady || favorite.isBusy,
                        child: FilledButton.icon(
                          onPressed: () {
                            if (detailsReady) {
                              unawaited(
                                favorite.showFoldersDialog(context, details!, (
                                  vm,
                                ) {
                                  final themedData = scope.theme
                                      .buildDetailTheme(Theme.of(context));
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
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              favoriteActive
                                  ? l10n(context).comicDetailUnfavorite
                                  : l10n(context).comicDetailFavorite,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

String _copyMangaStatusText(ComicDetailsData? details) {
  if (details == null) {
    return '';
  }

  for (final entry in details.tags.entries) {
    final key = entry.key.trim().toLowerCase();
    if (key != 'status' && entry.key.trim() != '状态') {
      continue;
    }

    for (final value in entry.value) {
      final text = value.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }

  return '';
}
