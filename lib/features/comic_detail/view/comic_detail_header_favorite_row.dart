import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailHeaderFavoriteRow extends StatelessWidget {
  const ComicDetailHeaderFavoriteRow({
    super.key,
    required this.details,
    required this.favoriteRowKey,
    required this.skeletonColor,
    required this.shouldAnimateInitialDetailReveal,
    this.isDesktop = false,
  });

  final ComicDetailsData? details;
  final GlobalKey favoriteRowKey;
  final Color skeletonColor;
  final bool shouldAnimateInitialDetailReveal;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final favorite = scope.favorite;
    final theme = Theme.of(context);
    final showLikeButton = favorite.supportComicLike;
    final detailsReady = details != null;
    String statText(ComicHeaderStat stat) => localizeSourcePluginText(
      stat.text,
      Localizations.localeOf(context).toLanguageTag(),
    ).trim();
    final stats = (details?.headerStats ?? const <ComicHeaderStat>[])
        .where((stat) => statText(stat).isNotEmpty)
        .toList(growable: false);
    final statsText = stats.map(statText).join(' / ');
    final favoriteActive =
        favorite.favoriteOverride ?? details?.isFavorite ?? false;
    final likedActive = favorite.likedOverride ?? details?.isLiked ?? false;

    if (isDesktop) {
      ButtonStyle buttonStyle(bool active) => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        foregroundColor: active
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        backgroundColor: active
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      return Column(
        key: favoriteRowKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: !detailsReady
                  ? ComicDetailSkeletonBlock(
                      color: skeletonColor,
                      width: 160,
                      height: 16,
                    )
                  : statsText.isNotEmpty
                  ? Text(
                      statsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (showLikeButton)
                OutlinedButton.icon(
                  style: buttonStyle(likedActive),
                  onPressed: detailsReady && !favorite.isLikeBusy
                      ? () => unawaited(favorite.toggleLike(context, details!))
                      : null,
                  icon: Icon(
                    likedActive
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 18,
                  ),
                  label: Text(
                    likedActive
                        ? l10n(context).comicDetailUnlike
                        : l10n(context).comicDetailLike,
                  ),
                ),
              OutlinedButton.icon(
                style: buttonStyle(favoriteActive),
                onPressed: detailsReady && !favorite.isBusy
                    ? () => unawaited(
                        favorite.showFoldersDialog(
                          context,
                          details!,
                          (vm) => Theme(
                            data: scope.theme.buildDetailTheme(theme),
                            child: FavoriteFoldersMorphDialog(viewModel: vm),
                          ),
                        ),
                      )
                    : null,
                icon: Icon(
                  favoriteActive ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                ),
                label: Text(
                  favoriteActive
                      ? l10n(context).comicDetailUnfavorite
                      : l10n(context).comicDetailFavorite,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final statsStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final reserveStatsHeight = theme.platform == TargetPlatform.android;
    final likeButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      foregroundColor: likedActive
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      textStyle: statsStyle,
    );
    final statWidgets = <Widget>[];
    final plainText = <String>[];
    void flushPlainText() {
      if (plainText.isEmpty) return;
      statWidgets.add(
        Text(
          plainText.join(' · '),
          style: statsStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      plainText.clear();
    }

    for (final stat in stats) {
      if (stat.action == ComicHeaderStatAction.like && showLikeButton) {
        flushPlainText();
        statWidgets.add(
          TextButton.icon(
            onPressed: detailsReady && !favorite.isLikeBusy
                ? () => unawaited(favorite.toggleLike(context, details!))
                : null,
            style: likeButtonStyle,
            icon: Icon(
              likedActive
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              size: 16,
            ),
            label: Text(
              statText(stat),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      } else {
        plainText.add(statText(stat));
      }
    }
    flushPlainText();
    final resolvedStats = reserveStatsHeight
        ? Row(
            children: [
              for (var index = 0; index < statWidgets.length; index++) ...[
                if (index > 0) const SizedBox(width: 14),
                Flexible(child: statWidgets[index]),
              ],
            ],
          )
        : Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: statWidgets,
          );
    final statsContent = detailsReady
        ? ComicDetailEntranceReveal(
            key: const ValueKey('comic-detail-stats'),
            beginOffset: Offset.zero,
            enabled: shouldAnimateInitialDetailReveal,
            child: resolvedStats,
          )
        : ComicDetailSkeletonBlock(
            color: skeletonColor,
            width: 160,
            height: 16,
          );
    return Padding(
      key: favoriteRowKey,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: Duration.zero,
        curve: Curves.easeOutCubic,
        child: reserveStatsHeight
            ? SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Reserve a button-sized row even before the plugin's like
                    // capability resolves. Measuring it also honors text scale,
                    // theme padding and the minimum touch target size.
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainState: true,
                      maintainAnimation: true,
                      child: TextButton.icon(
                        onPressed: null,
                        style: likeButtonStyle,
                        icon: const SizedBox.square(dimension: 16),
                        label: const Text(' ', maxLines: 1),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: statsContent,
                      ),
                    ),
                  ],
                ),
              )
            : statsContent,
      ),
    );
  }
}
