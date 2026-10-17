import 'package:flutter/material.dart';

class HomeContentStack extends StatefulWidget {
  const HomeContentStack({
    super.key,
    required this.currentIndex,
    required this.discoverChild,
    required this.favoriteChild,
    this.onTransitionChanged,
  });

  final int currentIndex;
  final Widget discoverChild;
  final Widget favoriteChild;

  /// Reports tab changes and completion of the longer slide transition.
  final ValueChanged<bool>? onTransitionChanged;

  @override
  State<HomeContentStack> createState() => _HomeContentStackState();
}

class _HomeContentStackState extends State<HomeContentStack> {
  @override
  void didUpdateWidget(HomeContentStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      widget.onTransitionChanged?.call(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.currentIndex;
    return Stack(
      children: [
        Positioned.fill(
          child: HeroMode(
            enabled: currentIndex == 0,
            child: IgnorePointer(
              ignoring: currentIndex != 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                offset: currentIndex == 0
                    ? Offset.zero
                    : const Offset(-0.04, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: currentIndex == 0 ? 1 : 0,
                  child: RepaintBoundary(
                    key: const ValueKey('home-discover-repaint-boundary'),
                    child: widget.discoverChild,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: HeroMode(
            enabled: currentIndex == 1,
            child: IgnorePointer(
              ignoring: currentIndex != 1,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                // Both slides finish together, after the shorter opacity
                // animations. Report once, including after rapid retargets.
                onEnd: () => widget.onTransitionChanged?.call(false),
                offset: currentIndex == 1 ? Offset.zero : const Offset(0.04, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: currentIndex == 1 ? 1 : 0,
                  child: RepaintBoundary(
                    key: const ValueKey('home-favorite-repaint-boundary'),
                    child: widget.favoriteChild,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
