import 'package:hazuki/widgets/chapter_group_picker.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';

part 'comic_detail_chapters_panel_widgets.dart';

class ComicDetailChaptersPanel extends StatefulWidget {
  const ComicDetailChaptersPanel({
    super.key,
    required this.details,
    required this.onChapterTap,
    required this.onDownloadConfirm,
    this.initialChapterId,
    this.readingProgress,
    this.onResume,
  });

  final ComicDetailsData details;
  final void Function(String epId, String chapterTitle, int index) onChapterTap;
  final ValueChanged<Set<String>> onDownloadConfirm;
  final String? initialChapterId;

  /// 上次阅读进度（epId / pageIndex），用于继续阅读卡片和已读标记。
  final Map<String, dynamic>? readingProgress;

  /// 点击继续阅读卡片；为空时不显示卡片（如阅读器内）。
  final void Function(BuildContext cardContext)? onResume;

  @override
  State<ComicDetailChaptersPanel> createState() =>
      _ComicDetailChaptersPanelState();
}

class _ComicDetailChaptersPanelState extends State<ComicDetailChaptersPanel>
    with TickerProviderStateMixin {
  static const _gridSpacing = 8.0;
  static const _listSpacing = 4.0;
  static const _contentTopPadding = 12.0;

  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedEpIds = <String>{};
  bool _showDownloadSelection = false;
  String? _groupId;
  bool _reversed = false;
  bool _listLayout = false;
  bool _scrolled = false;
  String? _launchingEpId;

  // 章节入场：以当前章节为中心逐行向外浮现
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  // 切换分组 / 排序时的整体滑入
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  double _swapDirection = 0;
  // 点按章节的高亮反馈
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  // 面板高度：-1~0 为下拉关闭区间，0 为半屏，1 为全屏
  late final AnimationController _extent = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );
  double _halfHeight = 0;
  double _detentRange = 0;
  bool _entranceStarted = false;
  bool _listDraggingSheet = false;

  // 最近一次构建的布局信息，用于定位到当前章节
  List<String> _orderedKeys = const [];
  int _columns = 1;
  double _rowExtent = 0;

  late final Map<String, int> _globalIndex = {
    for (final (index, key) in widget.details.chapters.keys.indexed) key: index,
  };

  String? get _currentEpId {
    final id = widget.initialChapterId ?? widget.readingProgress?['epId'];
    return id is String && widget.details.chapters.containsKey(id) ? id : null;
  }

  ComicChapterGroup? get _visibleGroup {
    final groups = widget.details.chapterGroups;
    if (groups.isEmpty) return null;
    return groups.where((g) => g.id == _groupId).firstOrNull ??
        widget.details.groupForChapter(_currentEpId ?? '') ??
        groups.first;
  }

  Map<String, String> get _visibleChapters =>
      _visibleGroup?.chapters ?? widget.details.chapters;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// 进度只记录最后一话，因此按章节顺序把当前话之前的都视为已读。
  bool _isRead(String epId) {
    final current = _globalIndex[_currentEpId];
    final index = _globalIndex[epId];
    return current != null && index != null && index < current;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
    _scheduleScrollToCurrent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entrance.dispose();
    _swap.dispose();
    _flash.dispose();
    _extent.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final positions = _scrollController.positions;
    final scrolled = positions.isNotEmpty && positions.last.pixels > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  void _scheduleScrollToCurrent({bool resetWhenMissing = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.positions.last;
      final index = _orderedKeys.indexOf(_currentEpId ?? '');
      if (index < 0) {
        if (resetWhenMissing) position.jumpTo(0);
        return;
      }
      final row = index ~/ _columns;
      final target =
          _contentTopPadding +
          row * _rowExtent -
          position.viewportDimension * 0.3;
      position.jumpTo(target.clamp(0.0, position.maxScrollExtent));
    });
  }

  void _setSelectionMode(bool enabled) {
    setState(() => _showDownloadSelection = enabled);
  }

  void _editSelection(void Function(Iterable<String> keys) edit) {
    setState(() => edit(_visibleChapters.keys));
  }

  void _selectGroup(String id) {
    final groups = widget.details.chapterGroups;
    final from = groups.indexOf(_visibleGroup!);
    final to = groups.indexWhere((g) => g.id == id);
    if (to < 0 || to == from) return;
    setState(() => _groupId = id);
    _playSwap(to > from ? 1 : -1);
    _scheduleScrollToCurrent(resetWhenMissing: true);
  }

  void _toggleSort() {
    setState(() => _reversed = !_reversed);
    _playSwap(0);
    _scheduleScrollToCurrent(resetWhenMissing: true);
  }

  void _toggleLayout() {
    setState(() => _listLayout = !_listLayout);
    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward(from: 0);
    }
    _scheduleScrollToCurrent();
  }

  void _playSwap(double direction) {
    _swapDirection = direction;
    if (_reduceMotion) {
      _swap.value = 1;
    } else {
      _swap.forward(from: 0);
    }
  }

  void _settleExtent(double target) {
    if (_reduceMotion) {
      _extent.value = target;
      return;
    }
    _extent.animateTo(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Easing.emphasizedDecelerate,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) =>
      _dragSheetBy(details.primaryDelta ?? 0);

  void _handleDragEnd(DragEndDetails details) =>
      _endSheetDrag(details.primaryVelocity ?? 0);

  /// [delta] 为手指向下移动的像素，负值表示向上。
  void _dragSheetBy(double delta) {
    final value = _extent.value;
    final aboveHalf = value > 0 || (value == 0 && delta < 0);
    final range = aboveHalf ? _detentRange : _halfHeight;
    if (range <= 0) return;
    _extent.value = (value - delta / range).clamp(-1.0, 1.0);
  }

  /// [velocity] 为松手时向下的速度（像素 / 秒）。
  void _endSheetDrag(double velocity) {
    final value = _extent.value;
    if (value < 0) {
      if (value > -0.25 && velocity < 700) {
        _settleExtent(0);
      } else if (_showDownloadSelection) {
        // 多选模式下拉到底只退出多选，与返回键行为一致
        _settleExtent(0);
        _setSelectionMode(false);
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }
    final expand = velocity < -500 || (velocity <= 500 && value > 0.5);
    _settleExtent(expand && _detentRange > 0 ? 1 : 0);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    switch (notification) {
      // 列表已在顶部仍继续下拉时，改为拖动面板（缩回半屏或关闭）
      case OverscrollNotification(dragDetails: _?, :final overscroll)
          when overscroll < 0 || _listDraggingSheet:
        _listDraggingSheet = true;
        _dragSheetBy(-overscroll);
      // 半屏时上滑列表，先把面板展开到全屏
      case ScrollUpdateNotification(dragDetails: _?, :final scrollDelta?)
          when scrollDelta > 0 &&
              !_listDraggingSheet &&
              _detentRange > 0 &&
              _extent.value == 0 &&
              !_extent.isAnimating:
        _settleExtent(1);
      case ScrollEndNotification(:final dragDetails) when _listDraggingSheet:
        _listDraggingSheet = false;
        _endSheetDrag(dragDetails?.primaryVelocity ?? 0);
      default:
        break;
    }
    return false;
  }

  bool _handleOverscrollIndicator(
    OverscrollIndicatorNotification notification,
  ) {
    // 顶部下拉交给面板处理，不再显示列表的回弹 / 拉伸效果
    if (notification.leading) notification.disallowIndicator();
    return false;
  }

  void _handleTileTap(String epId, String title) {
    if (_showDownloadSelection) {
      setState(() {
        if (!_selectedEpIds.remove(epId)) _selectedEpIds.add(epId);
      });
      return;
    }
    setState(() => _launchingEpId = epId);
    if (_reduceMotion) {
      _flash.value = 1;
    } else {
      _flash.forward(from: 0);
    }
    widget.onChapterTap(epId, title, _globalIndex[epId] ?? 0);
  }

  void _handleTileLongPress(String epId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedEpIds.add(epId);
      _showDownloadSelection = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final chapters = _visibleChapters.entries.toList(growable: false);
    final ordered = _reversed
        ? chapters.reversed.toList(growable: false)
        : chapters;
    final resumeEpId = widget.onResume == null
        ? null
        : widget.readingProgress?['epId'];
    final showResume =
        resumeEpId is String && widget.details.chapters.containsKey(resumeEpId);

    return PopScope(
      canPop: !_showDownloadSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showDownloadSelection) {
          _setSelectionMode(false);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.sizeOf(context).height;
          final fullHeight = math.min(constraints.maxHeight, screenHeight);
          // 半屏打开，可拖动展开到全屏；矮屏直接使用全高
          _halfHeight = screenHeight < 560
              ? fullHeight
              : math.min(fullHeight, math.max(420.0, screenHeight * 0.62));
          _detentRange = fullHeight - _halfHeight;
          final compact = _halfHeight < 420;
          // 卡片 / 快捷操作 / 分组区域限高并可滚动，矮屏时为章节列表留出空间
          final topMaxHeight = math.min(
            _halfHeight * 0.4,
            math.max(48.0, _halfHeight - 260),
          );
          return AnimatedBuilder(
            animation: _extent,
            builder: (context, child) {
              final value = _extent.value;
              final height = value >= 0
                  ? _halfHeight + _detentRange * value
                  : _halfHeight * (1 + value);
              return SizedBox(height: math.max(0, height), child: child);
            },
            child: Material(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _buildHeader(context, chapters, duration, compact),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: topMaxHeight),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSwitchedSection(
                              visible: showResume && !_showDownloadSelection,
                              keyName: 'resume',
                              duration: duration,
                              builder: () => _buildResumeCard(
                                context,
                                resumeEpId as String,
                              ),
                            ),
                            _buildSwitchedSection(
                              visible: _showDownloadSelection,
                              keyName: 'selection-actions',
                              duration: duration,
                              builder: () => _buildSelectionActions(context),
                            ),
                            if (widget.details.chapterGroups.isNotEmpty)
                              _buildGroupBar(context, duration),
                          ],
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _scrolled ? 1 : 0,
                      duration: duration,
                      child: Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child:
                            NotificationListener<
                              OverscrollIndicatorNotification
                            >(
                              onNotification: _handleOverscrollIndicator,
                              child: AnimatedBuilder(
                                animation: _swap,
                                builder: (context, child) {
                                  final t = Easing.emphasizedDecelerate
                                      .transform(_swap.value);
                                  return Opacity(
                                    opacity: t,
                                    child: Transform.translate(
                                      offset: Offset(
                                        _swapDirection * 24 * (1 - t),
                                        _swapDirection == 0 ? 10 * (1 - t) : 0,
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildChapterArea(
                                  context,
                                  ordered,
                                  duration,
                                ),
                              ),
                            ),
                      ),
                    ),
                    if (duration == Duration.zero)
                      _buildDownloadFooter(context)
                    else
                      AnimatedSize(
                        duration: duration,
                        curve: Easing.emphasizedDecelerate,
                        alignment: Alignment.topCenter,
                        child: _buildDownloadFooter(context),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<MapEntry<String, String>> chapters,
    Duration duration,
    bool compact,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = l10n(context);
    final readCount = _currentEpId == null
        ? null
        : chapters.where((e) => _isRead(e.key)).length;

    Widget switcher(
      Widget child, {
      AlignmentGeometry alignment = AlignmentDirectional.centerStart,
    }) => AnimatedSwitcher(
      duration: duration,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );

    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final title = _showDownloadSelection
        ? Column(
            key: const ValueKey('selection-title'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 计数变化时数字从下方滚入
              switcher(
                Text(
                  strings.comicDetailChapterSelectedCount(
                    '${_selectedEpIds.length}',
                  ),
                  key: ValueKey(_selectedEpIds.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (!compact)
                Text(
                  strings.comicDetailChapterSelectHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
            ],
          )
        : Column(
            key: const ValueKey('chapter-title'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.comicDetailChapters,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              if (!compact)
                Text(
                  readCount == null
                      ? strings.comicDetailChapterCount('${chapters.length}')
                      : strings.comicDetailChapterReadSummary(
                          '${chapters.length}',
                          '$readCount',
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
            ],
          );

    final actions = _showDownloadSelection
        ? IconButton(
            key: const ValueKey('selection-actions'),
            tooltip: strings.comicDetailChapterExitSelection,
            onPressed: () => _setSelectionMode(false),
            icon: const Icon(Icons.close_rounded),
          )
        : Row(
            key: const ValueKey('chapter-actions'),
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _reversed
                    ? strings.comicDetailChapterSortOriginal
                    : strings.comicDetailChapterSortReversed,
                onPressed: chapters.isEmpty ? null : _toggleSort,
                icon: TweenAnimationBuilder<double>(
                  tween: Tween(end: _reversed ? -1 : 1),
                  duration: duration,
                  curve: Easing.emphasizedDecelerate,
                  builder: (context, value, child) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1, value, 1),
                    child: child,
                  ),
                  child: const Icon(Icons.sort_rounded),
                ),
              ),
              IconButton(
                tooltip: _listLayout
                    ? strings.comicDetailChapterGridView
                    : strings.comicDetailChapterListView,
                onPressed: _toggleLayout,
                icon: AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    _listLayout
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                    key: ValueKey(_listLayout),
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.downloadsDownloadAction,
                onPressed: chapters.isEmpty
                    ? null
                    : () => _setSelectionMode(true),
                icon: const Icon(Icons.download_outlined),
              ),
            ],
          );

    // 把手与标题区域可上下拖动，在半屏 / 全屏间切换或下拉关闭
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
            child: Row(
              children: [
                Expanded(child: switcher(title)),
                const SizedBox(width: 4),
                // 操作按钮靠右对齐，切换时新按钮直接出现在最终位置
                switcher(actions, alignment: AlignmentDirectional.centerEnd),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchedSection({
    required bool visible,
    required String keyName,
    required Duration duration,
    required Widget Function() builder,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: visible
          ? KeyedSubtree(key: ValueKey(keyName), child: builder())
          : SizedBox(key: ValueKey('$keyName-hidden'), width: double.infinity),
    );
  }

  Widget _buildResumeCard(BuildContext context, String epId) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = l10n(context);
    final pageIndex = widget.readingProgress?['pageIndex'];
    final title = resolveHazukiChapterTitle(
      context,
      widget.details.chapters[epId]!,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Builder(
        builder: (cardContext) => Material(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onResume!(cardContext),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.comicDetailChapterContinue,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pageIndex is int && pageIndex > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      strings.comicDetailChapterResumePage('${pageIndex + 1}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionActions(BuildContext context) {
    final strings = l10n(context);
    Widget chip(String label, VoidCallback onPressed) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ActionChip(label: Text(label), onPressed: onPressed),
    );
    final keys = _visibleChapters.keys;
    final allSelected = keys.isNotEmpty && keys.every(_selectedEpIds.contains);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
      child: Row(
        children: [
          // 当前分组已全选时切换为取消全选，只作用于当前分组
          chip(
            allSelected ? strings.commonDeselectAll : strings.commonSelectAll,
            () => _editSelection(
              allSelected ? _selectedEpIds.removeAll : _selectedEpIds.addAll,
            ),
          ),
          chip(
            strings.comicDetailChapterSelectUnread,
            () => _editSelection(
              (keys) => _selectedEpIds.addAll(keys.where((k) => !_isRead(k))),
            ),
          ),
          chip(
            strings.comicDetailChapterSelectInvert,
            () => _editSelection((keys) {
              for (final key in keys) {
                if (!_selectedEpIds.remove(key)) _selectedEpIds.add(key);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupBar(BuildContext context, Duration duration) {
    final groups = widget.details.chapterGroups;
    final selected = groups.indexOf(_visibleGroup!);
    final customMenu = ChapterGroupPicker.menuBinding(
      widget.details,
    ).resolve(context).entries.isNotEmpty;
    // 插件自定义了分组菜单或分组过多时沿用下拉菜单；≤3 平分标签，4~8 横向滑动
    if (customMenu || groups.length > 8) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: ChapterGroupPicker(
          details: widget.details,
          selectedGroupId: _visibleGroup!.id,
          initialChapterId: _currentEpId,
          onSelected: _selectGroup,
        ),
      );
    }
    if (groups.length <= 3) {
      return _SegmentedGroupBar(
        groups: groups,
        selectedIndex: selected,
        duration: duration,
        onSelected: _selectGroup,
      );
    }
    return _ScrollingGroupBar(
      groups: groups,
      selectedIndex: selected,
      duration: duration,
      onSelected: _selectGroup,
    );
  }

  Widget _buildChapterArea(
    BuildContext context,
    List<MapEntry<String, String>> ordered,
    Duration duration,
  ) {
    final positions = {
      for (final (index, key) in _visibleChapters.keys.indexed) key: index,
    };
    _orderedKeys = [for (final entry in ordered) entry.key];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context);
        _columns = _listLayout
            ? 1
            : ((constraints.maxWidth - 32) / (textScale.scale(100) + 8))
                  .floor()
                  .clamp(1, 5);
        final extent = _listLayout
            ? 8 + textScale.scale(48)
            : 20 + textScale.scale(44);
        _rowExtent = extent + (_listLayout ? _listSpacing : _gridSpacing);
        final currentIndex = _orderedKeys.indexOf(_currentEpId ?? '');
        final currentRow = currentIndex < 0 ? 0 : currentIndex ~/ _columns;

        Widget itemBuilder(BuildContext context, int index) {
          final entry = ordered[index];
          final title = resolveHazukiChapterTitle(context, entry.value);
          final distance = ((index ~/ _columns) - currentRow).abs().clamp(
            0,
            10,
          );
          return _StaggeredEntrance(
            animation: _entrance,
            start: math.min(0.55, distance * 0.05 + index % _columns * 0.02),
            child: _ChapterTile(
              key: ValueKey(entry.key),
              number: (positions[entry.key] ?? index) + 1,
              title: title,
              list: _listLayout,
              read: _isRead(entry.key),
              current: entry.key == _currentEpId,
              selectionMode: _showDownloadSelection,
              selected: _selectedEpIds.contains(entry.key),
              launch: entry.key == _launchingEpId ? _flash : null,
              duration: duration,
              onTap: () => _handleTileTap(entry.key, title),
              onLongPress: () => _handleTileLongPress(entry.key),
            ),
          );
        }

        const padding = EdgeInsets.fromLTRB(16, _contentTopPadding, 16, 20);
        return Scrollbar(
          controller: _scrollController,
          child: _listLayout
              ? ListView.builder(
                  key: const ValueKey('chapter-list'),
                  controller: _scrollController,
                  padding: padding,
                  itemExtent: _rowExtent,
                  itemCount: ordered.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: _listSpacing),
                    child: itemBuilder(context, index),
                  ),
                )
              : GridView.builder(
                  key: const ValueKey('chapter-grid'),
                  controller: _scrollController,
                  padding: padding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns,
                    mainAxisSpacing: _gridSpacing,
                    crossAxisSpacing: _gridSpacing,
                    mainAxisExtent: extent,
                  ),
                  itemCount: ordered.length,
                  itemBuilder: itemBuilder,
                ),
        );
      },
    );
  }

  Widget _buildDownloadFooter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = l10n(context);
    return _showDownloadSelection
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: FilledButton.icon(
              onPressed: _selectedEpIds.isEmpty
                  ? null
                  : () => widget.onDownloadConfirm(
                      Set<String>.from(_selectedEpIds),
                    ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                _selectedEpIds.isEmpty
                    ? strings.downloadsDownloadAction
                    : strings.comicDetailChapterDownloadCount(
                        '${_selectedEpIds.length}',
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          )
        : const SizedBox(width: double.infinity);
  }
}
