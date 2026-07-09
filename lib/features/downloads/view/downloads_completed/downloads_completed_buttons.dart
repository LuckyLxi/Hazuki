part of '../downloads_completed_tab.dart';

class DownloadsBackToTopButton extends StatelessWidget {
  const DownloadsBackToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      key: const ValueKey<String>('downloads_back_to_top_animation'),
      offset: visible ? Offset.zero : const Offset(1.5, 0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.82,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton(
              key: const ValueKey<String>('downloads_back_to_top_button'),
              heroTag: 'downloads_back_to_top',
              onPressed: () => unawaited(onPressed()),
              child: const Icon(Icons.vertical_align_top_rounded),
            ),
          ),
        ),
      ),
    );
  }
}
