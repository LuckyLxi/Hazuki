part of '../comic_detail_page.dart';

class _ComicDetailHeaderSection extends StatelessWidget {
  const _ComicDetailHeaderSection({
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
    required this.favoriteBusy,
    required this.favoriteOverride,
    required this.lastReadProgress,
    required this.shouldAnimateInitialDetailReveal,
    required this.onCoverTap,
    required this.onFavoriteTap,
    required this.onShowChapters,
    required this.onOpenReader,
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
  final bool favoriteBusy;
  final bool? favoriteOverride;
  final Map<String, dynamic>? lastReadProgress;
  final bool shouldAnimateInitialDetailReveal;
  final VoidCallback? onCoverTap;
  final ValueChanged<ComicDetailsData> onFavoriteTap;
  final ValueChanged<ComicDetailsData> onShowChapters;
  final ValueChanged<ComicDetailsData> onOpenReader;

  @override
  Widget build(BuildContext context) {
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
                  onTap: displayCoverUrl.isEmpty ? null : onCoverTap,
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
                              child: _ComicDetailEntranceReveal(
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
                                _ComicDetailSkeletonBlock(
                                  color: skeletonColor,
                                  width: 112,
                                  height: 12,
                                ),
                                const SizedBox(height: 8),
                                _ComicDetailSkeletonBlock(
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
                      absorbing: !detailsReady || favoriteBusy,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (detailsReady) {
                            onFavoriteTap(details!);
                          }
                        },
                        icon: Icon(
                          (favoriteOverride ?? details?.isFavorite ?? false)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        label: Text(
                          (favoriteOverride ?? details?.isFavorite ?? false)
                              ? l10n(context).comicDetailUnfavorite
                              : l10n(context).comicDetailFavorite,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              (favoriteOverride ?? details?.isFavorite ?? false)
                              ? theme.colorScheme.primaryContainer
                              : null,
                          foregroundColor:
                              (favoriteOverride ?? details?.isFavorite ?? false)
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
                        onShowChapters(details!);
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
                          onOpenReader(details!);
                        }
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(_buildReaderButtonLabel(context)),
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

  String _buildReaderButtonLabel(BuildContext context) {
    if (details == null) {
      return l10n(context).comicDetailRead;
    }
    if (lastReadProgress != null &&
        details!.chapters.length > 1 &&
        (lastReadProgress!['index'] as int) >= 1 &&
        details!.chapters.containsKey(lastReadProgress!['epId'])) {
      final title = lastReadProgress!['title'] as String;
      return l10n(context).comicDetailContinueReading(title);
    }
    return l10n(context).comicDetailRead;
  }
}
