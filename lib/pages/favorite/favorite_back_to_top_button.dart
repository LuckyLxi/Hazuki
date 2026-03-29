part of '../favorite_page.dart';

class _FavoriteBackToTopButton extends StatelessWidget {
  const _FavoriteBackToTopButton({
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.24),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.86,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton(
              heroTag: 'favorite_back_to_top',
              onPressed: onPressed,
              child: const Icon(Icons.vertical_align_top_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
