part of '../../main.dart';

// ignore_for_file: unused_element

class _ComicCoverActionsSheet extends StatelessWidget {
  const _ComicCoverActionsSheet({required this.onSavePressed});

  final VoidCallback onSavePressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n(context).comicDetailSaveImage),
            onTap: () {
              Navigator.of(context).pop();
              onSavePressed();
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: Text(l10n(context).commonCancel),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ComicBlurredCoverBackground extends StatelessWidget {
  const _ComicBlurredCoverBackground({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (coverUrl.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 50,
                sigmaY: 50,
                tileMode: TileMode.clamp,
              ),
              child: HazukiCachedImage(
                url: coverUrl,
                fit: BoxFit.cover,
                keepInMemory: false,
              ),
            )
          else
            ColoredBox(color: surface),
          ColoredBox(color: surface.withValues(alpha: 0.2)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicCoverPreviewPage extends StatelessWidget {
  const _ComicCoverPreviewPage({
    required this.imageUrl,
    required this.heroTag,
    required this.onLongPress,
  });

  final String imageUrl;
  final String heroTag;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 32,
                ),
                child: Hero(
                  tag: heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: HazukiCachedImage(
                          url: imageUrl,
                          fit: BoxFit.contain,
                          loading: Container(
                            width: 220,
                            height: 300,
                            color: placeholderColor,
                          ),
                          error: Container(
                            width: 220,
                            height: 300,
                            color: placeholderColor,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
