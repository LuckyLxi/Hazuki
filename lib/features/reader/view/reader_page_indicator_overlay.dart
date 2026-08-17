import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/view/reader_control_surface.dart';
import 'package:hazuki/features/reader/view/reader_overlay_layout.dart';
import 'package:hazuki/l10n/l10n.dart';

class ReaderPageIndicatorOverlay extends StatelessWidget {
  const ReaderPageIndicatorOverlay({
    super.key,
    required this.readerTheme,
    required this.pageIndexNotifier,
    required this.chapterIndex,
    required this.imageCount,
  });

  final ThemeData readerTheme;
  final ValueListenable<int> pageIndexNotifier;
  final int chapterIndex;
  final int imageCount;

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
        child: IgnorePointer(
          ignoring: true,
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
                return ReaderControlSurface(
                  borderRadius: 18,
                  fallbackColor: Colors.black.withValues(alpha: 0.64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
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
    );
  }
}
