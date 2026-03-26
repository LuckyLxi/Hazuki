part of '../../main.dart';

// ignore_for_file: unused_element

const int _comicStaticBlurredCoverCacheLimit = 24;
const int _comicStaticBlurDecodeWidth = 128;
const int _comicStaticBlurRadius = 12;
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

Uint8List _applyComicStaticBoxBlur(
  Uint8List source,
  int width,
  int height, {
  required int radius,
}) {
  if (radius <= 0 || source.isEmpty || width <= 0 || height <= 0) {
    return Uint8List.fromList(source);
  }

  final horizontal = Uint8List(source.length);
  final output = Uint8List(source.length);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final startX = math.max(0, x - radius);
      final endX = math.min(width - 1, x + radius);
      var red = 0;
      var green = 0;
      var blue = 0;
      var alpha = 0;
      var count = 0;
      for (var sampleX = startX; sampleX <= endX; sampleX++) {
        final offset = (y * width + sampleX) * 4;
        red += source[offset];
        green += source[offset + 1];
        blue += source[offset + 2];
        alpha += source[offset + 3];
        count++;
      }
      final outOffset = (y * width + x) * 4;
      horizontal[outOffset] = red ~/ count;
      horizontal[outOffset + 1] = green ~/ count;
      horizontal[outOffset + 2] = blue ~/ count;
      horizontal[outOffset + 3] = alpha ~/ count;
    }
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final startY = math.max(0, y - radius);
      final endY = math.min(height - 1, y + radius);
      var red = 0;
      var green = 0;
      var blue = 0;
      var alpha = 0;
      var count = 0;
      for (var sampleY = startY; sampleY <= endY; sampleY++) {
        final offset = (sampleY * width + x) * 4;
        red += horizontal[offset];
        green += horizontal[offset + 1];
        blue += horizontal[offset + 2];
        alpha += horizontal[offset + 3];
        count++;
      }
      final outOffset = (y * width + x) * 4;
      output[outOffset] = red ~/ count;
      output[outOffset + 1] = green ~/ count;
      output[outOffset + 2] = blue ~/ count;
      output[outOffset + 3] = alpha ~/ count;
    }
  }

  return output;
}

Future<Uint8List> _createComicStaticBlurredCover(Uint8List bytes) async {
  final codec = await instantiateImageCodec(
    bytes,
    targetWidth: _comicStaticBlurDecodeWidth,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final raw = await image.toByteData(format: ImageByteFormat.rawRgba);
  if (raw == null) {
    return bytes;
  }

  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0) {
    return bytes;
  }

  final blurredBytes = _applyComicStaticBoxBlur(
    raw.buffer.asUint8List(),
    width,
    height,
    radius: _comicStaticBlurRadius,
  );
  final buffer = await ImmutableBuffer.fromUint8List(blurredBytes);
  final descriptor = ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: PixelFormat.rgba8888,
    rowBytes: width * 4,
  );
  final outCodec = await descriptor.instantiateCodec();
  final outFrame = await outCodec.getNextFrame();
  final png = await outFrame.image.toByteData(format: ImageByteFormat.png);
  if (png == null) {
    return bytes;
  }
  return png.buffer.asUint8List();
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
  Uint8List? _blurredBytes;

  @override
  void initState() {
    super.initState();
    final cached = _takeComicStaticBlurredCover(widget.coverUrl);
    if (cached != null) {
      _blurredBytes = cached;
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
    final cached = _takeComicStaticBlurredCover(widget.coverUrl);
    if (cached != null) {
      setState(() {
        _blurredBytes = cached;
      });
      return;
    }
    setState(() {
      _blurredBytes = null;
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
        keepInMemory: false,
      );
      final blurred = await _createComicStaticBlurredCover(bytes);
      _putComicStaticBlurredCover(normalizedUrl, blurred);
      if (!mounted || widget.coverUrl.trim() != normalizedUrl) {
        return;
      }
      setState(() {
        _blurredBytes = blurred;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final normalizedUrl = widget.coverUrl.trim();

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (normalizedUrl.isNotEmpty)
            HazukiCachedImage(
              key: ValueKey('cover-base-$normalizedUrl'),
              url: normalizedUrl,
              fit: BoxFit.cover,
              keepInMemory: false,
            )
          else
            ColoredBox(color: surface),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _blurredBytes == null
                ? const SizedBox.expand(key: ValueKey('static-cover-blur-empty'))
                : Image.memory(
                    _blurredBytes!,
                    key: ValueKey('static-cover-blur-$normalizedUrl'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
          ),
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
