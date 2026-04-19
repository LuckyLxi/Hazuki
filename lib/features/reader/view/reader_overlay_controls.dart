import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

class ReaderTopControls extends StatelessWidget {
  const ReaderTopControls({
    super.key,
    required this.controlsVisible,
    required this.readerTheme,
    required this.title,
    required this.settingsTooltip,
    required this.onBackPressed,
    required this.onOpenSettingsDrawer,
  });

  final bool controlsVisible;
  final ThemeData readerTheme;
  final String title;
  final String settingsTooltip;
  final VoidCallback onBackPressed;
  final VoidCallback onOpenSettingsDrawer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: IgnorePointer(
          ignoring: !controlsVisible,
          child: AnimatedSlide(
            offset: controlsVisible ? Offset.zero : const Offset(0, -0.32),
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
                    children: [
                      IconButton(
                        onPressed: onBackPressed,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: readerTheme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: settingsTooltip,
                        onPressed: onOpenSettingsDrawer,
                        icon: const Icon(
                          Icons.tune_rounded,
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
    );
  }
}

class ReaderPageIndicatorOverlay extends StatelessWidget {
  const ReaderPageIndicatorOverlay({
    super.key,
    required this.controlsVisible,
    required this.readerTheme,
    required this.pageIndexNotifier,
    required this.chapterIndex,
    required this.imageCount,
  });

  final bool controlsVisible;
  final ThemeData readerTheme;
  final ValueListenable<int> pageIndexNotifier;
  final int chapterIndex;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: IgnorePointer(
          ignoring: true,
          child: AnimatedSlide(
            offset: controlsVisible ? const Offset(0, 0.24) : Offset.zero,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: controlsVisible ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ValueListenableBuilder<int>(
                  valueListenable: pageIndexNotifier,
                  builder: (context, pageIndex, _) {
                    final strings = l10n(context);
                    final chapter = math.max(1, chapterIndex + 1);
                    final current = math.max(
                      1,
                      math.min(pageIndex + 1, imageCount),
                    );
                    final total = math.max(imageCount, 1);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        strings.readerPageIndicator(
                          chapter.toString(),
                          current.toString(),
                          total.toString(),
                        ),
                        style: readerTheme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: IgnorePointer(
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
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
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
                                activeTrackColor:
                                    readerTheme.colorScheme.primary,
                                inactiveTrackColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                thumbColor: readerTheme.colorScheme.primary,
                                overlayColor: readerTheme.colorScheme.primary
                                    .withValues(alpha: 0.18),
                                trackHeight: 3.2,
                              ),
                              child: Slider(
                                min: 0,
                                max: maxIndex.toDouble(),
                                divisions: canDrag ? maxIndex : null,
                                value: sliderValue,
                                onChangeStart: canDrag
                                    ? onSliderChangeStart
                                    : null,
                                onChanged: canDrag ? onSliderChanged : null,
                                onChangeEnd: canDrag ? onSliderChangeEnd : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$imageCount',
                              textAlign: TextAlign.center,
                              style: readerTheme.textTheme.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              tooltip: l10n(context).comicDetailChapters,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: chapterPanelLoading
                                  ? null
                                  : onOpenChaptersPanel,
                              icon: chapterPanelLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.menu_book_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderChapterJumpOverlay extends StatelessWidget {
  const ReaderChapterJumpOverlay({
    super.key,
    required this.controlsVisible,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.previousTooltip,
    required this.nextTooltip,
  });

  final bool controlsVisible;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final String previousTooltip;
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

class ReaderZoomResetOverlay extends StatelessWidget {
  const ReaderZoomResetOverlay({
    super.key,
    required this.controlsVisible,
    required this.isZoomed,
    required this.onResetZoom,
    required this.label,
  });

  final bool controlsVisible;
  final bool isZoomed;
  final VoidCallback onResetZoom;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      bottom: controlsVisible ? 104 : 24,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          ignoring: !isZoomed,
          child: AnimatedScale(
            scale: isZoomed ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 220),
            curve: isZoomed ? Curves.easeOutBack : Curves.easeInCubic,
            child: AnimatedOpacity(
              opacity: isZoomed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: onResetZoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_out_map_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
