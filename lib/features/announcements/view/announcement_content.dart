import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/announcement_service.dart';

import '../support/announcement_image_session_cache.dart';

class AnnouncementContent extends StatelessWidget {
  const AnnouncementContent({
    super.key,
    required this.announcement,
    this.imageCache,
  });

  final Announcement announcement;
  final AnnouncementImageSessionCache? imageCache;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < announcement.content.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          _AnnouncementBlock(
            block: announcement.content[index],
            imageCache: imageCache ?? AnnouncementImageSessionCache.instance,
          ),
        ],
      ],
    );
  }
}

class _AnnouncementBlock extends StatelessWidget {
  const _AnnouncementBlock({required this.block, required this.imageCache});

  final AnnouncementContentBlock block;
  final AnnouncementImageSessionCache imageCache;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      AnnouncementTextBlock(:final text) => SelectableText(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
      AnnouncementImageBlock image => _AnnouncementImage(
        image: image,
        imageCache: imageCache,
      ),
      AnnouncementLinkBlock(:final label, :final url) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => unawaited(
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(label),
        ),
      ),
    };
  }
}

class _AnnouncementImage extends StatefulWidget {
  const _AnnouncementImage({required this.image, required this.imageCache});

  final AnnouncementImageBlock image;
  final AnnouncementImageSessionCache imageCache;

  @override
  State<_AnnouncementImage> createState() => _AnnouncementImageState();
}

class _AnnouncementImageState extends State<_AnnouncementImage> {
  final _imageKey = GlobalKey();
  bool _viewerOpen = false;

  Future<void> _openViewer(BuildContext context, Uint8List bytes) async {
    final renderObject = _imageKey.currentContext?.findRenderObject();
    final sourceRect = renderObject is RenderBox && renderObject.attached
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    await _showAnnouncementImageViewer(
      context,
      bytes: bytes,
      caption: widget.image.caption,
      sourceRect: sourceRect,
      onFlightReady: () {
        if (!mounted || _viewerOpen) {
          return;
        }
        setState(() {
          _viewerOpen = true;
        });
      },
      onFlightLanding: () {
        if (!mounted || !_viewerOpen) {
          return;
        }
        setState(() {
          _viewerOpen = false;
        });
      },
    );
    if (!mounted || !_viewerOpen) {
      return;
    }
    setState(() {
      _viewerOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final colorScheme = Theme.of(context).colorScheme;
    final imageWidget = FutureBuilder<Uint8List>(
      future: widget.imageCache.load(image.url),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return TweenAnimationBuilder<double>(
            key: ValueKey<String>('announcement_image_reveal_${image.url}'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              key: ValueKey<String>(
                'announcement_image_reveal_opacity_${image.url}',
              ),
              opacity: value,
              child: Transform.scale(
                scale: 0.96 + (0.04 * value),
                alignment: Alignment.center,
                child: child,
              ),
            ),
            child: Semantics(
              button: true,
              image: true,
              label: image.caption,
              child: GestureDetector(
                key: ValueKey<String>('announcement_image_${image.url}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_openViewer(context, bytes)),
                child: Opacity(
                  key: ValueKey<String>(
                    'announcement_image_source_opacity_${image.url}',
                  ),
                  opacity: _viewerOpen ? 0 : 1,
                  child: SizedBox(
                    key: _imageKey,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Container(
            constraints: const BoxConstraints(minHeight: 120),
            color: colorScheme.surfaceContainerLow,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: colorScheme.outline),
                const SizedBox(height: 8),
                Text(
                  l10n(context).announcementImageLoadFailed,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(minHeight: 120),
          color: colorScheme.surfaceContainerLow,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      },
    );

    final ratio = image.aspectRatio;
    final constrainedImage = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: ratio == null
          ? imageWidget
          : AspectRatio(aspectRatio: ratio, child: imageWidget),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: constrainedImage,
        ),
        if (image.caption != null) ...[
          const SizedBox(height: 8),
          Text(
            image.caption!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _showAnnouncementImageViewer(
  BuildContext context, {
  required Uint8List bytes,
  required Rect? sourceRect,
  required VoidCallback onFlightReady,
  required VoidCallback onFlightLanding,
  String? caption,
}) async {
  final disposed = Completer<void>();
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _AnnouncementImageViewer(
            animation: animation,
            bytes: bytes,
            caption: caption,
            sourceRect: sourceRect,
            onFlightReady: onFlightReady,
            onFlightLanding: onFlightLanding,
            onDisposed: () {
              if (!disposed.isCompleted) {
                disposed.complete();
              }
            },
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    ),
  );
  if (!disposed.isCompleted) {
    await disposed.future;
  }
}

class _AnnouncementImageViewer extends StatefulWidget {
  const _AnnouncementImageViewer({
    required this.animation,
    required this.bytes,
    required this.sourceRect,
    required this.onFlightReady,
    required this.onFlightLanding,
    required this.onDisposed,
    this.caption,
  });

  final Animation<double> animation;
  final Uint8List bytes;
  final Rect? sourceRect;
  final VoidCallback onFlightReady;
  final VoidCallback onFlightLanding;
  final VoidCallback onDisposed;
  final String? caption;

  @override
  State<_AnnouncementImageViewer> createState() =>
      _AnnouncementImageViewerState();
}

class _AnnouncementImageViewerState extends State<_AnnouncementImageViewer>
    with SingleTickerProviderStateMixin {
  static const _doubleTapScale = 2.5;

  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _doubleTapAnimationController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(_applyDoubleTapAnimation);
  Offset _doubleTapPosition = Offset.zero;
  Matrix4 _animationStart = Matrix4.identity();
  Matrix4 _animationEnd = Matrix4.identity();
  bool _landingReported = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleRouteAnimation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onFlightReady();
      }
    });
  }

  void _handleRouteAnimation() {
    if (_landingReported ||
        widget.animation.status != AnimationStatus.reverse ||
        widget.animation.value > 0.08) {
      return;
    }
    _landingReported = true;
    widget.onFlightLanding();
  }

  void _applyDoubleTapAnimation() {
    final progress = Curves.easeOutCubic.transform(
      _doubleTapAnimationController.value,
    );
    final current = Matrix4.zero();
    for (var index = 0; index < 16; index++) {
      current[index] =
          _animationStart[index] +
          ((_animationEnd[index] - _animationStart[index]) * progress);
    }
    _transformationController.value = current;
  }

  void _handleDoubleTap() {
    _animationStart = _transformationController.value.clone();
    if (_animationStart.getMaxScaleOnAxis() > 1.01) {
      _animationEnd = Matrix4.identity();
    } else {
      _animationEnd = Matrix4.identity()
        ..[0] = _doubleTapScale
        ..[5] = _doubleTapScale
        ..[12] = -_doubleTapPosition.dx * (_doubleTapScale - 1)
        ..[13] = -_doubleTapPosition.dy * (_doubleTapScale - 1);
    }
    _doubleTapAnimationController.forward(from: 0);
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleRouteAnimation);
    widget.onDisposed();
    _doubleTapAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Material(
      key: const ValueKey<String>('announcement_image_viewer'),
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportRect = Rect.fromLTRB(
            0,
            mediaQuery.padding.top,
            constraints.maxWidth,
            constraints.maxHeight - mediaQuery.padding.bottom,
          );
          final fallbackSourceRect = Rect.fromCenter(
            center: viewportRect.center,
            width: viewportRect.width * 0.2,
            height: viewportRect.height * 0.2,
          );
          return AnimatedBuilder(
            animation: widget.animation,
            builder: (context, child) {
              final progress = Curves.easeInOutCubic.transform(
                widget.animation.value,
              );
              final movingRect = Rect.lerp(
                widget.sourceRect ?? fallbackSourceRect,
                viewportRect,
                progress,
              )!;
              final captionOpacity = const Interval(
                0.72,
                1,
                curve: Curves.easeOut,
              ).transform(progress);
              return Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.94 * progress),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: movingRect,
                    child: ClipRRect(
                      key: const ValueKey<String>(
                        'announcement_image_shared_element',
                      ),
                      borderRadius: BorderRadius.circular(16 * (1 - progress)),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        onDoubleTapDown: (details) {
                          _doubleTapPosition = details.localPosition;
                        },
                        onDoubleTap: _handleDoubleTap,
                        child: InteractiveViewer(
                          key: const ValueKey<String>(
                            'announcement_image_interactive_viewer',
                          ),
                          transformationController: _transformationController,
                          minScale: 1,
                          maxScale: 5,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox.expand(
                            child: Center(
                              child: Image.memory(
                                widget.bytes,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.caption != null)
                    PositionedDirectional(
                      start: 20,
                      end: 20,
                      bottom: mediaQuery.padding.bottom + 20,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: captionOpacity,
                          child: Text(
                            widget.caption!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 8),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
