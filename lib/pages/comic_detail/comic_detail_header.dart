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
  final VoidCallback? onCoverTap;
  final ValueChanged<ComicDetailsData> onFavoriteTap;
  final ValueChanged<ComicDetailsData> onShowChapters;
  final ValueChanged<ComicDetailsData> onOpenReader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: displayCoverUrl.isEmpty ? null : onCoverTap,
              child: Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: displayCoverUrl.isNotEmpty
                      ? HazukiCachedImage(
                          url: displayCoverUrl,
                          width: 135,
                          height: 190,
                          fit: BoxFit.cover,
                          keepInMemory: true,
                        )
                      : Container(
                          width: 135,
                          height: 190,
                          color: skeletonColor,
                          child: const Icon(Icons.image_not_supported_outlined),
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
                  if (details == null) ...[
                    const SizedBox(height: 12),
                    Container(height: 14, width: 140, color: skeletonColor),
                    const SizedBox(height: 6),
                    Container(height: 14, width: 100, color: skeletonColor),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (details != null)
          Padding(
            key: favoriteRowKey,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    [
                      if (details!.likesCount.isNotEmpty)
                        l10n(
                          context,
                        ).comicDetailLikesCount(details!.likesCount),
                      if (viewsText.isNotEmpty)
                        l10n(context).comicDetailViewsCount(viewsText),
                    ].join(' / '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2.2,
                  child: FilledButton.icon(
                    onPressed: favoriteBusy
                        ? null
                        : () => onFavoriteTap(details!),
                    icon: Icon(
                      (favoriteOverride ?? details!.isFavorite)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                    label: Text(
                      (favoriteOverride ?? details!.isFavorite)
                          ? l10n(context).comicDetailUnfavorite
                          : l10n(context).comicDetailFavorite,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: (favoriteOverride ?? details!.isFavorite)
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      foregroundColor: (favoriteOverride ?? details!.isFavorite)
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            key: favoriteRowKey,
            height: 40,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        const SizedBox(height: 8),
        if (details != null)
          Row(
            key: actionButtonsKey,
            children: [
              IconButton(
                tooltip: l10n(context).comicDetailChapters,
                onPressed: () => onShowChapters(details!),
                icon: const Icon(Icons.format_list_bulleted_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onOpenReader(details!),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(_buildReaderButtonLabel(context)),
                ),
              ),
            ],
          )
        else
          Row(
            key: actionButtonsKey,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 48, color: skeletonColor)),
            ],
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
