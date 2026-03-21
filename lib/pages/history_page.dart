part of '../../main.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();

  List<ExploreComic> _history = [];
  bool _loading = true;
  bool _selectionMode = false;
  bool _showBackToTop = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextShowBackToTop = position.pixels > 520;
    if (nextShowBackToTop != _showBackToTop && mounted) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('hazuki_read_history');
    if (jsonStr != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final history = jsonList
            .map(
              (e) => ExploreComic(
                id: e['id'] as String? ?? '',
                title: e['title'] as String? ?? '',
                cover: e['cover'] as String? ?? '',
                subTitle: e['subTitle'] as String? ?? '',
              ),
            )
            .toList();
        if (mounted) {
          setState(() {
            _history = history;
            _loading = false;
          });
        }
        return;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _history = [];
        _loading = false;
      });
    }
  }

  Future<void> _saveHistory(List<ExploreComic> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = history
        .map(
          (e) => {
            'id': e.id,
            'title': e.title,
            'cover': e.cover,
            'subTitle': e.subTitle,
          },
        )
        .toList();
    await prefs.setString('hazuki_read_history', jsonEncode(jsonList));
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          title: const Text('删除历史记录'),
          content: Text('你确定要删除选中的${_selectedIds.length}部漫画历史记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    if (confirm != true) return;

    final newHistory = _history
        .where((e) => !_selectedIds.contains(e.id))
        .toList();
    await _saveHistory(newHistory);
    setState(() {
      _history = newHistory;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          title: const Text('清空历史记录'),
          content: const Text('你确定要清空所有历史记录吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );

    if (confirm != true) return;

    await _saveHistory([]);
    setState(() {
      _history = [];
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _handleCopyComicId(ExploreComic comic) async {
    await Clipboard.setData(ClipboardData(text: comic.id));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制漫画ID')));
  }

  Future<void> _handleToggleFavoriteFromHistory(ExploreComic comic) async {
    final isLogged = HazukiSourceService.instance.isLogged;
    final messenger = ScaffoldMessenger.of(context);

    if (!isLogged) {
      messenger.showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('正在处理收藏...')));
    try {
      final details = await HazukiSourceService.instance.loadComicDetails(
        comic.id,
      );
      if (HazukiSourceService.instance.supportFavoriteFolderLoad &&
          HazukiSourceService.instance.supportFavoriteToggle) {
        messenger.showSnackBar(
          const SnackBar(content: Text('多收藏夹请在漫画详情页内操作，正在执行默认操作...')),
        );
      }
      if (details.isFavorite) {
        await HazukiSourceService.instance.toggleFavorite(
          comicId: details.id,
          isAdding: false,
          folderId: '0',
        );
        messenger.showSnackBar(const SnackBar(content: Text('已取消收藏')));
      } else {
        await HazukiSourceService.instance.toggleFavorite(
          comicId: details.id,
          isAdding: true,
          folderId: '0',
        );
        messenger.showSnackBar(const SnackBar(content: Text('已添加收藏')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('收藏操作失败: $e')));
    }
  }

  Future<void> _handleDeleteHistoryItem(ExploreComic comic) async {
    final newHistory = _history.where((e) => e.id != comic.id).toList();
    await _saveHistory(newHistory);
    if (!mounted) {
      return;
    }
    setState(() {
      _history = newHistory;
    });
  }

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

    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 240),
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
                        label: '复制漫画ID',
                        onTap: () => Navigator.of(dialogContext).pop('copy'),
                      ),
                      _HistoryMenuItem(
                        icon: Icons.favorite_border,
                        label: '收藏/取消收藏',
                        onTap: () =>
                            Navigator.of(dialogContext).pop('favorite'),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      _HistoryMenuItem(
                        icon: Icons.delete_outline,
                        label: '删除此记录',
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
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(curved);
        final align = Alignment(originX, originY);
        return FadeTransition(
          opacity: curved,
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
                setState(() {
                  if (_selectedIds.contains(comic.id)) {
                    _selectedIds.remove(comic.id);
                  } else {
                    _selectedIds.add(comic.id);
                  }
                });
                return;
              }
              final heroTag = _comicCoverHeroTag(comic, salt: 'history');
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ComicDetailPage(comic: comic, heroTag: heroTag),
                    ),
                  )
                  .then((_) {
                    _loadHistory(); // 重新加载以防记录位置变动
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
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(comic.id);
                                  } else {
                                    _selectedIds.remove(comic.id);
                                  }
                                });
                              },
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no_selection')),
                  ),
                  Hero(
                    tag: _comicCoverHeroTag(comic, salt: 'history'),
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

  @override
  Widget build(BuildContext context) {
    final bodyContent = _loading
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HazukiStickerLoadingIndicator(size: 112),
                SizedBox(height: 10),
                Text('加载中...'),
              ],
            ),
          )
        : _history.isEmpty
        ? const Center(child: Text('暂无历史记录'))
        : ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.all(16),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              return _buildItem(_history[index], index);
            },
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: _selectionMode ? '取消多选' : '多选',
              icon: Icon(_selectionMode ? Icons.close : Icons.checklist),
              onPressed: () {
                setState(() {
                  _selectionMode = !_selectionMode;
                  _selectedIds.clear();
                });
              },
            ),
          if (_history.isNotEmpty)
            IconButton(
              tooltip: _selectionMode ? '删除选中的历史' : '清空所有历史',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selectionMode ? _deleteSelected : _clearAll,
            ),
        ],
      ),
      body: Stack(
        children: [
          bodyContent,
          Positioned(
            right: 16,
            bottom: 16,
            child: AnimatedSlide(
              offset: _showBackToTop ? Offset.zero : const Offset(0, 0.24),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedScale(
                scale: _showBackToTop ? 1 : 0.86,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _showBackToTop ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !_showBackToTop,
                    child: FloatingActionButton.small(
                      heroTag: 'history_back_to_top',
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.vertical_align_top_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
