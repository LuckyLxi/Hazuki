part of '../downloads_completed_tab.dart';

class _AnimatedDownloadedComicCard extends StatelessWidget {
  const _AnimatedDownloadedComicCard({
    super.key,
    required this.entry,
    required this.bottomSpacing,
    required this.selectionMode,
    required this.selected,
    required this.hasIntegrityIssue,
    required this.activeSwipeStorageKey,
    required this.swipeRevealStackKey,
    required this.onSwipeRevealChanged,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onShowComicMenu,
  });

  final AnimatedDownloadedComicEntry entry;
  final double bottomSpacing;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final String? activeSwipeStorageKey;
  final GlobalKey swipeRevealStackKey;
  final ValueChanged<_DownloadedComicSwipeReveal> onSwipeRevealChanged;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final Future<void> Function(
    DownloadedMangaComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  onShowComicMenu;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: entry.entering ? 0 : null,
        end: entry.exiting ? 0 : 1,
      ),
      duration: DownloadsCompletedTab.dismissDuration,
      curve: entry.exiting ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (context, value, child) {
        final horizontalExitOffset = entry.exiting
            ? -(MediaQuery.sizeOf(context).width + 32) * (1 - value)
            : 0.0;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(horizontalExitOffset, 8 * (1 - value)),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              alignment: Alignment.topCenter,
              child: ClipRect(
                clipper: const _DownloadedComicVerticalAnimationClipper(),
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: value,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: _SwipeRevealDownloadedComicCard(
        comic: entry.comic,
        bottomSpacing: bottomSpacing,
        selectionMode: selectionMode,
        activeSwipeStorageKey: activeSwipeStorageKey,
        swipeRevealStackKey: swipeRevealStackKey,
        onSwipeRevealChanged: onSwipeRevealChanged,
        child: _DownloadedComicCardContent(
          comic: entry.comic,
          selectionMode: selectionMode,
          selected: selected,
          hasIntegrityIssue: hasIntegrityIssue,
          onToggleSelection: onToggleSelection,
          onOpenComic: onOpenComic,
          onShowComicMenu: onShowComicMenu,
        ),
      ),
    );
  }
}

class _DownloadedComicVerticalAnimationClipper extends CustomClipper<Rect> {
  const _DownloadedComicVerticalAnimationClipper();

  static const double _rightHorizontalOverflow = 88;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      -size.width,
      0,
      size.width + _rightHorizontalOverflow,
      size.height,
    );
  }

  @override
  bool shouldReclip(_DownloadedComicVerticalAnimationClipper oldClipper) =>
      false;
}

class _DownloadedComicCard extends StatelessWidget {
  const _DownloadedComicCard({
    required this.bottomSpacing,
    required this.child,
  });

  final double bottomSpacing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: child,
    );
  }
}

class _SwipeRevealDownloadedComicCard extends StatefulWidget {
  const _SwipeRevealDownloadedComicCard({
    required this.comic,
    required this.bottomSpacing,
    required this.selectionMode,
    required this.activeSwipeStorageKey,
    required this.swipeRevealStackKey,
    required this.onSwipeRevealChanged,
    required this.child,
  });

  final DownloadedMangaComic comic;
  final double bottomSpacing;
  final bool selectionMode;
  final String? activeSwipeStorageKey;
  final GlobalKey swipeRevealStackKey;
  final ValueChanged<_DownloadedComicSwipeReveal> onSwipeRevealChanged;
  final Widget child;

  @override
  State<_SwipeRevealDownloadedComicCard> createState() =>
      _SwipeRevealDownloadedComicCardState();
}

class _SwipeRevealDownloadedComicCardState
    extends State<_SwipeRevealDownloadedComicCard>
    with SingleTickerProviderStateMixin {
  static const double _revealDistance = _DownloadedComicEdgeDeleteButton.width;
  static const double _maxDragOvershoot = 18;
  static const double _dragOvershootResistance = 0.2;
  static const double _settleVelocity = 350;

  late final AnimationController _controller;
  Animation<double>? _animation;
  double _offset = 0;
  double? _dragPosition;
  bool _open = false;

  bool get _revealed => _offset < -_revealDistance * 0.45;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          setState(() {
            _offset = _animation!.value;
          });
          _reportReveal(claimActive: false);
        });
  }

  @override
  void didUpdateWidget(covariant _SwipeRevealDownloadedComicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionMode && !oldWidget.selectionMode) {
      _scheduleClose();
      return;
    }
    if (widget.activeSwipeStorageKey != widget.comic.storageKey &&
        oldWidget.activeSwipeStorageKey == widget.comic.storageKey) {
      _scheduleClose();
    }
  }

  void _scheduleClose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateTo(0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    final open = target < 0;
    if (_open != open) {
      setState(() {
        _open = open;
      });
    }
    final distance = (target - _offset).abs();
    final durationMillis = (120 + (100 * distance / _revealDistance))
        .round()
        .clamp(120, 220);
    _controller.duration = Duration(milliseconds: durationMillis);
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  void _handleDragStart(DragStartDetails details) {
    if (widget.selectionMode) {
      return;
    }
    _controller.stop();
    _dragPosition = _offset;
  }

  double _displayOffsetForDrag(double rawOffset) {
    if (rawOffset >= 0) {
      return 0;
    }
    if (rawOffset >= -_revealDistance) {
      return rawOffset;
    }
    final overshoot = (-rawOffset - _revealDistance) * _dragOvershootResistance;
    return -_revealDistance - overshoot.clamp(0, _maxDragOvershoot);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (widget.selectionMode) {
      return;
    }
    final dragPosition = (_dragPosition ?? _offset) + details.delta.dx;
    _dragPosition = dragPosition;
    setState(() {
      _offset = _displayOffsetForDrag(dragPosition);
    });
    _reportReveal(claimActive: true);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.selectionMode) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    _dragPosition = null;
    final open =
        velocity < -_settleVelocity ||
        (velocity <= _settleVelocity && _revealed);
    _animateTo(open ? -_revealDistance : 0);
  }

  void _reportReveal({required bool claimActive}) {
    final stackBox =
        widget.swipeRevealStackKey.currentContext?.findRenderObject()
            as RenderBox?;
    final cardBox = context.findRenderObject() as RenderBox?;
    if (stackBox == null || cardBox == null || !cardBox.hasSize) {
      return;
    }
    final top = cardBox.localToGlobal(Offset.zero, ancestor: stackBox).dy;
    widget.onSwipeRevealChanged(
      _DownloadedComicSwipeReveal(
        comic: widget.comic,
        top: top,
        height: cardBox.size.height - widget.bottomSpacing,
        progress: (-_offset / _revealDistance).clamp(0.0, 1.0),
        revealed: _open,
        claimActive: claimActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomSpacing),
      child: Transform.translate(
        offset: Offset(_offset, 0),
        child: _open
            ? GestureDetector(
                behavior: HitTestBehavior.translucent,
                dragStartBehavior: DragStartBehavior.down,
                onTap: () => _animateTo(0),
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: _DownloadedComicCard(
                  bottomSpacing: 0,
                  child: AbsorbPointer(child: widget.child),
                ),
              )
            : RawGestureDetector(
                behavior: HitTestBehavior.translucent,
                gestures: widget.selectionMode
                    ? const <Type, GestureRecognizerFactory>{}
                    : <Type, GestureRecognizerFactory>{
                        _LeftHorizontalDragGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              _LeftHorizontalDragGestureRecognizer
                            >(_LeftHorizontalDragGestureRecognizer.new, (
                              recognizer,
                            ) {
                              recognizer
                                ..dragStartBehavior = DragStartBehavior.down
                                ..onStart = _handleDragStart
                                ..onUpdate = _handleDragUpdate
                                ..onEnd = _handleDragEnd;
                            }),
                      },
                child: _DownloadedComicCard(
                  bottomSpacing: 0,
                  child: widget.child,
                ),
              ),
      ),
    );
  }
}

class _LeftHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  static const double _claimSlopFactor = 0.5;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return globalDistanceMoved <
        -computeHitSlop(pointerDeviceKind, gestureSettings) * _claimSlopFactor;
  }

  @override
  String get debugDescription => 'left horizontal drag';
}

class _DownloadedComicEdgeDeleteButton extends StatelessWidget {
  const _DownloadedComicEdgeDeleteButton({
    required this.comic,
    required this.enabled,
    required this.onDeleteComic,
  });

  static const double width = 58;

  final DownloadedMangaComic comic;
  final bool enabled;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      excluding: !enabled,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Tooltip(
          message: l10n(context).comicDetailDelete,
          child: Material(
            key: ValueKey<String>('downloaded_edge_delete_${comic.storageKey}'),
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onDeleteComic(comic),
              child: SizedBox(
                width: width,
                height: double.infinity,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.onError,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadedComicSwipeReveal {
  const _DownloadedComicSwipeReveal({
    required this.comic,
    required this.top,
    required this.height,
    required this.progress,
    required this.revealed,
    required this.claimActive,
  });

  final DownloadedMangaComic comic;
  final double top;
  final double height;
  final double progress;
  final bool revealed;
  final bool claimActive;
}

class _DownloadedComicCardContent extends StatelessWidget {
  const _DownloadedComicCardContent({
    required this.comic,
    required this.selectionMode,
    required this.selected,
    required this.hasIntegrityIssue,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onShowComicMenu,
  });

  final DownloadedMangaComic comic;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final Future<void> Function(
    DownloadedMangaComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  )
  onShowComicMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.secondaryContainer.withValues(alpha: 0.96)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.34)
              : colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Builder(
          builder: (itemContext) => GestureDetector(
            onLongPressStart: selectionMode
                ? null
                : (details) {
                    unawaited(HapticFeedback.mediumImpact());
                    unawaited(
                      onShowComicMenu(
                        comic,
                        details.globalPosition,
                        itemContext,
                      ),
                    );
                  },
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (selectionMode) {
                  onToggleSelection(comic.storageKey);
                } else {
                  onOpenComic(comic);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        DownloadedComicCover(
                          comic: comic,
                          heroTag: 'downloaded_cover_${comic.storageKey}',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comic.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (comic.subTitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  comic.subTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                l10n(context).downloadsChapterCount(
                                  '${comic.chapters.length}',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DownloadedComicSelectionSlot(
                          visible: selectionMode,
                          selected: selected,
                        ),
                      ],
                    ),
                  ),
                  if (hasIntegrityIssue)
                    DownloadedComicIntegrityWarningBanner(
                      message: l10n(context).downloadsIntegrityWarning,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
