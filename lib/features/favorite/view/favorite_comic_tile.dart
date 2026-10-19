import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'favorite_view_support.dart';
import '../support/favorite_entry_animation_queue.dart';

class FavoriteComicTile extends StatefulWidget {
  const FavoriteComicTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.onTap,
    this.animationStyle = FavoriteEntryAnimationStyle.none,
    this.layout = FavoriteLayout.list,
    this.entryScrollController,
    this.entryAnimationQueue,
  });

  final ExploreComic comic;
  final String heroTag;
  final VoidCallback onTap;
  final FavoriteEntryAnimationStyle animationStyle;
  final FavoriteLayout layout;
  final ScrollController? entryScrollController;
  final FavoriteEntryAnimationQueue? entryAnimationQueue;

  @override
  State<FavoriteComicTile> createState() => _FavoriteComicTileState();
}

class _FavoriteComicTileState extends State<FavoriteComicTile>
    with SingleTickerProviderStateMixin {
  bool _showEntry = true;
  late final AnimationController _entryController;
  late final CurvedAnimation _entryProgress;
  late final Animation<Offset> _entryOffset;
  ScrollController? _listeningScrollController;
  bool _visibilityCheckScheduled = false;
  bool _entryQueued = false;
  FavoriteEntryAnimationQueue? _queuedAnimationQueue;

  @override
  void initState() {
    super.initState();
    _showEntry = widget.animationStyle == FavoriteEntryAnimationStyle.none;
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: _showEntry ? 1 : 0,
    );
    _entryProgress = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryOffset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_entryProgress);
    if (widget.animationStyle != FavoriteEntryAnimationStyle.none) {
      _waitForEntryVisibility();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queueEntryReveal();
  }

  @override
  void didUpdateWidget(covariant FavoriteComicTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entryAnimationQueue, widget.entryAnimationQueue)) {
      _cancelQueuedEntry();
    }
    if (widget.animationStyle == FavoriteEntryAnimationStyle.none) {
      _cancelQueuedEntry();
      _entryController.value = 1;
      _stopWaitingForEntryVisibility();
      _showEntry = true;
      return;
    }
    if (oldWidget.animationStyle == FavoriteEntryAnimationStyle.none &&
        widget.animationStyle != FavoriteEntryAnimationStyle.none) {
      _showEntry = false;
      _entryController.value = 0;
    }
    if (!_showEntry) {
      _waitForEntryVisibility();
    }
  }

  @override
  void dispose() {
    _stopWaitingForEntryVisibility();
    _cancelQueuedEntry();
    _entryProgress.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _waitForEntryVisibility() {
    if (_entryQueued) return;
    if (!identical(_listeningScrollController, widget.entryScrollController)) {
      _stopWaitingForEntryVisibility();
      _listeningScrollController = widget.entryScrollController;
      _listeningScrollController?.addListener(_queueEntryReveal);
    }
    _queueEntryReveal();
  }

  void _stopWaitingForEntryVisibility() {
    _listeningScrollController?.removeListener(_queueEntryReveal);
    _listeningScrollController = null;
  }

  bool _isEntryVisible() {
    final controller = widget.entryScrollController;
    if (controller == null) return true;
    if (!controller.hasClients) return false;
    final viewport = controller.position.context.notificationContext
        ?.findRenderObject();
    final tile = context.findRenderObject();
    if (viewport is! RenderBox ||
        tile is! RenderBox ||
        !viewport.hasSize ||
        !tile.hasSize) {
      return false;
    }
    final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    final tileRect = tile.localToGlobal(Offset.zero) & tile.size;
    return viewportRect.overlaps(tileRect);
  }

  void _queueEntryReveal() {
    if (_showEntry || _visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted || _showEntry) {
        return;
      }
      if (_entryQueued) {
        if (!_isEntryVisible()) _cancelQueuedEntry();
        return;
      }
      if (!_isEntryVisible()) return;
      final queue = widget.entryAnimationQueue;
      if (queue == null) {
        _startEntry();
      } else {
        _entryQueued = true;
        _queuedAnimationQueue = queue;
        queue.schedule(this, _startEntry);
      }
    });
  }

  void _cancelQueuedEntry() {
    _queuedAnimationQueue?.cancel(this);
    _queuedAnimationQueue = null;
    _entryQueued = false;
  }

  void _startEntry() {
    _queuedAnimationQueue = null;
    _entryQueued = false;
    if (!mounted || _showEntry) return;
    if (!_isEntryVisible()) {
      _waitForEntryVisibility();
      return;
    }
    _stopWaitingForEntryVisibility();
    setState(() => _showEntry = true);
    _entryController.forward();
  }

  Widget _buildCover(BuildContext context, {double? width, double? height}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Hero(
      tag: widget.heroTag,
      flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
      placeholderBuilder: buildComicCoverHeroPlaceholder,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: widget.comic.cover.isEmpty
            ? Container(
                width: width,
                height: height,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined),
              )
            : HazukiCachedImage(
                url: widget.comic.cover,
                sourceKey: widget.comic.sourceKey,
                width: width,
                height: height,
                fit: BoxFit.cover,
                animateOnLoad: true,
                loading: Container(
                  width: width,
                  height: height,
                  color: colorScheme.surfaceContainerHighest,
                ),
                error: Container(
                  width: width,
                  height: height,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onTap,
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _buildCover(context, width: 72, height: 102),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    convertChineseText(context, widget.comic.title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.comic.subTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.comic.subTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (sourceFeature(
                        widget.comic.sourceKey,
                        'showTags',
                        context: context,
                      ) &&
                      widget.comic.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SourceComicTags(
                      sourceKey: widget.comic.sourceKey,
                      tags: widget.comic.tags,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTile(BuildContext context) {
    final title = convertChineseText(context, widget.comic.title);
    return Semantics(
      label: title,
      button: true,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 72 / 102, child: _buildCover(context)),
            if (widget.layout != FavoriteLayout.coverOnly) ...[
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.layout == FavoriteLayout.list
        ? _buildListTile(context)
        : _buildGridTile(context);

    if (widget.animationStyle == FavoriteEntryAnimationStyle.none &&
        _showEntry) {
      return child;
    }

    return FadeTransition(
      opacity: _entryProgress,
      child: SlideTransition(
        position: _entryOffset,
        child: IgnorePointer(ignoring: !_showEntry, child: child),
      ),
    );
  }
}
