import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hazuki/app/navigation_tags.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

const int _comicStaticBlurredCoverCacheLimit = 24;
final Map<String, Uint8List> _comicStaticBlurredCoverCache =
    <String, Uint8List>{};

Uint8List? _takeComicStaticBlurredCover(String url, {String sourceKey = ''}) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty) {
    return null;
  }
  final cacheKey = hazukiWidgetImageMemoryKey(
    normalizedUrl,
    sourceKey: sourceKey,
  );
  final bytes =
      _comicStaticBlurredCoverCache[cacheKey] ??
      (sourceKey.trim().isNotEmpty
          ? _comicStaticBlurredCoverCache[normalizedUrl]
          : null);
  if (bytes == null) {
    return null;
  }
  _comicStaticBlurredCoverCache.remove(cacheKey);
  _comicStaticBlurredCoverCache[cacheKey] = bytes;
  return bytes;
}

void _putComicStaticBlurredCover(
  String url,
  Uint8List bytes, {
  String sourceKey = '',
}) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty || bytes.isEmpty) {
    return;
  }
  final cacheKey = hazukiWidgetImageMemoryKey(
    normalizedUrl,
    sourceKey: sourceKey,
  );
  _comicStaticBlurredCoverCache.remove(cacheKey);
  _comicStaticBlurredCoverCache[cacheKey] = bytes;
  while (_comicStaticBlurredCoverCache.length >
      _comicStaticBlurredCoverCacheLimit) {
    _comicStaticBlurredCoverCache.remove(
      _comicStaticBlurredCoverCache.keys.first,
    );
  }
}

Uint8List? _takeBackgroundCoverBytes(String url, {String sourceKey = ''}) {
  final normalizedUrl = url.trim();
  if (normalizedUrl.isEmpty) {
    return null;
  }
  return _takeComicStaticBlurredCover(normalizedUrl, sourceKey: sourceKey) ??
      takeHazukiWidgetImageMemory(normalizedUrl, sourceKey: sourceKey);
}

class ComicBlurredCoverBackground extends StatefulWidget {
  const ComicBlurredCoverBackground({
    super.key,
    required this.coverUrl,
    required this.sourceKey,
  });

  final String coverUrl;
  final String sourceKey;

  @override
  State<ComicBlurredCoverBackground> createState() =>
      _ComicBlurredCoverBackgroundState();
}

class _ComicBlurredCoverBackgroundState
    extends State<ComicBlurredCoverBackground> {
  Uint8List? _coverBytes;
  bool _showBackground = false;

  @override
  void initState() {
    super.initState();
    final cached = _takeBackgroundCoverBytes(
      widget.coverUrl,
      sourceKey: widget.sourceKey,
    );
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
  void didUpdateWidget(covariant ComicBlurredCoverBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl == widget.coverUrl &&
        oldWidget.sourceKey == widget.sourceKey) {
      return;
    }
    final cached = _takeBackgroundCoverBytes(
      widget.coverUrl,
      sourceKey: widget.sourceKey,
    );
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
        sourceKey: widget.sourceKey,
      );
      putHazukiWidgetImageMemory(
        normalizedUrl,
        bytes,
        sourceKey: widget.sourceKey,
      );
      _putComicStaticBlurredCover(
        normalizedUrl,
        bytes,
        sourceKey: widget.sourceKey,
      );
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

class ComicCoverPreviewPage extends StatelessWidget {
  const ComicCoverPreviewPage({
    super.key,
    required this.imageUrl,
    required this.sourceKey,
    required this.heroTag,
    required this.onLongPress,
  });

  final String imageUrl;
  final String sourceKey;
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
                        sourceKey: sourceKey,
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
