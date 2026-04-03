import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class HazukiLoadMoreFooter extends StatefulWidget {
  const HazukiLoadMoreFooter({super.key, this.verticalPadding = 6});

  final double verticalPadding;

  @override
  State<HazukiLoadMoreFooter> createState() => _HazukiLoadMoreFooterState();
}

class _HazukiLoadMoreFooterState extends State<HazukiLoadMoreFooter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withAlpha(232),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(148),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  final iconLift = math.sin(progress * math.pi * 2) * 1.4;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(0, -iconLift),
                        child: Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      for (var index = 0; index < 3; index++) ...[
                        _AnimatedLoadDot(
                          progress: progress,
                          index: index,
                          color: index == 1
                              ? colorScheme.primary
                              : colorScheme.secondary,
                        ),
                        if (index < 2) const SizedBox(width: 6),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLoadDot extends StatelessWidget {
  const _AnimatedLoadDot({
    required this.progress,
    required this.index,
    required this.color,
  });

  final double progress;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final phase = (progress - index * 0.14) % 1;
    final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
    final scale = 0.72 + wave * 0.48;
    final opacity = 0.3 + wave * 0.7;
    final lift = 1.5 + wave * 2.2;

    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.scale(
        scale: scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha((opacity * 255).round()),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((opacity * 90).round()),
                blurRadius: 6,
              ),
            ],
          ),
          child: const SizedBox(width: 7, height: 7),
        ),
      ),
    );
  }
}

class HazukiSearchingAnimationIndicator extends StatelessWidget {
  const HazukiSearchingAnimationIndicator({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/stickers/loading/searching_animation.json',
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}

class HazukiSandyLoadingIndicator extends StatelessWidget {
  const HazukiSandyLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/stickers/loading/sandy_loading.json',
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}
