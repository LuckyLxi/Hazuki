import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/view/reader_overlay_layout.dart';

class ReaderBottomControls extends StatelessWidget {
  const ReaderBottomControls({
    super.key,
    required this.controlsVisible,
    required this.readerTheme,
    required this.pageIndexNotifier,
    required this.sliderDragging,
    required this.sliderDragValue,
    required this.imageCount,
    required this.chapterPanelLoading,
    required this.onSliderChangeStart,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onOpenChaptersPanel,
    required this.onPreviousChapter,
    this.onFavorite,
    required this.onComments,
    required this.onNextChapter,
    required this.onResetZoom,
    required this.isZoomed,
    required this.previousTooltip,
    required this.chaptersTooltip,
    required this.favoriteTooltip,
    required this.commentsTooltip,
    required this.nextTooltip,
    required this.resetZoomLabel,
  });

  final bool controlsVisible;
  final ThemeData readerTheme;
  final ValueListenable<int> pageIndexNotifier;
  final bool sliderDragging;
  final double sliderDragValue;
  final int imageCount;
  final bool chapterPanelLoading;
  final ValueChanged<double>? onSliderChangeStart;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onSliderChangeEnd;
  final VoidCallback onOpenChaptersPanel;
  final VoidCallback onPreviousChapter;
  final VoidCallback? onFavorite;
  final VoidCallback onComments;
  final VoidCallback onNextChapter;
  final VoidCallback onResetZoom;
  final bool isZoomed;
  final String previousTooltip;
  final String chaptersTooltip;
  final String favoriteTooltip;
  final String commentsTooltip;
  final String nextTooltip;
  final String resetZoomLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReaderOverlayLayout.edgePadding,
          0,
          ReaderOverlayLayout.edgePadding,
          ReaderOverlayLayout.bottomControlsBottomPadding,
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            IgnorePointer(
              ignoring: controlsVisible || !isZoomed,
              child: AnimatedAlign(
                alignment: controlsVisible
                    ? Alignment.bottomLeft
                    : Alignment.bottomCenter,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: AnimatedPadding(
                  padding: EdgeInsets.only(
                    bottom: controlsVisible
                        ? ReaderOverlayLayout.bottomControlsHeight -
                              ReaderOverlayLayout.bottomControlsButtonSize -
                              8
                        : ReaderOverlayLayout.hiddenResetZoomLift,
                  ),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: !controlsVisible && isZoomed ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _ReaderResetZoomButton(
                      label: resetZoomLabel,
                      onPressed: onResetZoom,
                      embedded: false,
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !controlsVisible,
              child: AnimatedSlide(
                offset: controlsVisible ? Offset.zero : const Offset(0, 0.36),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedScale(
                  scale: controlsVisible ? 1.0 : 0.96,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: ValueListenableBuilder<int>(
                      valueListenable: pageIndexNotifier,
                      builder: (context, pageIndex, _) {
                        final maxIndex = math.max(imageCount - 1, 0);
                        final rawSliderValue = sliderDragging
                            ? sliderDragValue
                            : pageIndex.toDouble();
                        final sliderValue = math.min(
                          math.max(rawSliderValue, 0.0),
                          maxIndex.toDouble(),
                        );
                        final displayIndex = math.max(
                          0,
                          math.min(
                            sliderDragging ? sliderValue.round() : pageIndex,
                            maxIndex,
                          ),
                        );
                        final canDrag = imageCount > 1;
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return _ReaderUnifiedControlBar(
                              readerTheme: readerTheme,
                              displayIndex: displayIndex,
                              imageCount: imageCount,
                              maxIndex: maxIndex,
                              sliderValue: sliderValue,
                              canDrag: canDrag,
                              isZoomed: isZoomed,
                              chapterPanelLoading: chapterPanelLoading,
                              previousTooltip: previousTooltip,
                              chaptersTooltip: chaptersTooltip,
                              favoriteTooltip: favoriteTooltip,
                              commentsTooltip: commentsTooltip,
                              nextTooltip: nextTooltip,
                              resetZoomLabel: resetZoomLabel,
                              onSliderChangeStart: onSliderChangeStart,
                              onSliderChanged: onSliderChanged,
                              onSliderChangeEnd: onSliderChangeEnd,
                              onPreviousChapter: onPreviousChapter,
                              onOpenChaptersPanel: onOpenChaptersPanel,
                              onFavorite: onFavorite,
                              onComments: onComments,
                              onNextChapter: onNextChapter,
                              onResetZoom: onResetZoom,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderUnifiedControlBar extends StatelessWidget {
  const _ReaderUnifiedControlBar({
    required this.readerTheme,
    required this.displayIndex,
    required this.imageCount,
    required this.maxIndex,
    required this.sliderValue,
    required this.canDrag,
    required this.isZoomed,
    required this.chapterPanelLoading,
    required this.previousTooltip,
    required this.chaptersTooltip,
    required this.favoriteTooltip,
    required this.commentsTooltip,
    required this.nextTooltip,
    required this.resetZoomLabel,
    required this.onSliderChangeStart,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onPreviousChapter,
    required this.onOpenChaptersPanel,
    required this.onFavorite,
    required this.onComments,
    required this.onNextChapter,
    required this.onResetZoom,
  });

  final ThemeData readerTheme;
  final int displayIndex;
  final int imageCount;
  final int maxIndex;
  final double sliderValue;
  final bool canDrag;
  final bool isZoomed;
  final bool chapterPanelLoading;
  final String previousTooltip;
  final String chaptersTooltip;
  final String favoriteTooltip;
  final String commentsTooltip;
  final String nextTooltip;
  final String resetZoomLabel;
  final ValueChanged<double>? onSliderChangeStart;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onSliderChangeEnd;
  final VoidCallback onPreviousChapter;
  final VoidCallback onOpenChaptersPanel;
  final VoidCallback? onFavorite;
  final VoidCallback onComments;
  final VoidCallback onNextChapter;
  final VoidCallback onResetZoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ReaderOverlayLayout.bottomControlsHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: isZoomed
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _ReaderResetZoomButton(
                          label: resetZoomLabel,
                          onPressed: onResetZoom,
                          embedded: true,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const Spacer(),
              _ReaderBarIconButton(
                tooltip: chaptersTooltip,
                onPressed: chapterPanelLoading ? null : onOpenChaptersPanel,
                loading: chapterPanelLoading,
                icon: Icons.menu_book_rounded,
              ),
              const SizedBox(width: ReaderOverlayLayout.bottomControlsIconGap),
              _ReaderBarIconButton(
                tooltip: favoriteTooltip,
                onPressed: onFavorite,
                icon: Icons.favorite_border_rounded,
              ),
              const SizedBox(width: ReaderOverlayLayout.bottomControlsIconGap),
              _ReaderBarIconButton(
                tooltip: commentsTooltip,
                onPressed: onComments,
                icon: Icons.mode_comment_outlined,
              ),
            ],
          ),
          const SizedBox(height: ReaderOverlayLayout.bottomControlsRowGap),
          Row(
            children: [
              _ReaderBarIconButton(
                tooltip: previousTooltip,
                onPressed: onPreviousChapter,
                icon: Icons.skip_previous_rounded,
              ),
              const SizedBox(width: ReaderOverlayLayout.bottomControlsIconGap),
              Expanded(
                child: _ReaderProgressSlider(
                  readerTheme: readerTheme,
                  displayIndex: displayIndex,
                  imageCount: imageCount,
                  maxIndex: maxIndex,
                  sliderValue: sliderValue,
                  canDrag: canDrag,
                  onSliderChangeStart: onSliderChangeStart,
                  onSliderChanged: onSliderChanged,
                  onSliderChangeEnd: onSliderChangeEnd,
                ),
              ),
              const SizedBox(width: ReaderOverlayLayout.bottomControlsIconGap),
              _ReaderBarIconButton(
                tooltip: nextTooltip,
                onPressed: onNextChapter,
                icon: Icons.skip_next_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReaderProgressSlider extends StatelessWidget {
  const _ReaderProgressSlider({
    required this.readerTheme,
    required this.displayIndex,
    required this.imageCount,
    required this.maxIndex,
    required this.sliderValue,
    required this.canDrag,
    required this.onSliderChangeStart,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
  });

  final ThemeData readerTheme;
  final int displayIndex;
  final int imageCount;
  final int maxIndex;
  final double sliderValue;
  final bool canDrag;
  final ValueChanged<double>? onSliderChangeStart;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onSliderChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '${displayIndex + 1}',
            textAlign: TextAlign.center,
            style: readerTheme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: readerTheme.colorScheme.primary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
              thumbColor: readerTheme.colorScheme.primary,
              overlayColor: readerTheme.colorScheme.primary.withValues(
                alpha: 0.18,
              ),
              trackHeight: 3.2,
            ),
            child: Slider(
              min: 0,
              max: maxIndex.toDouble(),
              divisions: canDrag ? maxIndex : null,
              value: sliderValue,
              onChangeStart: canDrag ? onSliderChangeStart : null,
              onChanged: canDrag ? onSliderChanged : null,
              onChangeEnd: canDrag ? onSliderChangeEnd : null,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$imageCount',
            textAlign: TextAlign.center,
            style: readerTheme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderResetZoomButton extends StatelessWidget {
  const _ReaderResetZoomButton({
    required this.label,
    required this.onPressed,
    required this.embedded,
  });

  final String label;
  final VoidCallback onPressed;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: !embedded
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: SizedBox(
          height: ReaderOverlayLayout.bottomControlsButtonSize,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.zoom_out_map_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderBarIconButton extends StatelessWidget {
  const _ReaderBarIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.loading = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: ReaderOverlayLayout.bottomControlsButtonSize,
        height: ReaderOverlayLayout.bottomControlsButtonSize,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.standard,
          onPressed: onPressed,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}
