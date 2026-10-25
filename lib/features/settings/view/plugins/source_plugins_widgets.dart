part of 'source_plugins_page.dart';

class _PluginOperationLabel extends StatelessWidget {
  const _PluginOperationLabel({
    required this.loading,
    required this.label,
    required this.loadingLabel,
  });

  final bool loading;
  final String label;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      ExcludeSemantics(
        excluding: loading,
        child: AnimatedOpacity(
          opacity: loading ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          child: Text(label),
        ),
      ),
      Positioned.fill(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: loading
              ? SizedBox.square(
                  key: const ValueKey('loading'),
                  dimension: 24,
                  child: HazukiM3ELoadingIndicator(semanticLabel: loadingLabel),
                )
              : const SizedBox.shrink(key: ValueKey('idle')),
        ),
      ),
    ],
  );
}

/// 仓库刷新按钮：刷新期间图标持续旋转并切换为强调色，结束时转完当前一圈再停下。
class _PluginRefreshButton extends StatefulWidget {
  const _PluginRefreshButton({
    required this.tooltip,
    required this.refreshing,
    required this.onPressed,
  });

  final String tooltip;
  final bool refreshing;
  final VoidCallback? onPressed;

  @override
  State<_PluginRefreshButton> createState() => _PluginRefreshButtonState();
}

class _PluginRefreshButtonState extends State<_PluginRefreshButton>
    with SingleTickerProviderStateMixin {
  static const _turn = Duration(milliseconds: 850);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _turn,
  );

  @override
  void initState() {
    super.initState();
    if (widget.refreshing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _PluginRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshing == oldWidget.refreshing) return;
    if (widget.refreshing) {
      _controller.repeat();
    } else if (_controller.isAnimating) {
      _settle();
    }
  }

  // 按剩余角度换算时长并减速，转回原位后归零，避免图标停在半圈。
  void _settle() {
    final remaining = 1 - _controller.value;
    _controller
        .animateTo(
          1,
          duration: _turn * (remaining * 1.6),
          curve: Curves.easeOutCubic,
        )
        .whenCompleteOrCancel(() {
          if (mounted && !widget.refreshing) _controller.value = 0;
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final refreshing = widget.refreshing;
    return IconButton(
      tooltip: widget.tooltip,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.primary,
        disabledBackgroundColor: refreshing ? scheme.primary : null,
        disabledForegroundColor: refreshing ? scheme.onPrimary : null,
        animationDuration: const Duration(milliseconds: 220),
      ),
      onPressed: widget.onPressed,
      icon: RotationTransition(
        turns: _controller,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _PluginSurface extends StatelessWidget {
  const _PluginSurface({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 插件首字母头像；启用状态切换时颜色平滑过渡。
class _PluginAvatar extends StatelessWidget {
  const _PluginAvatar({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
          child: Text(initial),
        ),
      ),
    );
  }
}

/// 空状态与列表占位之间的淡入淡出 + 尺寸过渡。
class _PluginFadeSwitcher extends StatelessWidget {
  const _PluginFadeSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    ),
  );
}

/// 卡片内可选区块（更新按钮、错误提示）的展开 / 收起动画。
class _PluginRevealSection extends StatelessWidget {
  const _PluginRevealSection({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: visible
          ? KeyedSubtree(key: const ValueKey('visible'), child: child)
          : const SizedBox(key: ValueKey('hidden'), width: double.infinity),
    ),
  );
}

class _PluginGridSlot<T> {
  _PluginGridSlot({
    required this.key,
    required this.item,
    required this.controller,
  }) : animation = CurvedAnimation(
         parent: controller,
         curve: Curves.easeOutCubic,
         reverseCurve: Curves.easeInCubic,
       ),
       // 退场分两段：控制器 1→0.4 时卡片侧滑淡出，0.45→0 时收起占位高度。
       exitAnimation = CurvedAnimation(
         parent: controller,
         curve: const Interval(0.4, 1, curve: Curves.easeInOutCubic),
       ),
       collapseAnimation = CurvedAnimation(
         parent: controller,
         curve: const Interval(0, 0.45, curve: Curves.easeInOutCubic),
       );

  final String key;
  T item;
  final AnimationController controller;
  final CurvedAnimation animation;
  final CurvedAnimation exitAnimation;
  final CurvedAnimation collapseAnimation;
  bool removing = false;

  void dispose() {
    animation.dispose();
    exitAnimation.dispose();
    collapseAnimation.dispose();
    controller.dispose();
  }
}

/// 按 key 对比前后列表：新增条目展开淡入，被移除条目（如卸载）缩小淡出后再折叠，
/// 宽屏下两列排布。
class _AnimatedPluginGrid<T> extends StatefulWidget {
  const _AnimatedPluginGrid({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
  });

  final List<T> items;
  final String Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  State<_AnimatedPluginGrid<T>> createState() => _AnimatedPluginGridState<T>();
}

class _AnimatedPluginGridState<T> extends State<_AnimatedPluginGrid<T>>
    with TickerProviderStateMixin {
  final List<_PluginGridSlot<T>> _slots = [];

  @override
  void initState() {
    super.initState();
    // 首帧直接展示，不播放进场动画。
    for (final item in widget.items) {
      _slots.add(_createSlot(item, value: 1));
    }
  }

  _PluginGridSlot<T> _createSlot(T item, {double value = 0}) =>
      _PluginGridSlot<T>(
        key: widget.keyOf(item),
        item: item,
        controller: AnimationController(
          vsync: this,
          value: value,
          duration: const Duration(milliseconds: 320),
          reverseDuration: const Duration(milliseconds: 480),
        ),
      );

  @override
  void didUpdateWidget(covariant _AnimatedPluginGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKeys = {for (final item in widget.items) widget.keyOf(item)};
    final previous = {for (final slot in _slots) slot.key: slot};
    final merged = <_PluginGridSlot<T>>[];
    var oldIndex = 0;
    void takeRemoved() {
      // 被移除的条目保留在原相对位置播放退场动画。
      while (oldIndex < _slots.length &&
          !nextKeys.contains(_slots[oldIndex].key)) {
        merged.add(_exit(_slots[oldIndex]));
        oldIndex++;
      }
    }

    for (final item in widget.items) {
      takeRemoved();
      final key = widget.keyOf(item);
      final existing = previous[key];
      if (existing == null) {
        merged.add(_createSlot(item)..controller.forward());
      } else {
        existing.item = item;
        if (existing.removing) {
          existing.removing = false;
          existing.controller.forward();
        }
        merged.add(existing);
      }
      if (oldIndex < _slots.length && _slots[oldIndex].key == key) oldIndex++;
    }
    for (; oldIndex < _slots.length; oldIndex++) {
      if (!nextKeys.contains(_slots[oldIndex].key)) {
        merged.add(_exit(_slots[oldIndex]));
      }
    }
    _slots
      ..clear()
      ..addAll(merged);
  }

  _PluginGridSlot<T> _exit(_PluginGridSlot<T> slot) {
    if (slot.removing) return slot;
    slot.removing = true;
    slot.controller.reverse().whenCompleteOrCancel(() {
      // 退场途中重新出现时动画会被取消，此时保留条目。
      if (!mounted || !slot.removing || !slot.controller.isDismissed) return;
      setState(() => _slots.remove(slot));
      slot.dispose();
    });
    return slot;
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  static final _enterScale = Tween<double>(begin: 0.92, end: 1);
  static final _exitScale = Tween<double>(begin: 0.9, end: 1);
  static final _exitOffset = Tween<Offset>(
    begin: const Offset(-0.18, 0),
    end: Offset.zero,
  );

  // 进场与退场共用同一层级结构，只替换驱动动画，避免切换时重建卡片子树。
  Widget _transition(BuildContext context, _PluginGridSlot<T> slot) {
    final removing = slot.removing;
    final visual = removing ? slot.exitAnimation : slot.animation;
    return SizeTransition(
      sizeFactor: removing ? slot.collapseAnimation : slot.animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: visual,
        child: SlideTransition(
          position: removing
              ? _exitOffset.animate(visual)
              : const AlwaysStoppedAnimation(Offset.zero),
          child: ScaleTransition(
            scale: (removing ? _exitScale : _enterScale).animate(visual),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.itemBuilder(context, slot.item),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 800
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        children: [
          for (final slot in _slots)
            KeyedSubtree(
              key: ValueKey(slot.key),
              child: SizedBox(
                width: width,
                child: IgnorePointer(
                  ignoring: slot.removing,
                  child: _transition(context, slot),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// 已安装插件的操作面板，返回用户选择的操作，由页面在面板关闭后执行。
class _PluginActionSheet extends StatelessWidget {
  const _PluginActionSheet({
    required this.plugin,
    required this.subtitle,
    required this.settingsEnabled,
    required this.canCopyRepository,
    this.updateLabel,
    this.updateTrailing,
  });

  final InstalledSourcePlugin plugin;
  final String subtitle;
  final bool settingsEnabled;
  final bool canCopyRepository;
  final String? updateLabel;
  final String? updateTrailing;

  @override
  Widget build(BuildContext context) {
    final s = l10n(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    void pick(_PluginSheetAction action) => Navigator.pop(context, action);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                _PluginAvatar(
                  label: plugin.manifest.name,
                  background: plugin.enabled
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  foreground: plugin.enabled
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.manifest.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 24, endIndent: 24),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            enabled: settingsEnabled,
            leading: const Icon(Icons.tune),
            title: Text(s.settingsTitle),
            onTap: () => pick(_PluginSheetAction.settings),
          ),
          if (updateLabel case final label?)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(
                updateTrailing == null ? Icons.update : Icons.download_rounded,
                color: updateTrailing == null ? null : scheme.tertiary,
              ),
              title: Text(label),
              trailing: updateTrailing == null
                  ? null
                  : Text(
                      updateTrailing!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
              onTap: () => pick(_PluginSheetAction.update),
            ),
          if (canCopyRepository)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.link),
              title: Text(s.pluginsCopyRepository),
              onTap: () => pick(_PluginSheetAction.copyRepository),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            iconColor: scheme.error,
            textColor: scheme.error,
            leading: const Icon(Icons.delete_outline),
            title: Text(s.pluginsUninstall),
            onTap: () => pick(_PluginSheetAction.uninstall),
          ),
        ],
      ),
    );
  }
}

class _PluginBadge extends StatelessWidget {
  const _PluginBadge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: highlighted
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PluginIcon extends StatelessWidget {
  const _PluginIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 24, color: scheme.onSurfaceVariant),
    );
  }
}

class _PluginEmptyState extends StatelessWidget {
  const _PluginEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => _PluginSurface(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _PluginIcon(icon: icon),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PluginError extends StatelessWidget {
  const _PluginError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
