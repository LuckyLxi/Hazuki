part of 'cache_settings_page.dart';

const _cacheMotion = Duration(milliseconds: 280);
const _cacheCountMotion = Duration(milliseconds: 760);

/// 成功态配色，深浅色主题下保持足够对比度。
Color _cacheSuccessColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.green.shade300
      : Colors.green.shade700;
}

String _formatCacheBytes(int bytes) {
  if (bytes <= 0) {
    return '0 MB';
  }
  final mb = bytes / 1024 / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(0)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}

/// 图标互换：淡入并从略小尺寸弹出。
Widget _cachePopTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
      child: child,
    ),
  );
}

/// 文案互换：新文案自下而上滑入。
Widget _cacheSlideUpTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

Widget _cacheLeftAlignedLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  return Stack(
    alignment: Alignment.centerLeft,
    children: [...previousChildren, ?currentChild],
  );
}

/// 进入页面时各区块依次淡入上浮。
class _CacheEntrance extends StatelessWidget {
  const _CacheEntrance({
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.14).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _CacheSectionHeader extends StatelessWidget {
  const _CacheSectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 用量卡片：数值滚动计数，进度条与强调色随占用平滑过渡。
class _CacheUsageCard extends StatelessWidget {
  const _CacheUsageCard({
    required this.title,
    required this.initialized,
    required this.usedBytes,
    required this.maxBytes,
  });

  final String title;
  final bool initialized;
  final int usedBytes;
  final int maxBytes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetRatio = maxBytes > 0
        ? (usedBytes / maxBytes).clamp(0.0, 1.0)
        : 0.0;
    final isHigh = initialized && targetRatio > 0.9;

    return SettingsGroup(
      children: [
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            end: isHigh ? colorScheme.error : colorScheme.primary,
          ),
          duration: _cacheMotion,
          curve: Curves.easeOutCubic,
          builder: (context, accent, _) {
            // 上限首帧不做动画，避免比例从满格回落。
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: maxBytes.toDouble(),
                end: maxBytes.toDouble(),
              ),
              duration: _cacheCountMotion,
              curve: Curves.easeOutCubic,
              builder: (context, animatedMax, _) {
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: usedBytes.toDouble()),
                  duration: _cacheCountMotion,
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedUsed, _) {
                    return _buildContent(
                      context,
                      accent: accent ?? colorScheme.primary,
                      isHigh: isHigh,
                      animatedUsed: animatedUsed,
                      animatedMax: animatedMax,
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required Color accent,
    required bool isHigh,
    required double animatedUsed,
    required double animatedMax,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = animatedMax > 0
        ? (animatedUsed / animatedMax).clamp(0.0, 1.0)
        : 0.0;
    final usedLabel = initialized
        ? _formatCacheBytes(animatedUsed.round())
        : '…';
    const tabular = [FontFeature.tabularFigures()];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: _cacheMotion,
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isHigh
                      ? colorScheme.errorContainer
                      : colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: _cacheMotion,
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: _cachePopTransition,
                  child: initialized
                      ? Icon(
                          Icons.sd_storage_rounded,
                          key: const ValueKey('cache-usage-icon'),
                          size: 20,
                          color: isHigh
                              ? colorScheme.onErrorContainer
                              : colorScheme.onSecondaryContainer,
                        )
                      : SizedBox(
                          key: const ValueKey('cache-usage-loading'),
                          width: 26,
                          height: 26,
                          child: HazukiM3ELoadingIndicator(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '$usedLabel / ${_formatCacheBytes(animatedMax.round())}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: initialized ? 1 : 0,
                duration: _cacheMotion,
                curve: Curves.easeOutCubic,
                child: Text(
                  '${(ratio * 100).round()}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabular,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: AnimatedSwitcher(
                duration: _cacheMotion,
                child: LinearProgressIndicator(
                  // 首次加载为不确定进度，加载完成后切换为实际占比。
                  key: ValueKey(initialized),
                  value: initialized ? ratio : null,
                  minHeight: 6,
                  color: accent,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置条目：值变化时图标轻弹、副标题滑入新值。
class _CacheSettingTile extends StatelessWidget {
  const _CacheSettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: _cacheMotion,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: _cachePopTransition,
          child: Icon(
            icon,
            key: ValueKey(value),
            size: 20,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      title: Text(title),
      subtitle: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        layoutBuilder: _cacheLeftAlignedLayout,
        transitionBuilder: _cacheSlideUpTransition,
        child: Text(value, key: ValueKey(value)),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// 清理条目：执行中展开进度条，完成后图标短暂变为勾选。
class _CacheClearTile extends StatelessWidget {
  const _CacheClearTile({
    required this.title,
    required this.subtitle,
    required this.busySubtitle,
    required this.completedSubtitle,
    required this.busy,
    required this.completed,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String busySubtitle;
  final String completedSubtitle;
  final bool busy;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successColor = _cacheSuccessColor(context);
    final Color badgeColor;
    final Color iconColor;
    final Color titleColor;
    if (completed) {
      badgeColor = successColor.withValues(alpha: 0.16);
      iconColor = successColor;
      titleColor = successColor;
    } else if (busy) {
      badgeColor = colorScheme.error;
      iconColor = colorScheme.onError;
      titleColor = colorScheme.error;
    } else {
      badgeColor = colorScheme.errorContainer;
      iconColor = colorScheme.onErrorContainer;
      titleColor = colorScheme.error;
    }
    final currentSubtitle = completed
        ? completedSubtitle
        : busy
        ? busySubtitle
        : subtitle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          onTap: onTap,
          leading: AnimatedContainer(
            duration: _cacheMotion,
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: _cacheMotion,
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: _cachePopTransition,
              child: Icon(
                completed ? Icons.check_rounded : Icons.delete_sweep_outlined,
                key: ValueKey(completed),
                size: 20,
                color: iconColor,
              ),
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: _cacheMotion,
            curve: Curves.easeOutCubic,
            style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
              color: titleColor,
              fontWeight: FontWeight.w500,
            ),
            child: Text(title),
          ),
          subtitle: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            layoutBuilder: _cacheLeftAlignedLayout,
            transitionBuilder: _cacheSlideUpTransition,
            child: Text(currentSubtitle, key: ValueKey(currentSubtitle)),
          ),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: _cachePopTransition,
            child: busy || completed
                ? const SizedBox(key: ValueKey('idle-hidden'), width: 24)
                : const Icon(
                    Icons.chevron_right_rounded,
                    key: ValueKey('chevron'),
                  ),
          ),
        ),
        AnimatedSize(
          duration: _cacheMotion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 24, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      color: colorScheme.error,
                      backgroundColor: colorScheme.errorContainer,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
