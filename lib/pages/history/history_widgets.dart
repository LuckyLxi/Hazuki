part of '../history_page.dart';

extension _HistoryWidgets on _HistoryPageState {
  Future<void> _showComicMenu(
    ExploreComic comic,
    BuildContext itemContext,
    Offset globalPosition,
  ) async {
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    final itemRender = itemContext.findRenderObject() as RenderBox?;
    if (overlay == null || itemRender == null || !itemRender.hasSize) {
      return;
    }

    final itemTopLeft = itemRender.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final itemRect = itemTopLeft & itemRender.size;
    final fingerOffset = overlay.globalToLocal(globalPosition);

    const menuWidth = 212.0;
    const menuHeight = 174.0;
    const gap = 8.0;
    const screenPadding = 8.0;

    final preferRight = fingerOffset.dx <= itemRect.center.dx;
    var dx = preferRight
        ? itemRect.right + gap
        : itemRect.left - menuWidth - gap;
    if (dx + menuWidth > overlay.size.width - screenPadding) {
      dx = itemRect.left - menuWidth - gap;
    }
    if (dx < screenPadding) {
      dx = itemRect.right + gap;
    }
    if (dx + menuWidth > overlay.size.width - screenPadding) {
      dx = (overlay.size.width - menuWidth) / 2;
    }

    final mediaPadding = MediaQuery.of(context).padding;
    final scrollableRender =
        Scrollable.maybeOf(itemContext)?.context.findRenderObject()
            as RenderBox?;
    final viewportRect = scrollableRender != null && scrollableRender.hasSize
        ? scrollableRender.localToGlobal(Offset.zero, ancestor: overlay) &
              scrollableRender.size
        : Offset.zero & overlay.size;
    final minY = math.max(
      screenPadding + mediaPadding.top,
      viewportRect.top + screenPadding,
    );
    final maxY = math.min(
      overlay.size.height - mediaPadding.bottom - menuHeight - screenPadding,
      viewportRect.bottom - menuHeight - screenPadding,
    );
    final availableAbove = itemRect.top - minY;
    final availableBelow = maxY + menuHeight - itemRect.bottom;
    final canShowBelow = availableBelow >= menuHeight + gap;
    final canShowAbove = availableAbove >= menuHeight;
    final showBelow =
        canShowBelow || (!canShowAbove && availableBelow >= availableAbove);
    final preferredTop = itemRect.bottom + gap;
    final dy = preferredTop.clamp(minY, math.max(minY, maxY)).toDouble();
    final upwardBottom = (overlay.size.height - itemRect.top).toDouble();

    final originX = fingerOffset.dx < dx + menuWidth / 2 ? 0.0 : 1.0;
    final originY = showBelow ? -1.0 : 1.0;

    final strings = AppLocalizations.of(context)!;
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final scheme = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Positioned(
              left: dx,
              top: showBelow ? dy : null,
              bottom: showBelow ? null : upwardBottom,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HistoryMenuItem(
                        icon: Icons.copy,
                        label: strings.historyMenuCopyComicId,
                        onTap: () => Navigator.of(dialogContext).pop('copy'),
                      ),
                      _HistoryMenuItem(
                        icon: Icons.favorite_border,
                        label: strings.historyMenuToggleFavorite,
                        onTap: () =>
                            Navigator.of(dialogContext).pop('favorite'),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      _HistoryMenuItem(
                        icon: Icons.delete_outline,
                        label: strings.historyMenuDeleteItem,
                        danger: true,
                        onTap: () => Navigator.of(dialogContext).pop('delete'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final scaleCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeOutCubic,
        );
        final opacityCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.linear,
        );
        final scale = Tween<double>(begin: 0.6, end: 1.0).animate(scaleCurve);
        final align = Alignment(originX, originY);
        return FadeTransition(
          opacity: opacityCurve,
          child: ScaleTransition(alignment: align, scale: scale, child: child),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'copy':
        await _handleCopyComicId(comic);
        break;
      case 'favorite':
        await _handleToggleFavoriteFromHistory(comic);
        break;
      case 'delete':
        await _handleDeleteHistoryItem(comic);
        break;
      default:
        break;
    }
  }

  Widget _buildItem(ExploreComic comic, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Builder(
        builder: (itemContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            if (!_selectionMode) {
              HapticFeedback.mediumImpact();
              unawaited(
                _showComicMenu(comic, itemContext, details.globalPosition),
              );
            }
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(comic.id);
                return;
              }
              final heroTag = widget.comicCoverHeroTagBuilder(
                comic,
                salt: 'history',
              );
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          widget.comicDetailPageBuilder(comic, heroTag),
                    ),
                  )
                  .then((_) {
                    _loadHistory();
                  });
            },
            child: Ink(
              padding: EdgeInsets.fromLTRB(_selectionMode ? 6 : 10, 10, 10, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                          axisAlignment: -1.0,
                          child: child,
                        ),
                      );
                    },
                    child: _selectionMode
                        ? Padding(
                            key: const ValueKey('selection_checkbox'),
                            padding: const EdgeInsets.only(right: 6),
                            child: Checkbox(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              value: _selectedIds.contains(comic.id),
                              onChanged: (selected) {
                                _toggleSelection(comic.id, selected: selected);
                              },
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no_selection')),
                  ),
                  Hero(
                    tag: widget.comicCoverHeroTagBuilder(
                      comic,
                      salt: 'history',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: comic.cover.isEmpty
                          ? Container(
                              width: 72,
                              height: 102,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            )
                          : HazukiCachedImage(
                              url: comic.cover,
                              width: 72,
                              height: 102,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (comic.subTitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            comic.subTitle,
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
          ),
        ),
      ),
    );
  }

  void _toggleSelection(String comicId, {bool? selected}) {
    _updateHistoryState(() {
      if (selected ?? !_selectedIds.contains(comicId)) {
        _selectedIds.add(comicId);
      } else {
        _selectedIds.remove(comicId);
      }
    });
  }
}

class _HistoryMenuItem extends StatelessWidget {
  const _HistoryMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: danger ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
