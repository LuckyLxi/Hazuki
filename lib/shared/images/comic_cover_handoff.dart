import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../widgets/cached_image_widgets.dart';
import '../ui_flags.dart';

/// Route-local artwork used only while a banner hands over to a comic cover.
class ComicCoverHandoff {
  ComicCoverHandoff({
    required this.heroTag,
    required this.url,
    required this.sourceKey,
    required this.bytes,
    this.cacheWidth,
    this.cacheHeight,
    ui.Image? decodedBanner,
  }) : _decodedBanner = decodedBanner?.clone();

  final String heroTag;
  final String url;
  final String sourceKey;
  final Uint8List bytes;
  final int? cacheWidth;
  final int? cacheHeight;
  bool coverRevealed = false;
  ui.Image? _decodedBanner;
  bool get hasDecodedBanner => _decodedBanner != null;

  void dispose() {
    _decodedBanner?.dispose();
    _decodedBanner = null;
  }

  Widget buildBanner() => _decodedBanner != null
      ? RawImage(image: _decodedBanner, fit: BoxFit.cover)
      : Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        );
}

class ComicCoverHandoffScope extends InheritedWidget {
  const ComicCoverHandoffScope({
    super.key,
    required this.handoff,
    required super.child,
  });

  final ComicCoverHandoff handoff;

  static ComicCoverHandoff? find(BuildContext context, String heroTag) {
    final handoff = context
        .getInheritedWidgetOfExactType<ComicCoverHandoffScope>()
        ?.handoff;
    return handoff?.heroTag == heroTag ? handoff : null;
  }

  @override
  bool updateShouldNotify(ComicCoverHandoffScope oldWidget) =>
      handoff != oldWidget.handoff;
}

/// Keeps the actual banner under the cover until both the route and decoded
/// cover frame are ready. Failed or missing covers leave the banner in place.
class ComicCoverHandoffImage extends StatefulWidget {
  const ComicCoverHandoffImage({
    super.key,
    required this.handoff,
    required this.coverUrl,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final ComicCoverHandoff handoff;
  final String coverUrl;
  final int cacheWidth;
  final int cacheHeight;

  @override
  State<ComicCoverHandoffImage> createState() => _ComicCoverHandoffImageState();
}

class _ComicCoverHandoffImageState extends State<ComicCoverHandoffImage> {
  bool _entranceCompleted = false;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    Widget buildImage() {
      _entranceCompleted =
          _entranceCompleted ||
          animation == null ||
          (route?.offstage != true &&
              animation.status == AnimationStatus.completed);
      return ValueListenableBuilder<bool>(
        valueListenable: hazukiNoImageModeNotifier,
        builder: (context, noImages, _) {
          if (noImages) return const SizedBox.expand();
          final banner = widget.handoff.buildBanner();
          if (widget.coverUrl.trim().isEmpty) return banner;
          return HazukiCachedImage(
            url: widget.coverUrl,
            sourceKey: widget.handoff.sourceKey,
            fit: BoxFit.cover,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
            loading: banner,
            error: banner,
            useShimmerLoading: false,
            waitForFirstFrame: true,
            animateOnLoad: true,
            animateOnCacheHit: true,
            revealEnabled: _entranceCompleted,
            loadAnimationDuration: const Duration(milliseconds: 220),
            loadAnimationBeginScale: 1,
            onRevealComplete: () => widget.handoff.coverRevealed = true,
          );
        },
      );
    }

    return animation == null
        ? buildImage()
        : ListenableBuilder(
            listenable: animation,
            builder: (_, _) => buildImage(),
          );
  }
}
