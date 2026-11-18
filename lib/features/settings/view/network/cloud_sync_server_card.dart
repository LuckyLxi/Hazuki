part of 'cloud_sync_page.dart';

enum _CloudSyncServerStatus { checking, connected, disconnected, unchecked }

/// 状态对应的前景色与浅色底。
({Color foreground, Color background}) _resolveServerStatusColors(
  BuildContext context,
  _CloudSyncServerStatus status,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status) {
    _CloudSyncServerStatus.connected => (
      foreground: _cloudSyncSuccessColor(context),
      background: _cloudSyncSuccessColor(context).withValues(alpha: 0.14),
    ),
    _CloudSyncServerStatus.disconnected => (
      foreground: colorScheme.error,
      background: colorScheme.error.withValues(alpha: 0.12),
    ),
    _CloudSyncServerStatus.checking => (
      foreground: colorScheme.primary,
      background: colorScheme.primary.withValues(alpha: 0.12),
    ),
    _CloudSyncServerStatus.unchecked => (
      foreground: colorScheme.onSurfaceVariant,
      background: colorScheme.surfaceContainerHighest,
    ),
  };
}

/// 已配置服务器的账号式卡片。
class _CloudSyncServerCard extends StatelessWidget {
  const _CloudSyncServerCard({
    super.key,
    required this.url,
    required this.username,
    required this.status,
    required this.failureMessage,
    required this.onTest,
    required this.onEdit,
  });

  final String url;
  final String username;
  final _CloudSyncServerStatus status;
  final String failureMessage;
  final VoidCallback? onTest;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uri = Uri.tryParse(url);
    final host = uri != null && uri.host.isNotEmpty ? uri.host : url;
    final showFailure =
        status == _CloudSyncServerStatus.disconnected &&
        failureMessage.trim().isNotEmpty;

    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _CloudSyncServerAvatar(status: status),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CloudSyncStatusChip(status: status),
                ],
              ),
              AnimatedSize(
                duration: _cloudSyncMotion,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: _cloudSyncMotion,
                  child: showFailure
                      ? Padding(
                          key: const ValueKey('failure'),
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              failureMessage.trim(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('no-failure'),
                          width: double.infinity,
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTest,
                      icon: const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(strings.cloudSyncTestConnection),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(strings.cloudSyncEditServer),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 头像：底色随状态渐变，检测中外圈转动。
class _CloudSyncServerAvatar extends StatelessWidget {
  const _CloudSyncServerAvatar({required this.status});

  final _CloudSyncServerStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveServerStatusColors(context, status);
    final icon = switch (status) {
      _CloudSyncServerStatus.connected => Icons.cloud_done_outlined,
      _CloudSyncServerStatus.disconnected => Icons.cloud_off_outlined,
      _ => Icons.cloud_outlined,
    };
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: _cloudSyncMotion,
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: _cloudSyncMotion,
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: _cloudSyncPopTransition,
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 22,
                color: colors.foreground,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: status == _CloudSyncServerStatus.checking
                ? SizedBox.expand(
                    key: const ValueKey('ring'),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.foreground,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-ring')),
          ),
        ],
      ),
    );
  }
}

/// 状态标签：颜色渐变、宽度平滑过渡、内容缩放切换。
class _CloudSyncStatusChip extends StatelessWidget {
  const _CloudSyncStatusChip({required this.status});

  final _CloudSyncServerStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colors = _resolveServerStatusColors(context, status);
    final label = switch (status) {
      _CloudSyncServerStatus.checking => strings.cloudSyncStatusChecking,
      _CloudSyncServerStatus.connected => strings.cloudSyncStatusConnected,
      _CloudSyncServerStatus.disconnected =>
        strings.cloudSyncStatusDisconnected,
      _CloudSyncServerStatus.unchecked => strings.cloudSyncStatusUnchecked,
    };
    final Widget leading = switch (status) {
      _CloudSyncServerStatus.checking => SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          color: colors.foreground,
        ),
      ),
      _CloudSyncServerStatus.connected => Icon(
        Icons.check_circle_rounded,
        size: 14,
        color: colors.foreground,
      ),
      _CloudSyncServerStatus.disconnected => Icon(
        Icons.error_outline_rounded,
        size: 14,
        color: colors.foreground,
      ),
      _CloudSyncServerStatus.unchecked => Icon(
        Icons.help_outline_rounded,
        size: 14,
        color: colors.foreground,
      ),
    };

    return AnimatedContainer(
      duration: _cloudSyncMotion,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedSize(
        duration: _cloudSyncMotion,
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: _cloudSyncPopTransition,
          child: Row(
            key: ValueKey(status),
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 尚未配置服务器时的引导卡片。
class _CloudSyncEmptyServerCard extends StatelessWidget {
  const _CloudSyncEmptyServerCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.dns_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.cloudSyncAddServerTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                strings.cloudSyncAddServerSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(strings.cloudSyncAddServer),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
