import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

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
