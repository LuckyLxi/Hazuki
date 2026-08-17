import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/view/reader_control_surface.dart';
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
    required this.onSliderPointerDown,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    this.onOpenChaptersPanel,
    this.onPreviousChapter,
    this.onFavorite,
    this.onComments,
    this.onNextChapter,
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
  final ValueChanged<double>? onSliderPointerDown;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onSliderChangeEnd;
  final VoidCallback? onOpenChaptersPanel;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onFavorite;
  final VoidCallback? onComments;
  final VoidCallback? onNextChapter;
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
    final hiddenControlsOffset =
        ReaderOverlayLayout.bottomControlsHeight +
        MediaQuery.paddingOf(context).bottom +
        ReaderOverlayLayout.bottomControlsBottomPadding;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReaderOverlayLayout.edgePadding,
          0,
          ReaderOverlayLayout.edgePadding,
          ReaderOverlayLayout.bottomControlsBottomPadding,
        ),
        child: _ReaderResetZoomTransitionLayout(
          controlsVisible: controlsVisible,
          isZoomed: isZoomed,
          label: resetZoomLabel,
          onPressed: onResetZoom,
          controlBarBuilder:
              (controlBarKey, resetZoomTargetKey, resetZoomTransitionProgress) {
                return Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: TweenAnimationBuilder<double>(
                        key: const ValueKey<String>(
                          'reader_bottom_control_bar_transition',
                        ),
                        tween: Tween<double>(
                          begin: controlsVisible ? 0 : hiddenControlsOffset,
                          end: controlsVisible ? 0 : hiddenControlsOffset,
                        ),
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutBack,
                        builder: (context, offsetY, child) =>
                            Transform.translate(
                              offset: Offset(0, offsetY),
                              child: child,
                            ),
                        child: IgnorePointer(
                          ignoring: !controlsVisible,
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
                                  sliderDragging
                                      ? sliderValue.round()
                                      : pageIndex,
                                  maxIndex,
                                ),
                              );
                              final canDrag = imageCount > 1;
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  return _ReaderUnifiedControlBar(
                                    key: controlBarKey,
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
                                    onSliderPointerDown: onSliderPointerDown,
                                    onSliderChanged: onSliderChanged,
                                    onSliderChangeEnd: onSliderChangeEnd,
                                    onPreviousChapter: onPreviousChapter,
                                    onOpenChaptersPanel: onOpenChaptersPanel,
                                    onFavorite: onFavorite,
                                    onComments: onComments,
                                    onNextChapter: onNextChapter,
                                    onResetZoom: onResetZoom,
                                    resetZoomTargetKey: resetZoomTargetKey,
                                    resetZoomTransitionProgress:
                                        resetZoomTransitionProgress,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

typedef _ReaderControlBarBuilder =
    Widget Function(
      GlobalKey controlBarKey,
      GlobalKey resetZoomTargetKey,
      ValueListenable<double> resetZoomTransitionProgress,
    );

class _ReaderResetZoomTransitionLayout extends StatefulWidget {
  const _ReaderResetZoomTransitionLayout({
    required this.controlsVisible,
    required this.isZoomed,
    required this.label,
    required this.onPressed,
    required this.controlBarBuilder,
  });

  final bool controlsVisible;
  final bool isZoomed;
  final String label;
  final VoidCallback onPressed;
  final _ReaderControlBarBuilder controlBarBuilder;

  @override
  State<_ReaderResetZoomTransitionLayout> createState() =>
      _ReaderResetZoomTransitionLayoutState();
}

class _ReaderResetZoomTransitionLayoutState
    extends State<_ReaderResetZoomTransitionLayout> {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _controlBarKey = GlobalKey();
  final GlobalKey _resetZoomTargetKey = GlobalKey();
  late final ValueNotifier<double> _transitionProgress = ValueNotifier<double>(
    widget.controlsVisible ? 1 : 0,
  );

  @override
  void dispose() {
    _transitionProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height:
          ReaderOverlayLayout.hiddenResetZoomLift +
          ReaderOverlayLayout.bottomControlsButtonSize,
      child: Stack(
        key: _stackKey,
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          _ReaderFloatingResetZoomButton(
            controlsVisible: widget.controlsVisible,
            isZoomed: widget.isZoomed,
            label: widget.label,
            onPressed: widget.onPressed,
            stackKey: _stackKey,
            controlBarKey: _controlBarKey,
            resetZoomTargetKey: _resetZoomTargetKey,
            transitionProgress: _transitionProgress,
          ),
          widget.controlBarBuilder(
            _controlBarKey,
            _resetZoomTargetKey,
            _transitionProgress,
          ),
        ],
      ),
    );
  }
}

class _ReaderFloatingResetZoomButton extends StatefulWidget {
  const _ReaderFloatingResetZoomButton({
    required this.controlsVisible,
    required this.isZoomed,
    required this.label,
    required this.onPressed,
    required this.stackKey,
    required this.controlBarKey,
    required this.resetZoomTargetKey,
    required this.transitionProgress,
  });

  final bool controlsVisible;
  final bool isZoomed;
  final String label;
  final VoidCallback onPressed;
  final GlobalKey stackKey;
  final GlobalKey controlBarKey;
  final GlobalKey resetZoomTargetKey;
  final ValueNotifier<double> transitionProgress;

  @override
  State<_ReaderFloatingResetZoomButton> createState() =>
      _ReaderFloatingResetZoomButtonState();
}

class _ReaderFloatingResetZoomButtonState
    extends State<_ReaderFloatingResetZoomButton>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: widget.controlsVisible ? 1 : 0,
  );
  late final AnimationController _blendController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 180),
    value: widget.controlsVisible ? 1 : 0,
  );
  late bool _showButton = widget.isZoomed;
  final GlobalKey _floatingButtonKey = GlobalKey();
  Offset _targetDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    _blendController.addListener(_syncTransitionProgress);
    _syncTransitionProgress();
  }

  void _syncTransitionProgress() {
    widget.transitionProgress.value = _blendController.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _blendController
      ..removeListener(_syncTransitionProgress)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReaderFloatingResetZoomButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isZoomed) {
      return;
    }
    if (!oldWidget.isZoomed) {
      _controller.value = widget.controlsVisible ? 1 : 0;
      _blendController.value = widget.controlsVisible ? 1 : 0;
      if (!widget.controlsVisible) {
        setState(() => _showButton = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _captureTargetPosition();
        }
      });
      return;
    }
    if (widget.controlsVisible == oldWidget.controlsVisible) {
      return;
    }
    if (!widget.controlsVisible) {
      setState(() => _showButton = true);
    }
    _captureTargetPosition(notify: false);
    if (widget.controlsVisible) {
      _controller.forward();
      _blendController.forward();
    } else {
      _controller.reverse();
      _blendController.reverse();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _captureTargetPosition();
    });
  }

  void _captureTargetPosition({bool notify = true}) {
    final stackBox =
        widget.stackKey.currentContext?.findRenderObject() as RenderBox?;
    final controlBarBox =
        widget.controlBarKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        widget.resetZoomTargetKey.currentContext?.findRenderObject()
            as RenderBox?;
    final floatingBox =
        _floatingButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null ||
        controlBarBox == null ||
        targetBox == null ||
        floatingBox == null) {
      return;
    }

    final targetInControlBar = targetBox.localToGlobal(
      Offset.zero,
      ancestor: controlBarBox,
    );
    final targetTopLeft = Offset(
      targetInControlBar.dx,
      stackBox.size.height - controlBarBox.size.height + targetInControlBar.dy,
    );
    final sourceTopLeft = Offset(
      (stackBox.size.width - floatingBox.size.width) / 2,
      stackBox.size.height -
          ReaderOverlayLayout.hiddenResetZoomLift -
          floatingBox.size.height,
    );
    final nextDelta = targetTopLeft - sourceTopLeft;
    if (nextDelta == _targetDelta) {
      return;
    }
    if (notify) {
      setState(() => _targetDelta = nextDelta);
    } else {
      _targetDelta = nextDelta;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showButton) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: ReaderOverlayLayout.hiddenResetZoomLift,
      child: IgnorePointer(
        ignoring: widget.controlsVisible || !widget.isZoomed,
        child: AnimatedOpacity(
          opacity: widget.isZoomed ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (!widget.isZoomed && mounted) {
              setState(() => _showButton = false);
            }
          },
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_controller, _blendController]),
              builder: (context, child) {
                final reversing = _controller.status == AnimationStatus.reverse;
                final movementProgress =
                    (reversing ? Curves.easeInBack : Curves.easeOutBack)
                        .transform(_controller.value);
                return Opacity(
                  opacity: 1 - _blendController.value,
                  child: Transform.translate(
                    offset: _targetDelta * movementProgress,
                    child: KeyedSubtree(
                      key: _floatingButtonKey,
                      child: KeyedSubtree(
                        key: const ValueKey<String>(
                          'reader_floating_reset_zoom_button',
                        ),
                        child: child!,
                      ),
                    ),
                  ),
                );
              },
              child: _ReaderResetZoomButton(
                label: widget.label,
                onPressed: widget.onPressed,
                embedded: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderUnifiedControlBar extends StatelessWidget {
  const _ReaderUnifiedControlBar({
    super.key,
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
    required this.onSliderPointerDown,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onPreviousChapter,
    required this.onOpenChaptersPanel,
    required this.onFavorite,
    required this.onComments,
    required this.onNextChapter,
    required this.onResetZoom,
    required this.resetZoomTargetKey,
    required this.resetZoomTransitionProgress,
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
  final ValueChanged<double>? onSliderPointerDown;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onSliderChangeEnd;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onOpenChaptersPanel;
  final VoidCallback? onFavorite;
  final VoidCallback? onComments;
  final VoidCallback? onNextChapter;
  final VoidCallback onResetZoom;
  final GlobalKey resetZoomTargetKey;
  final ValueListenable<double> resetZoomTransitionProgress;

  @override
  Widget build(BuildContext context) {
    final hasTopActions =
        onOpenChaptersPanel != null || onFavorite != null || onComments != null;
    return ReaderControlSurface(
      borderRadius: 30,
      fallbackColor: Colors.black.withValues(alpha: 0.68),
      height: hasTopActions
          ? ReaderOverlayLayout.bottomControlsHeight
          : ReaderOverlayLayout.bottomControlsButtonSize + 24,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTopActions)
            Row(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: isZoomed
                      ? Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: KeyedSubtree(
                            key: resetZoomTargetKey,
                            child: AnimatedBuilder(
                              animation: resetZoomTransitionProgress,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: resetZoomTransitionProgress.value,
                                  child: child,
                                );
                              },
                              child: KeyedSubtree(
                                key: const ValueKey<String>(
                                  'reader_embedded_reset_zoom_button',
                                ),
                                child: _ReaderResetZoomButton(
                                  label: resetZoomLabel,
                                  onPressed: onResetZoom,
                                  embedded: true,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const Spacer(),
                if (onOpenChaptersPanel != null)
                  _ReaderBarIconButton(
                    tooltip: chaptersTooltip,
                    onPressed: chapterPanelLoading ? null : onOpenChaptersPanel,
                    loading: chapterPanelLoading,
                    icon: Icons.menu_book_rounded,
                  ),
                if (onOpenChaptersPanel != null && onFavorite != null)
                  const SizedBox(
                    width: ReaderOverlayLayout.bottomControlsIconGap,
                  ),
                if (onFavorite != null)
                  _ReaderBarIconButton(
                    tooltip: favoriteTooltip,
                    onPressed: onFavorite,
                    icon: Icons.favorite_border_rounded,
                  ),
                if ((onOpenChaptersPanel != null || onFavorite != null) &&
                    onComments != null)
                  const SizedBox(
                    width: ReaderOverlayLayout.bottomControlsIconGap,
                  ),
                if (onComments != null)
                  _ReaderBarIconButton(
                    tooltip: commentsTooltip,
                    onPressed: onComments,
                    icon: Icons.mode_comment_outlined,
                  ),
              ],
            ),
          if (hasTopActions)
            const SizedBox(height: ReaderOverlayLayout.bottomControlsRowGap),
          Row(
            children: [
              if (onPreviousChapter != null) ...[
                _ReaderBarIconButton(
                  tooltip: previousTooltip,
                  onPressed: onPreviousChapter,
                  icon: Icons.skip_previous_rounded,
                ),
                const SizedBox(
                  width: ReaderOverlayLayout.bottomControlsIconGap,
                ),
              ],
              Expanded(
                child: _ReaderProgressSlider(
                  readerTheme: readerTheme,
                  displayIndex: displayIndex,
                  imageCount: imageCount,
                  maxIndex: maxIndex,
                  sliderValue: sliderValue,
                  canDrag: canDrag,
                  onSliderChangeStart: onSliderChangeStart,
                  onSliderPointerDown: onSliderPointerDown,
                  onSliderChanged: onSliderChanged,
                  onSliderChangeEnd: onSliderChangeEnd,
                ),
              ),
              if (onNextChapter != null) ...[
                const SizedBox(
                  width: ReaderOverlayLayout.bottomControlsIconGap,
                ),
                _ReaderBarIconButton(
                  tooltip: nextTooltip,
                  onPressed: onNextChapter,
                  icon: Icons.skip_next_rounded,
                ),
              ],
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
    required this.onSliderPointerDown,
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
  final ValueChanged<double>? onSliderPointerDown;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: canDrag
                    ? (event) {
                        final width = constraints.maxWidth;
                        if (width <= 0) {
                          return;
                        }
                        final ratio = (event.localPosition.dx / width).clamp(
                          0.0,
                          1.0,
                        );
                        onSliderPointerDown?.call(ratio * maxIndex);
                      }
                    : null,
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
                    divisions: null,
                    value: sliderValue,
                    onChangeStart: canDrag ? onSliderChangeStart : null,
                    onChanged: canDrag ? onSliderChanged : null,
                    onChangeEnd: canDrag ? onSliderChangeEnd : null,
                  ),
                ),
              );
            },
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
    final button = Material(
      color: embedded
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
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
    if (embedded) {
      return button;
    }
    return ReaderControlSurface(
      borderRadius: 24,
      fallbackColor: Colors.black.withValues(alpha: 0.72),
      child: button,
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
