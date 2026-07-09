import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';

class ReaderOverlayHost extends StatelessWidget {
  const ReaderOverlayHost({
    super.key,
    required this.child,
    required this.runtimeState,
    required this.readerTheme,
    required this.title,
    required this.chapterIndex,
    required this.chapterPanelLoading,
    required this.updateState,
    required this.goToPage,
    required this.onBackPressed,
    required this.onOpenSettingsDrawer,
    this.onOpenChaptersPanel,
    this.onPreviousChapter,
    this.onFavorite,
    this.onComments,
    this.onNextChapter,
    required this.onResetZoom,
  });

  final Widget child;
  final ReaderRuntimeState runtimeState;
  final ThemeData readerTheme;
  final String title;
  final int chapterIndex;
  final bool chapterPanelLoading;
  final void Function(VoidCallback update) updateState;
  final Future<void> Function(int target) goToPage;
  final VoidCallback onBackPressed;
  final VoidCallback onOpenSettingsDrawer;
  final Future<void> Function()? onOpenChaptersPanel;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onFavorite;
  final VoidCallback? onComments;
  final VoidCallback? onNextChapter;
  final VoidCallback onResetZoom;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: buildReaderTopControls(
            context: context,
            runtimeState: runtimeState,
            readerTheme: readerTheme,
            title: title,
            onBackPressed: onBackPressed,
            onOpenSettingsDrawer: onOpenSettingsDrawer,
          ),
        ),
        if (runtimeState.pageIndicator)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: buildReaderPageIndicator(
              runtimeState: runtimeState,
              readerTheme: readerTheme,
              chapterIndex: chapterIndex,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: buildReaderBottomControls(
            context: context,
            runtimeState: runtimeState,
            readerTheme: readerTheme,
            chapterPanelLoading: chapterPanelLoading,
            maybeTriggerSliderHaptic: (value, {force = false}) {
              maybeTriggerReaderSliderHaptic(
                runtimeState: runtimeState,
                value: value,
                force: force,
              );
            },
            updateState: updateState,
            goToPage: goToPage,
            onOpenChaptersPanel: onOpenChaptersPanel,
            onPreviousChapter: onPreviousChapter,
            onFavorite: onFavorite,
            onComments: onComments,
            onNextChapter: onNextChapter,
            onResetZoom: onResetZoom,
          ),
        ),
      ],
    );
  }
}
