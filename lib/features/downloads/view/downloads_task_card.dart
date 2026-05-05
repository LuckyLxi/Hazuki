import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'package:hazuki/widgets/widgets.dart';

class DownloadsOngoingTaskCard extends StatelessWidget {
  const DownloadsOngoingTaskCard({
    super.key,
    required this.task,
    required this.onPauseTask,
    required this.onResumeTask,
    required this.onDeleteTask,
  });

  final MangaDownloadTask task;
  final ValueChanged<String> onPauseTask;
  final ValueChanged<String> onResumeTask;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = task.progressValue.clamp(0.0, 1.0);
    final progressPercent = '${(progress * 100).round()}%';
    final statusMeta = _statusMeta(context, task.status);
    final chapterText = task.currentChapterTitle?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainerLow,
          ],
        ),
        border: Border.all(
          color: statusMeta.foreground.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DownloadTaskCover(
                  task: task,
                  accentColor: statusMeta.foreground,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _TaskStatusChip(meta: statusMeta),
                        ],
                      ),
                      if (task.subTitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.subTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (chapterText != null && chapterText.isNotEmpty)
                        Text(
                          chapterText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        Text(
                          l10n(
                            context,
                          ).downloadsChapterCount('${task.totalCount}'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TaskInfoPill(
                            icon: Icons.menu_book_rounded,
                            label: '${task.completedCount}/${task.totalCount}',
                          ),
                          _TaskInfoPill(
                            icon: Icons.percent_rounded,
                            label: progressPercent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: task.status == MangaDownloadTaskStatus.failed
                    ? null
                    : progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: statusMeta.foreground,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.currentImageTotal > 0
                        ? l10n(context).downloadsCurrentProgress(
                            '${task.currentImageIndex}',
                            '${task.currentImageTotal}',
                          )
                        : l10n(
                            context,
                          ).downloadsChapterCount('${task.totalCount}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (task.status == MangaDownloadTaskStatus.failed &&
                task.errorMessage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                task.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed:
                        task.status == MangaDownloadTaskStatus.downloading
                        ? () => onPauseTask(task.storageKey)
                        : () => onResumeTask(task.storageKey),
                    icon: Icon(
                      task.status == MangaDownloadTaskStatus.downloading
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                    ),
                    label: Text(
                      task.status == MangaDownloadTaskStatus.downloading
                          ? l10n(context).downloadsActionPause
                          : l10n(context).downloadsActionResume,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onDeleteTask(task.storageKey),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n(context).comicDetailDelete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _TaskStatusMeta _statusMeta(
    BuildContext context,
    MangaDownloadTaskStatus status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      MangaDownloadTaskStatus.queued => _TaskStatusMeta(
        label: l10n(context).downloadsStatusQueued,
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      ),
      MangaDownloadTaskStatus.downloading => _TaskStatusMeta(
        label: l10n(context).downloadsStatusDownloading,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.primary,
      ),
      MangaDownloadTaskStatus.paused => _TaskStatusMeta(
        label: l10n(context).downloadsStatusPaused,
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      ),
      MangaDownloadTaskStatus.failed => _TaskStatusMeta(
        label: l10n(context).downloadsStatusFailed(task.errorMessage ?? ''),
        background: colorScheme.errorContainer,
        foreground: colorScheme.error,
      ),
    };
  }
}

class _DownloadTaskCover extends StatelessWidget {
  const _DownloadTaskCover({required this.task, required this.accentColor});

  final MangaDownloadTask task;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(18);

    Widget image;
    if (task.coverUrl.trim().isNotEmpty) {
      image = HazukiCachedImage(
        url: task.coverUrl,
        sourceKey: task.sourceKey,
        width: 84,
        height: 118,
        fit: BoxFit.cover,
        loading: _buildFallback(theme, borderRadius),
        error: _buildFallback(theme, borderRadius),
      );
    } else {
      image = _buildFallback(theme, borderRadius);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          SizedBox(width: 84, height: 118, child: image),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.14),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentColor.withValues(alpha: 0.28)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '${task.completedCount}/${task.totalCount}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(ThemeData theme, BorderRadius borderRadius) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.download_rounded,
        size: 30,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TaskInfoPill extends StatelessWidget {
  const _TaskInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({required this.meta});

  final _TaskStatusMeta meta;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          meta.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: meta.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TaskStatusMeta {
  const _TaskStatusMeta({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
