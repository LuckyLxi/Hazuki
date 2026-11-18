part of 'cloud_sync_page.dart';

/// 上传 / 恢复条目：执行中展开进度条，完成后图标短暂变为勾选。
class _CloudSyncActionTile extends StatelessWidget {
  const _CloudSyncActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busySubtitle,
    required this.busy,
    required this.completed,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String busySubtitle;
  final bool busy;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = _cloudSyncSuccessColor(context);
    final Color badgeColor;
    final Color iconColor;
    if (completed) {
      badgeColor = successColor.withValues(alpha: 0.16);
      iconColor = successColor;
    } else if (busy) {
      badgeColor = colorScheme.primary;
      iconColor = colorScheme.onPrimary;
    } else {
      badgeColor = colorScheme.secondaryContainer;
      iconColor = colorScheme.onSecondaryContainer;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          onTap: onTap,
          leading: AnimatedContainer(
            duration: _cloudSyncMotion,
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: _cloudSyncMotion,
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: _cloudSyncPopTransition,
              child: Icon(
                completed ? Icons.check_rounded : icon,
                key: ValueKey(completed),
                size: 20,
                color: iconColor,
              ),
            ),
          ),
          title: Text(title),
          subtitle: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(busy ? busySubtitle : subtitle, key: ValueKey(busy)),
          ),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: _cloudSyncPopTransition,
            child: busy || completed
                ? const SizedBox(key: ValueKey('idle-hidden'), width: 24)
                : const Icon(
                    Icons.chevron_right_rounded,
                    key: ValueKey('chevron'),
                  ),
          ),
        ),
        AnimatedSize(
          duration: _cloudSyncMotion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 24, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
