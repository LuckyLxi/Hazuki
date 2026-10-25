part of 'comic_detail_chapters_panel.dart';

/// 纯黑模式下各级容器色都等于背景色，改用前景色叠加出可见的底色。
Color _visibleContainer(ColorScheme cs, Color container, double alpha) =>
    container == cs.surface
    ? Color.alphaBlend(cs.onSurface.withValues(alpha: alpha), cs.surface)
    : container;

/// 按起始时间错开的入场动画；结构保持不变，避免重建子树。
class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.animation,
    required this.start,
    required this.child,
  });

  final Animation<double> animation;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Easing.emphasizedDecelerate.transform(
          Interval(start, math.min(1, start + 0.45)).transform(animation.value),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _SegmentedGroupBar extends StatelessWidget {
  const _SegmentedGroupBar({
    required this.groups,
    required this.selectedIndex,
    required this.duration,
    required this.onSelected,
  });

  final List<ComicChapterGroup> groups;
  final int selectedIndex;
  final Duration duration;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _visibleContainer(cs, cs.surfaceContainer, 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / groups.length;
              return Stack(
                children: [
                  // 选中滑块跟随分组移动
                  AnimatedPositioned(
                    duration: duration * 1.6,
                    curve: Easing.emphasizedDecelerate,
                    left: width * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (index, group) in groups.indexed)
                        Expanded(
                          child: Semantics(
                            selected: index == selectedIndex,
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => onSelected(group.id),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 40,
                                ),
                                child: Center(
                                  child: _GroupLabel(
                                    group: group,
                                    selected: index == selectedIndex,
                                    duration: duration,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScrollingGroupBar extends StatefulWidget {
  const _ScrollingGroupBar({
    required this.groups,
    required this.selectedIndex,
    required this.duration,
    required this.onSelected,
  });

  final List<ComicChapterGroup> groups;
  final int selectedIndex;
  final Duration duration;
  final ValueChanged<String> onSelected;

  @override
  State<_ScrollingGroupBar> createState() => _ScrollingGroupBarState();
}

class _ScrollingGroupBarState extends State<_ScrollingGroupBar> {
  late List<GlobalKey> _keys = _createKeys();

  List<GlobalKey> _createKeys() => [for (final _ in widget.groups) GlobalKey()];

  @override
  void initState() {
    super.initState();
    _revealSelected(Duration.zero);
  }

  @override
  void didUpdateWidget(_ScrollingGroupBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups.length != widget.groups.length) {
      _keys = _createKeys();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _revealSelected(widget.duration * 1.6);
    }
  }

  // 选中的分组滚到可视区中间
  void _revealSelected(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[widget.selectedIndex].currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: duration,
        curve: Easing.emphasizedDecelerate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 8),
      child: Row(
        children: [
          for (final (index, group) in widget.groups.indexed)
            Padding(
              key: _keys[index],
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: _GroupLabel(
                  group: group,
                  selected: index == widget.selectedIndex,
                  duration: widget.duration,
                ),
                selected: index == widget.selectedIndex,
                showCheckmark: false,
                selectedColor: cs.primaryContainer,
                onSelected: (_) => widget.onSelected(group.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({
    required this.group,
    required this.selected,
    required this.duration,
  });

  final ComicChapterGroup group;
  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return AnimatedDefaultTextStyle(
      duration: duration,
      style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: color,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text.rich(
          TextSpan(
            text: group.title,
            children: [
              TextSpan(
                text: ' ${group.chapters.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: color.withValues(alpha: 0.8),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    super.key,
    required this.number,
    required this.title,
    required this.list,
    required this.read,
    required this.current,
    required this.selectionMode,
    required this.selected,
    required this.launch,
    required this.duration,
    required this.onTap,
    required this.onLongPress,
  });

  final int number;
  final String title;
  final bool list;
  final bool read;
  final bool current;
  final bool selectionMode;
  final bool selected;

  /// 非空表示该章节刚被点按，用于播放高亮反馈。
  final Animation<double>? launch;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = l10n(context);
    final highlighted = selectionMode && selected;
    final Color background;
    final Color foreground;
    if (highlighted) {
      background = list ? cs.secondaryContainer : cs.primary;
      foreground = list ? cs.onSecondaryContainer : cs.onPrimary;
    } else if (current) {
      background = cs.primaryContainer;
      foreground = cs.onPrimaryContainer;
    } else if (read) {
      background = list
          ? Colors.transparent
          : _visibleContainer(cs, cs.surfaceContainer, 0.06);
      foreground = cs.onSurfaceVariant;
    } else {
      background = list
          ? Colors.transparent
          : _visibleContainer(cs, cs.surfaceContainerHighest, 0.12);
      foreground = cs.onSurface;
    }
    final radius = BorderRadius.circular(14);
    final titleStyle = theme.textTheme.bodySmall?.copyWith(
      color: foreground,
      fontWeight: read && !highlighted ? FontWeight.w400 : FontWeight.w600,
    );
    final kicker = current
        ? Text(
            strings.comicDetailChapterLastRead,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: highlighted ? foreground : cs.primary,
              fontWeight: FontWeight.w700,
            ),
          )
        : null;
    final mark = AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: selectionMode
          ? Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey(selected),
              size: 18,
              color: highlighted
                  ? (list ? cs.primary : foreground)
                  : cs.outline,
            )
          : list
          ? Icon(
              Icons.chevron_right_rounded,
              key: const ValueKey('chevron'),
              size: 20,
              color: cs.outline,
            )
          : const SizedBox.shrink(key: ValueKey('none')),
    );
    final readGlyph = AnimatedOpacity(
      opacity: read && !selectionMode ? 1 : 0,
      duration: duration,
      child: Icon(Icons.check_rounded, size: 14, color: cs.outline),
    );

    final Widget content;
    if (list) {
      content = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 12, 0),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$number'.padLeft(2, '0'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: current ? foreground : cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?kicker,
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ],
              ),
            ),
            if (read) readGlyph,
            const SizedBox(width: 8),
            SizedBox.square(dimension: 24, child: Center(child: mark)),
          ],
        ),
      );
    } else {
      content = Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 26, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?kicker,
                Flexible(
                  child: Text(
                    title,
                    maxLines: current ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(top: 7, end: 7, child: mark),
          if (read) PositionedDirectional(bottom: 8, end: 8, child: readGlyph),
        ],
      );
    }

    final launch = this.launch;
    return Semantics(
      button: true,
      selected: selectionMode ? selected : null,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Material(
        color: background,
        animationDuration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: current && !highlighted && !list
              ? BorderSide(color: cs.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (launch != null)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: launch,
                    builder: (context, _) {
                      // 先亮到峰值，再保持淡淡的选中底色
                      final t = launch.value;
                      final alpha = t < 0.4
                          ? t / 0.4 * 0.3
                          : 0.3 - (t - 0.4) / 0.6 * 0.18;
                      return ColoredBox(
                        color: cs.primary.withValues(alpha: alpha),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
