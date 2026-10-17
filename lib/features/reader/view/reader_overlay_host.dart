import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/view/reader_control_motion.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

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
    final overlays = <Widget>[
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: !runtimeState.controlsVisible,
          child: ReaderControlSlide(
            offset: runtimeState.controlsVisible
                ? Offset.zero
                : const Offset(0, -1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            child: buildReaderTopControls(
              context: context,
              runtimeState: runtimeState,
              readerTheme: readerTheme,
              title: title,
              onBackPressed: onBackPressed,
              onOpenSettingsDrawer: onOpenSettingsDrawer,
            ),
          ),
        ),
      ),
      if (runtimeState.pageIndicator)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ReaderControlSlide(
            offset: runtimeState.controlsVisible
                ? const Offset(0, 1)
                : Offset.zero,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            child: buildReaderPageIndicator(
              runtimeState: runtimeState,
              readerTheme: readerTheme,
              chapterIndex: chapterIndex,
            ),
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
    ];
    // Sliding controls must not repaint the comic or the surrounding scaffold.
    // Keep the glass live: repaint boundaries retain display lists, rather than
    // taking a background snapshot that would become stale on page changes.
    final content = RepaintBoundary(child: child);
    final controls = Positioned.fill(
      child: RepaintBoundary(child: Stack(children: overlays)),
    );
    if (!HazukiLiquidGlass.isAvailable) {
      return Stack(children: [content, controls]);
    }
    // Keep reading content below all control surfaces. The outer Material
    // scaffold continues to own the settings drawer and keyboard focus.
    return GlassScaffold(
      backgroundColor: readerTheme.colorScheme.surface,
      enableBackgroundSampling: false,
      resizeToAvoidBottomInset: false,
      edgeFade: false,
      body: content,
      bodyOverlays: [controls],
    );
  }
}
