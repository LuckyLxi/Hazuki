import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

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
