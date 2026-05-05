import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'comic_detail_cover.dart';

class ComicDetailParallaxBackground extends StatefulWidget {
  const ComicDetailParallaxBackground({
    super.key,
    required this.coverUrl,
    required this.sourceKey,
    required this.scrollController,
  });

  final String coverUrl;
  final String sourceKey;
  final ScrollController scrollController;

  @override
  State<ComicDetailParallaxBackground> createState() =>
      _ComicDetailParallaxBackgroundState();
}

class _ComicDetailParallaxBackgroundState
    extends State<ComicDetailParallaxBackground> {
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncOffset();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ComicDetailParallaxBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
    }
    _syncOffset();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    _syncOffset();
  }

  void _syncOffset() {
    if (!mounted) {
      return;
    }
    final backgroundHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.58,
      520.0,
    );
    final nextOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
              .clamp(0.0, backgroundHeight)
              .roundToDouble()
        : 0.0;
    if ((_offset - nextOffset).abs() < 1) {
      return;
    }
    setState(() {
      _offset = nextOffset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final backgroundHeight = math.min(screenHeight * 0.58, 520.0);

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: backgroundHeight,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(0, -_offset),
          child: RepaintBoundary(
            child: ComicBlurredCoverBackground(
              coverUrl: widget.coverUrl,
              sourceKey: widget.sourceKey,
            ),
          ),
        ),
      ),
    );
  }
}
