import 'package:flutter/material.dart';

class HazukiStickerLoadingIndicator extends StatefulWidget {
  const HazukiStickerLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  State<HazukiStickerLoadingIndicator> createState() =>
      _HazukiStickerLoadingIndicatorState();
}

class _HazukiStickerLoadingIndicatorState
    extends State<HazukiStickerLoadingIndicator>
    with SingleTickerProviderStateMixin {
  static const int _frameCount = 49;
  static const Duration _loopDuration = Duration(milliseconds: 1600);
  static final List<String> _frames = List<String>.generate(
    _frameCount,
    (index) =>
        'assets/stickers/loading/frame_${(index + 1).toString().padLeft(3, '0')}.png',
  );

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _loopDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetSize = (widget.size * dpr).clamp(1, 1024).toInt();
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final frameIndex =
                (_controller.value * _frameCount).floor() % _frameCount;
            return Image.asset(
              _frames[frameIndex],
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              cacheWidth: targetSize,
              cacheHeight: targetSize,
            );
          },
        ),
      ),
    );
  }
}
