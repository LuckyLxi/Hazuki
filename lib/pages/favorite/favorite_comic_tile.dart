part of '../favorite_page.dart';

class FavoriteComicTile extends StatelessWidget {
  const FavoriteComicTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.onTap,
  });

  final ExploreComic comic;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Hero(
              tag: heroTag,
              flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: comic.cover.isEmpty
                    ? Container(
                        width: 72,
                        height: 102,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : HazukiCachedImage(
                        url: comic.cover,
                        width: 72,
                        height: 102,
                        fit: BoxFit.cover,
                        loading: Container(
                          width: 72,
                          height: 102,
                          color: colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: Container(
                          width: 72,
                          height: 102,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (comic.subTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      comic.subTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
