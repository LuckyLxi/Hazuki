import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'favorite_view_support.dart';

class FavoriteComicTile extends StatefulWidget {
  const FavoriteComicTile({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.onTap,
    this.animationStyle = FavoriteEntryAnimationStyle.none,
    this.entryIndex = 0,
  });

  final ExploreComic comic;
  final String heroTag;
  final VoidCallback onTap;
  final FavoriteEntryAnimationStyle animationStyle;
  final int entryIndex;

  @override
  State<FavoriteComicTile> createState() => _FavoriteComicTileState();
}

class _FavoriteComicTileState extends State<FavoriteComicTile> {
  bool _showEntry = true;
  int _entryAnimationRunId = 0;

  @override
  void initState() {
    super.initState();
    _showEntry = widget.animationStyle == FavoriteEntryAnimationStyle.none;
    if (widget.animationStyle != FavoriteEntryAnimationStyle.none) {
      _queueEntryReveal();
    }
  }

  @override
  void didUpdateWidget(covariant FavoriteComicTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationStyle == FavoriteEntryAnimationStyle.none &&
        widget.animationStyle != FavoriteEntryAnimationStyle.none) {
      _showEntry = false;
      _queueEntryReveal();
    }
  }

  void _queueEntryReveal() {
    final runId = ++_entryAnimationRunId;
    final delay = Duration(milliseconds: (widget.entryIndex.clamp(0, 7)) * 45);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(delay, () {
        if (!mounted || _showEntry || runId != _entryAnimationRunId) {
          return;
        }
        setState(() {
          _showEntry = true;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = InkWell(
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
            Hero(
              tag: widget.heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.comic.cover.isEmpty
                    ? Container(
                        width: 72,
                        height: 102,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : HazukiCachedImage(
                        url: widget.comic.cover,
                        sourceKey: widget.comic.sourceKey,
                        width: 72,
                        height: 102,
                        fit: BoxFit.cover,
                        animateOnLoad: true,
                        loading: Container(
                          width: 72,
                          height: 102,
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        error: Container(
                          width: 72,
                          height: 102,
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.comic.title,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.animationStyle == FavoriteEntryAnimationStyle.none &&
        _showEntry) {
      return child;
    }

    const duration = Duration(milliseconds: 320);
    return AnimatedOpacity(
      opacity: _showEntry ? 1.0 : 0.0,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _showEntry ? Offset.zero : const Offset(0, 0.08),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}
