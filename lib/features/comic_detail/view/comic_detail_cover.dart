part of 'comic_detail_page.dart';

// ignore_for_file: unused_element

const int _comicStaticBlurredCoverCacheLimit = 24;
final Map<String, Uint8List> _comicStaticBlurredCoverCache =
    <String, Uint8List>{};

Uint8List? _takeComicStaticBlurredCover(String url) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty) {
    return null;
  }
  final bytes = _comicStaticBlurredCoverCache[normalizedUrl];
  if (bytes == null) {
    return null;
  }
  _comicStaticBlurredCoverCache.remove(normalizedUrl);
  _comicStaticBlurredCoverCache[normalizedUrl] = bytes;
  return bytes;
}

void _putComicStaticBlurredCover(String url, Uint8List bytes) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty || bytes.isEmpty) {
    return;
  }
  _comicStaticBlurredCoverCache.remove(normalizedUrl);
  _comicStaticBlurredCoverCache[normalizedUrl] = bytes;
  while (_comicStaticBlurredCoverCache.length >
      _comicStaticBlurredCoverCacheLimit) {
    _comicStaticBlurredCoverCache.remove(
      _comicStaticBlurredCoverCache.keys.first,
    );
  }
}

Uint8List? _takeBackgroundCoverBytes(String url) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty) {
    return null;
  }
  return _takeComicStaticBlurredCover(normalizedUrl) ??
      takeHazukiWidgetImageMemory(normalizedUrl);
}

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

class _ComicBlurredCoverBackground extends StatefulWidget {
  const _ComicBlurredCoverBackground({required this.coverUrl});

  final String coverUrl;

  @override
  State<_ComicBlurredCoverBackground> createState() =>
      _ComicBlurredCoverBackgroundState();
}

class _ComicBlurredCoverBackgroundState
    extends State<_ComicBlurredCoverBackground> {
  Uint8List? _coverBytes;
  bool _showBackground = false;

  @override
  void initState() {
    super.initState();
    final cached = _takeBackgroundCoverBytes(widget.coverUrl);
    if (cached != null) {
      _coverBytes = cached;
      _queueBackgroundReveal();
      return;
    }
    final normalizedUrl = widget.coverUrl.trim();
    if (normalizedUrl.isNotEmpty) {
      unawaited(_loadBlurredCover(normalizedUrl));
    }
  }

  @override
  void didUpdateWidget(covariant _ComicBlurredCoverBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl == widget.coverUrl) {
      return;
    }
    final cached = _takeBackgroundCoverBytes(widget.coverUrl);
    if (cached != null) {
      setState(() {
        _coverBytes = cached;
        _showBackground = false;
      });
      _queueBackgroundReveal();
      return;
    }
    setState(() {
      _coverBytes = null;
      _showBackground = false;
    });
    final normalizedUrl = widget.coverUrl.trim();
    if (normalizedUrl.isNotEmpty) {
      unawaited(_loadBlurredCover(normalizedUrl));
    }
  }

  Future<void> _loadBlurredCover(String normalizedUrl) async {
    try {
      final bytes = await HazukiSourceService.instance.downloadImageBytes(
        normalizedUrl,
        keepInMemory: true,
      );
      putHazukiWidgetImageMemory(normalizedUrl, bytes);
      _putComicStaticBlurredCover(normalizedUrl, bytes);
      if (!mounted || widget.coverUrl.trim() != normalizedUrl) {
        return;
      }
      setState(() {
        _coverBytes = bytes;
        _showBackground = false;
      });
      _queueBackgroundReveal();
    } catch (_) {}
  }

  void _queueBackgroundReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _coverBytes == null || _showBackground) {
        return;
      }
      setState(() {
        _showBackground = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final surface = theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;
    final hasCover = _coverBytes != null;
    final normalizedUrl = widget.coverUrl.trim();
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final cacheWidth = (mediaQuery.size.width * devicePixelRatio * 0.72)
        .round()
        .clamp(320, 1080)
        .toInt();
    final cacheHeight =
        (mediaQuery.size.height * 0.58 * devicePixelRatio * 0.72)
            .round()
            .clamp(240, 720)
            .toInt();
    final topScrim = isDark
        ? surface.withValues(alpha: 0.64)
        : const Color(0xA2FAFAFA);
    final bottomScrim = surface;
    final darkModeDim = isDark
        ? Colors.black.withValues(alpha: hasCover ? 0.18 : 0.12)
        : Colors.transparent;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: surface),
          if (hasCover)
            AnimatedOpacity(
              key: ValueKey('static-cover-blur-$normalizedUrl'),
              opacity: _showBackground ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Image.memory(
                  _coverBytes!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ColoredBox(color: darkModeDim),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  topScrim,
                  topScrim.withValues(alpha: isDark ? 0.58 : 0.52),
                  bottomScrim.withValues(alpha: isDark ? 0.96 : 0.88),
                  bottomScrim,
                ],
                stops: const [0.0, 0.32, 0.68, 0.88],
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
    final coverBorderRadius = comicCoverHeroBorderRadius(heroTag, fallback: 10);
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
              onTap: () => Navigator.of(context).pop(),
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 32,
                ),
                child: Hero(
                  tag: heroTag,
                  flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
                  placeholderBuilder: buildComicCoverHeroPlaceholder,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(coverBorderRadius),
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
    );
  }
}
