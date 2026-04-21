part of 'history_page.dart';

extension _HistoryWidgets on _HistoryPageState {
  Future<void> _showComicMenu(
    ExploreComic comic,
    Offset globalPosition,
    BuildContext itemContext,
  ) async {
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    final cardBox = itemContext.findRenderObject() as RenderBox?;
    if (overlay == null || cardBox == null) {
      return;
    }

    final fingerOffset = overlay.globalToLocal(globalPosition);
    final cardOffset = cardBox.localToGlobal(Offset.zero, ancestor: overlay);
    final cardSize = cardBox.size;
    final cardTopDy = cardOffset.dy;
    final cardBottomDy = cardOffset.dy + cardSize.height;

    const menuWidth = 212.0;
    const menuHeight = 174.0;
    const gap = 8.0;
    const screenPadding = 8.0;

    final mediaPadding = MediaQuery.of(context).padding;
    final minX = screenPadding;
    final maxX = overlay.size.width - menuWidth - screenPadding;
    final minY = screenPadding + mediaPadding.top;
    final maxY =
        overlay.size.height - mediaPadding.bottom - menuHeight - screenPadding;

    // 尝试让菜单左边缘对齐手指，超出屏幕则镜像到右侧
    var dx = fingerOffset.dx - menuWidth / 2;
    dx = dx.clamp(minX, maxX);

    // 菜单默认在卡片下方，空间不足则显示在上方
    final showBelow =
        cardBottomDy + gap + menuHeight <=
        overlay.size.height - mediaPadding.bottom - screenPadding;
    final dy = showBelow
        ? (cardBottomDy + gap).clamp(minY, maxY)
        : (cardTopDy - gap - menuHeight).clamp(minY, maxY);
    final upwardBottom = overlay.size.height - cardTopDy + gap;

    // 动画缩放原点与水平手指位置相关，垂直方向固定上下边缘
    final originX = ((fingerOffset.dx - dx) / menuWidth * 2 - 1).clamp(
      -1.0,
      1.0,
    );
    final originY = showBelow ? -1.0 : 1.0;

    final strings = AppLocalizations.of(context)!;
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final scheme = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Positioned(
              left: dx,
              top: showBelow ? dy : null,
              bottom: showBelow ? null : upwardBottom,
              width: menuWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                        ),
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
                            onTap: () =>
                                Navigator.of(dialogContext).pop('copy'),
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
                            onTap: () =>
                                Navigator.of(dialogContext).pop('delete'),
                          ),
                        ],
                      ),
                    ),
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
          reverseCurve: Curves.easeInCubic,
        );
        final opacityCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.5, end: 1.0).animate(scaleCurve);
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
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Builder(
        builder: (itemContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            if (!_selectionMode) {
              HapticFeedback.mediumImpact();
              unawaited(
                _showComicMenu(comic, details.globalPosition, itemContext),
              );
            }
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              if (_selectionMode) {
                _toggleSelection(comic.id);
                return;
              }
              final heroTag = widget.comicCoverHeroTagBuilder(
                comic,
                salt: 'history',
              );
              await openComicDetail(
                context,
                comic: comic,
                heroTag: heroTag,
                pageBuilder: widget.comicDetailPageBuilder,
              );
              if (!mounted) {
                return;
              }
              _loadHistory();
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

    return TweenAnimationBuilder<double>(
      // 首次加载或滑入视野时的从下方放出放大动画
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 10)) * 60),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * value,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: item,
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
