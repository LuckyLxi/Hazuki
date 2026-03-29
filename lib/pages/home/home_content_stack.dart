import 'package:flutter/material.dart';

class HomeContentStack extends StatelessWidget {
  const HomeContentStack({
    super.key,
    required this.currentIndex,
    required this.discoverChild,
    required this.favoriteChild,
  });

  final int currentIndex;
  final Widget discoverChild;
  final Widget favoriteChild;

  @override
  Widget build(BuildContext context) {
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
                  child: discoverChild,
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
                offset: currentIndex == 1
                    ? Offset.zero
                    : const Offset(0.04, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: currentIndex == 1 ? 1 : 0,
                  child: favoriteChild,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
