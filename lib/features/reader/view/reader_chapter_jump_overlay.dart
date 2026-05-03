import 'package:flutter/material.dart';

class ReaderChapterJumpOverlay extends StatelessWidget {
  const ReaderChapterJumpOverlay({
    super.key,
    required this.controlsVisible,
    required this.onPreviousChapter,
    required this.onFavorite,
    required this.onComments,
    required this.onNextChapter,
    required this.previousTooltip,
    required this.favoriteTooltip,
    required this.commentsTooltip,
    required this.nextTooltip,
  });

  final bool controlsVisible;
  final VoidCallback onPreviousChapter;
  final VoidCallback onFavorite;
  final VoidCallback onComments;
  final VoidCallback onNextChapter;
  final String previousTooltip;
  final String favoriteTooltip;
  final String commentsTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
        child: Align(
          alignment: Alignment.bottomRight,
          child: IgnorePointer(
            ignoring: !controlsVisible,
            child: AnimatedSlide(
              offset: controlsVisible ? Offset.zero : const Offset(0.24, 0.16),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedScale(
                scale: controlsVisible ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.64),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: previousTooltip,
                          onPressed: onPreviousChapter,
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: favoriteTooltip,
                          onPressed: onFavorite,
                          icon: const Icon(
                            Icons.favorite_border_rounded,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: commentsTooltip,
                          onPressed: onComments,
                          icon: const Icon(
                            Icons.mode_comment_outlined,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: nextTooltip,
                          onPressed: onNextChapter,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
