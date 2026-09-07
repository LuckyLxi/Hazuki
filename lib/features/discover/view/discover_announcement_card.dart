import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/services/announcement_service.dart';

import 'discover_announcement_menu.dart';

class DiscoverAnnouncementAnimatedSlot extends StatefulWidget {
  const DiscoverAnnouncementAnimatedSlot({
    super.key,
    required this.announcements,
    required this.service,
    this.onTap,
  });

  final List<Announcement> announcements;
  final AnnouncementService service;
  final Future<void> Function(
    BuildContext anchorContext,
    Announcement announcement,
    VoidCallback onMorphLanding,
  )?
  onTap;

  @override
  State<DiscoverAnnouncementAnimatedSlot> createState() =>
      _DiscoverAnnouncementAnimatedSlotState();
}

class _DiscoverAnnouncementAnimatedSlotState
    extends State<DiscoverAnnouncementAnimatedSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController;
  List<String> _deckIds = const [];
  double _dragOffset = 0;
  double _animationStart = 0;
  double _animationEnd = 0;

  @override
  void initState() {
    super.initState();
    _deckIds = widget.announcements
        .map((announcement) => announcement.id)
        .toList(growable: true);
    _settleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
        )..addListener(() {
          final progress = Curves.easeOutCubic.transform(
            _settleController.value,
          );
          setState(() {
            _dragOffset =
                _animationStart +
                ((_animationEnd - _animationStart) * progress);
          });
        });
  }

  @override
  void didUpdateWidget(covariant DiscoverAnnouncementAnimatedSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _settleController.stop();
    _dragOffset = 0;
    final newIds = widget.announcements
        .map((announcement) => announcement.id)
        .toList(growable: false);
    final oldIds = oldWidget.announcements
        .map((announcement) => announcement.id)
        .toSet();
    final availableIds = newIds.toSet();
    final addedIds = newIds.where((id) => !oldIds.contains(id));
    final retainedIds = _deckIds.where(availableIds.contains);
    final orderedIds = <String>[...addedIds, ...retainedIds];
    orderedIds.addAll(newIds.where((id) => !orderedIds.contains(id)));
    _deckIds = orderedIds;
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_settleController.isAnimating || _deckIds.length < 2) {
      return;
    }
    setState(() {
      _dragOffset += details.primaryDelta ?? 0;
    });
  }

  void _handleDragEnd(DragEndDetails details, double width) {
    if (_settleController.isAnimating || _deckIds.length < 2) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final shouldCommit =
        _dragOffset.abs() >= width * 0.24 || velocity.abs() >= 700;
    if (!shouldCommit) {
      unawaited(_animateDragTo(0, rotateDeck: false));
      return;
    }
    final directionSource = _dragOffset.abs() >= 8 ? _dragOffset : velocity;
    final direction = directionSource < 0 ? -1.0 : 1.0;
    unawaited(_animateDragTo(direction * (width + 64), rotateDeck: true));
  }

  void _handleDragCancel() {
    if (!_settleController.isAnimating && _dragOffset != 0) {
      unawaited(_animateDragTo(0, rotateDeck: false));
    }
  }

  Future<void> _animateDragTo(double target, {required bool rotateDeck}) async {
    _animationStart = _dragOffset;
    _animationEnd = target;
    try {
      await _settleController.forward(from: 0);
    } on TickerCanceled {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (rotateDeck && _deckIds.length > 1) {
        _deckIds.add(_deckIds.removeAt(0));
      }
      _dragOffset = 0;
    });
  }

  Future<void> _showMenu(
    BuildContext cardContext,
    Offset globalPosition,
    Announcement announcement,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    final action = await showDiscoverAnnouncementMenu(
      context: context,
      cardContext: cardContext,
      globalPosition: globalPosition,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case DiscoverAnnouncementMenuAction.hideCurrent:
        await widget.service.hideCardFromDiscover(announcement);
        break;
      case DiscoverAnnouncementMenuAction.hideAll:
        await widget.service.hideAllCardsFromDiscover();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcements = widget.announcements;
    return AnimatedSwitcher(
      key: const ValueKey<String>('discover_announcement_slot'),
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return AnimatedBuilder(
          animation: curvedAnimation,
          child: child,
          builder: (context, transitionChild) {
            final value = curvedAnimation.value;
            return Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -8 * (1 - value)),
                  child: transitionChild,
                ),
              ),
            );
          },
        );
      },
      child: announcements.isEmpty
          ? const SizedBox(
              key: ValueKey<String>('discover_announcement_slot_empty'),
            )
          : Padding(
              key: const ValueKey<String>('discover_announcement_slot_stack'),
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildStack(context),
            ),
    );
  }

  Widget _buildStack(BuildContext context) {
    final announcementsById = {
      for (final announcement in widget.announcements)
        announcement.id: announcement,
    };
    final deck = _deckIds
        .map((id) => announcementsById[id])
        .whereType<Announcement>()
        .toList(growable: false);
    final visibleCount = math.min(3, deck.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final liftProgress = width <= 0
            ? 0.0
            : (_dragOffset.abs() / (width * 0.32)).clamp(0.0, 1.0);
        return SizedBox(
          key: const ValueKey<String>('discover_announcement_stack'),
          height: 48 + ((visibleCount - 1) * 4),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              if (deck.length > 1)
                _buildDeckCard(
                  deck.length > visibleCount ? deck[visibleCount] : deck.first,
                  depth: visibleCount,
                  liftProgress: liftProgress,
                  width: width,
                  buffer: true,
                  cloneBuffer: deck.length <= visibleCount,
                ),
              for (var depth = visibleCount - 1; depth >= 0; depth--)
                _buildDeckCard(
                  deck[depth],
                  depth: depth,
                  liftProgress: liftProgress,
                  width: width,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeckCard(
    Announcement announcement, {
    required int depth,
    required double liftProgress,
    required double width,
    bool buffer = false,
    bool cloneBuffer = false,
  }) {
    final isTop = depth == 0 && !buffer;
    final effectiveDepth = isTop ? 0.0 : depth - liftProgress;
    final verticalOffset = effectiveDepth * 4;
    final scale = 1 - (effectiveDepth * 0.03);
    Widget card = Builder(
      builder: (cardContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: isTop && !_settleController.isAnimating
            ? _handleDragUpdate
            : null,
        onHorizontalDragEnd: isTop && !_settleController.isAnimating
            ? (details) => _handleDragEnd(details, width)
            : null,
        onHorizontalDragCancel: isTop && !_settleController.isAnimating
            ? _handleDragCancel
            : null,
        onLongPressStart: isTop && !_settleController.isAnimating
            ? (details) => unawaited(
                _showMenu(cardContext, details.globalPosition, announcement),
              )
            : null,
        child: IgnorePointer(
          ignoring: !isTop || _settleController.isAnimating,
          child: DiscoverAnnouncementCard(
            announcement: announcement,
            service: widget.service,
            onTap: !isTop || widget.onTap == null
                ? null
                : (anchorContext, onMorphLanding) => widget.onTap!(
                    anchorContext,
                    announcement,
                    onMorphLanding,
                  ),
          ),
        ),
      ),
    );
    final keySuffix = cloneBuffer ? '_buffer' : '';
    card = KeyedSubtree(
      key: ValueKey<String>(
        'discover_announcement_deck_visual_${announcement.id}$keySuffix',
      ),
      child: card,
    );
    card = Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: card,
      ),
    );
    if (isTop) {
      final rotation = width <= 0
          ? 0.0
          : (_dragOffset / width).clamp(-1.0, 1.0) * 0.06;
      card = Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Transform.rotate(angle: rotation, child: card),
      );
    }
    if (buffer) {
      card = Opacity(
        key: ValueKey<String>(
          'discover_announcement_deck_buffer_opacity_${announcement.id}',
        ),
        opacity: liftProgress,
        child: card,
      );
    }
    return Positioned(
      key: ValueKey<String>(
        'discover_announcement_deck_${announcement.id}$keySuffix',
      ),
      left: 0,
      right: 0,
      top: 0,
      height: 48,
      child: card,
    );
  }
}

class DiscoverAnnouncementCard extends StatefulWidget {
  const DiscoverAnnouncementCard({
    super.key,
    required this.announcement,
    required this.service,
    this.onTap,
  });

  final Announcement announcement;
  final AnnouncementService service;
  final Future<void> Function(
    BuildContext anchorContext,
    VoidCallback onMorphLanding,
  )?
  onTap;

  @override
  State<DiscoverAnnouncementCard> createState() =>
      _DiscoverAnnouncementCardState();
}

class _DiscoverAnnouncementCardState extends State<DiscoverAnnouncementCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _anchorKey = GlobalKey();
  late final AnimationController _landingController;
  late final Animation<double> _landingScale;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _landingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _landingScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.022,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.022,
          end: 0.996,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.996,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
    ]).animate(_landingController);
  }

  @override
  void dispose() {
    _landingController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final onTap = widget.onTap;
    final anchorContext = _anchorKey.currentContext;
    if (onTap == null || anchorContext == null || _dialogOpen) {
      return;
    }
    setState(() => _dialogOpen = true);
    void revealSource() {
      if (mounted && _dialogOpen) {
        setState(() => _dialogOpen = false);
        _landingController.forward(from: 0);
      }
    }

    try {
      await onTap(anchorContext, revealSource);
    } finally {
      revealSource();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final announcement = widget.announcement;
    final important = announcement.level == AnnouncementLevel.important;
    final accent = important ? colorScheme.error : colorScheme.primary;
    final background = important
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(announcement.publishedAt.toLocal());
    return ScaleTransition(
      key: const ValueKey<String>('discover_announcement_card_landing_scale'),
      scale: _landingScale,
      alignment: Alignment.center,
      child: Opacity(
        key: const ValueKey<String>('discover_announcement_card_opacity'),
        opacity: _dialogOpen ? 0 : 1,
        child: IgnorePointer(
          ignoring: _dialogOpen,
          child: SizedBox(
            key: _anchorKey,
            height: 48,
            child: Material(
              key: const ValueKey<String>(
                'discover_announcement_card_material',
              ),
              color: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: accent.withValues(alpha: 0.16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap == null ? null : () => unawaited(_open()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: accent,
                            size: 22,
                          ),
                          if (!widget.service.isRead(announcement))
                            PositionedDirectional(
                              end: -2,
                              top: -2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          announcement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
