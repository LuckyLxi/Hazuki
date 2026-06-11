import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'downloads_cover_widgets.dart';
import 'downloads_shell_widgets.dart';

class DownloadsCompletedTab extends StatefulWidget {
  const DownloadsCompletedTab({
    super.key,
    required this.comics,
    required this.active,
    required this.selectionMode,
    required this.scanning,
    required this.selectedCount,
    required this.selectedComicIds,
    required this.comicsWithIntegrityIssues,
    required this.onToggleSelection,
    required this.onDeleteSelected,
    required this.onScanDownloaded,
    required this.onOpenComic,
    required this.onDeleteComic,
  });

  final List<DownloadedMangaComic> comics;
  final bool active;
  final bool selectionMode;
  final bool scanning;
  final int selectedCount;
  final Set<String> selectedComicIds;
  final Set<String> comicsWithIntegrityIssues;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  static const Duration dismissDuration = Duration(milliseconds: 320);

  @override
  State<DownloadsCompletedTab> createState() => _DownloadsCompletedTabState();
}

class _DownloadsCompletedTabState extends State<DownloadsCompletedTab> {
  final GlobalKey _stackKey = GlobalKey();
  List<_AnimatedDownloadedComicEntry> _visibleComics =
      const <_AnimatedDownloadedComicEntry>[];
  _DownloadedComicSwipeReveal? _swipeReveal;

  @override
  void initState() {
    super.initState();
    _visibleComics = widget.comics
        .map((comic) => _AnimatedDownloadedComicEntry(comic: comic))
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant DownloadsCompletedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!widget.active && oldWidget.active) ||
        (widget.selectionMode && !oldWidget.selectionMode)) {
      _swipeReveal = null;
    }
    _syncVisibleComics();
  }

  void _handleSwipeReveal(_DownloadedComicSwipeReveal reveal) {
    final activeStorageKey = _swipeReveal?.comic.storageKey;
    if (!reveal.claimActive &&
        activeStorageKey != null &&
        activeStorageKey != reveal.comic.storageKey) {
      return;
    }
    final nextReveal = reveal.progress <= precisionErrorTolerance
        ? null
        : reveal;
    setState(() {
      _swipeReveal = nextReveal;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && _swipeReveal != null) {
      setState(() {
        _swipeReveal = null;
      });
    }
    return false;
  }

  void _syncVisibleComics() {
    final nextById = <String, DownloadedMangaComic>{
      for (final comic in widget.comics) comic.storageKey: comic,
    };
    final currentById = <String, _AnimatedDownloadedComicEntry>{
      for (final entry in _visibleComics) entry.comic.storageKey: entry,
    };
    final exitingEntries =
        <({int index, _AnimatedDownloadedComicEntry entry})>[];
    final nextVisible = <_AnimatedDownloadedComicEntry>[];

    for (int i = 0; i < _visibleComics.length; i++) {
      final entry = _visibleComics[i];
      final nextComic = nextById[entry.comic.storageKey];
      if (nextComic == null) {
        final exitingEntry = entry.copyWith(exiting: true, entering: false);
        exitingEntries.add((index: i, entry: exitingEntry));
        if (!entry.exiting) {
          _scheduleRemoval(entry.comic.storageKey);
        }
        continue;
      }
    }

    for (final comic in widget.comics) {
      final currentEntry = currentById[comic.storageKey];
      if (currentEntry == null) {
        nextVisible.add(
          _AnimatedDownloadedComicEntry(comic: comic, entering: true),
        );
        _scheduleEnterComplete(comic.storageKey);
        continue;
      }
      nextVisible.add(
        _AnimatedDownloadedComicEntry(
          comic: comic,
          entering: currentEntry.entering,
        ),
      );
    }

    for (final exiting in exitingEntries) {
      final index = exiting.index.clamp(0, nextVisible.length);
      nextVisible.insert(index, exiting.entry);
    }

    if (!_sameEntries(_visibleComics, nextVisible)) {
      setState(() {
        _visibleComics = nextVisible;
      });
    }
  }

  bool _sameEntries(
    List<_AnimatedDownloadedComicEntry> current,
    List<_AnimatedDownloadedComicEntry> next,
  ) {
    if (current.length != next.length) {
      return false;
    }
    for (int i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.comic != b.comic ||
          a.exiting != b.exiting ||
          a.entering != b.entering) {
        return false;
      }
    }
    return true;
  }

  void _scheduleEnterComplete(String storageKey) {
    Future<void>.delayed(DownloadsCompletedTab.dismissDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visibleComics = _visibleComics
            .map((entry) {
              if (entry.comic.storageKey != storageKey || entry.exiting) {
                return entry;
              }
              return entry.copyWith(entering: false);
            })
            .toList(growable: false);
      });
    });
  }

  void _scheduleRemoval(String storageKey) {
    Future<void>.delayed(DownloadsCompletedTab.dismissDuration, () {
      if (!mounted) {
        return;
      }
      if (widget.comics.any((comic) => comic.storageKey == storageKey)) {
        return;
      }
      setState(() {
        _visibleComics = _visibleComics
            .where((entry) => entry.comic.storageKey != storageKey)
            .toList(growable: false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _visibleComics.isEmpty
        ? Center(child: Text(l10n(context).downloadsEmptyDownloaded))
        : NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _visibleComics.length,
              itemBuilder: (context, index) {
                final entry = _visibleComics[index];
                return _AnimatedDownloadedComicCard(
                  key: ValueKey<String>('downloaded_${entry.comic.storageKey}'),
                  entry: entry,
                  bottomSpacing: index == _visibleComics.length - 1 ? 0 : 12,
                  selectionMode: widget.selectionMode,
                  selected: widget.selectedComicIds.contains(
                    entry.comic.storageKey,
                  ),
                  hasIntegrityIssue: widget.comicsWithIntegrityIssues.contains(
                    entry.comic.storageKey,
                  ),
                  activeSwipeStorageKey: _swipeReveal?.comic.storageKey,
                  swipeRevealStackKey: _stackKey,
                  onSwipeRevealChanged: _handleSwipeReveal,
                  onToggleSelection: widget.onToggleSelection,
                  onOpenComic: widget.onOpenComic,
                );
              },
            ),
          );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: content),
        if (_swipeReveal case final reveal?)
          Positioned(
            top: reveal.top,
            right:
                -_DownloadedComicEdgeDeleteButton.width * (1 - reveal.progress),
            height: reveal.height,
            child: _DownloadedComicEdgeDeleteButton(
              comic: reveal.comic,
              enabled: reveal.revealed,
              onDeleteComic: widget.onDeleteComic,
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16 + bottomInset,
          child: DownloadsScanButton(
            selectionMode: widget.selectionMode,
            scanning: widget.scanning,
            selectedCount: widget.selectedCount,
            onDeleteSelected: widget.onDeleteSelected,
            onScanDownloaded: widget.onScanDownloaded,
          ),
        ),
      ],
    );
  }
}

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
  });

  final _AnimatedDownloadedComicEntry entry;
  final double bottomSpacing;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final String? activeSwipeStorageKey;
  final GlobalKey swipeRevealStackKey;
  final ValueChanged<_DownloadedComicSwipeReveal> onSwipeRevealChanged;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;

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
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              alignment: Alignment.topCenter,
              child: ClipRect(
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
        ),
      ),
    );
  }
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
  static const double _revealDistance = 42;

  late final AnimationController _controller;
  Animation<double>? _animation;
  double _offset = 0;
  bool _open = false;
  bool _closingDragIntent = false;
  int? _closedDragPointer;
  Offset? _closedDragInitialPosition;
  bool _trackingClosedLeftDrag = false;
  bool _ignoringClosedDrag = false;

  bool get _revealed => _offset < -_revealDistance / 2;

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
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  void _handleClosedDragUpdate(DragUpdateDetails details) {
    if (widget.selectionMode) {
      return;
    }
    _controller.stop();
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-_revealDistance, 0);
    });
    _reportReveal(claimActive: true);
  }

  void _handleClosedDragEnd(DragEndDetails details) {
    _animateTo(_revealed ? -_revealDistance : 0);
  }

  void _handleClosedPointerDown(PointerDownEvent event) {
    if (widget.selectionMode || _closedDragPointer != null) {
      return;
    }
    _closedDragPointer = event.pointer;
    _closedDragInitialPosition = event.position;
    _trackingClosedLeftDrag = false;
    _ignoringClosedDrag = false;
  }

  void _handleClosedPointerMove(PointerMoveEvent event) {
    if (widget.selectionMode ||
        event.pointer != _closedDragPointer ||
        _ignoringClosedDrag) {
      return;
    }
    final initialPosition = _closedDragInitialPosition;
    if (initialPosition == null) {
      return;
    }
    if (!_trackingClosedLeftDrag) {
      final delta = event.position - initialPosition;
      if (delta.distance < kTouchSlop) {
        return;
      }
      if (delta.dx >= 0 || delta.dx.abs() <= delta.dy.abs()) {
        _ignoringClosedDrag = true;
        return;
      }
      _trackingClosedLeftDrag = true;
      _controller.stop();
    }
    _handleClosedDragUpdate(
      DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.delta,
        primaryDelta: event.delta.dx,
        globalPosition: event.position,
        localPosition: event.localPosition,
      ),
    );
  }

  void _handleClosedPointerEnd(PointerEvent event) {
    if (event.pointer != _closedDragPointer) {
      return;
    }
    final trackedLeftDrag = _trackingClosedLeftDrag;
    _closedDragPointer = null;
    _closedDragInitialPosition = null;
    _trackingClosedLeftDrag = false;
    _ignoringClosedDrag = false;
    if (trackedLeftDrag) {
      _handleClosedDragEnd(DragEndDetails());
    }
  }

  void _handleRevealedDragUpdate(DragUpdateDetails details) {
    if (widget.selectionMode) {
      return;
    }
    _controller.stop();
    if (details.delta.dx > 0) {
      _closingDragIntent = true;
    }
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-_revealDistance, 0);
    });
    _reportReveal(claimActive: true);
  }

  void _handleRevealedDragEnd(DragEndDetails details) {
    if (widget.selectionMode) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final close = _closingDragIntent || velocity > 250;
    _closingDragIntent = false;
    _animateTo(close ? 0 : -_revealDistance);
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
                onTap: () => _animateTo(0),
                onHorizontalDragStart: (_) {
                  _closingDragIntent = false;
                },
                onHorizontalDragUpdate: _handleRevealedDragUpdate,
                onHorizontalDragEnd: _handleRevealedDragEnd,
                child: _DownloadedComicCard(
                  bottomSpacing: 0,
                  child: AbsorbPointer(child: widget.child),
                ),
              )
            : Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handleClosedPointerDown,
                onPointerMove: _handleClosedPointerMove,
                onPointerUp: _handleClosedPointerEnd,
                onPointerCancel: _handleClosedPointerEnd,
                child: _DownloadedComicCard(
                  bottomSpacing: 0,
                  child: widget.child,
                ),
              ),
      ),
    );
  }
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
  });

  final DownloadedMangaComic comic;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;

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
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (selectionMode) {
              onToggleSelection(comic.storageKey);
            } else {
              onOpenComic(comic);
            }
          },
          onLongPress: () => onToggleSelection(comic.storageKey),
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
                            l10n(
                              context,
                            ).downloadsChapterCount('${comic.chapters.length}'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectionMode) ...[
                      const SizedBox(width: 8),
                      _DownloadedComicSelectionIndicator(selected: selected),
                    ],
                  ],
                ),
              ),
              if (hasIntegrityIssue)
                _IntegrityWarningBanner(
                  message: l10n(context).downloadsIntegrityWarning,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDownloadedComicEntry {
  const _AnimatedDownloadedComicEntry({
    required this.comic,
    this.entering = false,
    this.exiting = false,
  });

  final DownloadedMangaComic comic;
  final bool entering;
  final bool exiting;

  _AnimatedDownloadedComicEntry copyWith({
    DownloadedMangaComic? comic,
    bool? entering,
    bool? exiting,
  }) {
    return _AnimatedDownloadedComicEntry(
      comic: comic ?? this.comic,
      entering: entering ?? this.entering,
      exiting: exiting ?? this.exiting,
    );
  }
}

class _IntegrityWarningBanner extends StatelessWidget {
  const _IntegrityWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: const Color(0xFFB71C1C),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadedComicSelectionIndicator extends StatelessWidget {
  const _DownloadedComicSelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: AnimatedContainer(
          key: ValueKey<bool>(selected),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.16)
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1.4,
            ),
          ),
          child: Icon(
            selected ? Icons.check_rounded : Icons.circle_outlined,
            size: selected ? 18 : 20,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
