import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';
import 'package:hazuki/widgets/widgets.dart';

/// 进行中下载任务的紧凑卡片：封面 + 单行状态信息 + 细进度条，操作收为右侧图标按钮。
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
    final strings = l10n(context);
    final progress = task.progressValue.clamp(0.0, 1.0);
    final statusMeta = _statusMeta(context, task.status);
    final isDownloading = task.status == MangaDownloadTaskStatus.downloading;
    final isFailed = task.status == MangaDownloadTaskStatus.failed;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusMeta.foreground.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _DownloadTaskCover(task: task),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    convertChineseText(context, task.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _TaskStatusLine(
                    task: task,
                    meta: statusMeta,
                    // 失败状态的标签已包含错误信息，不再拼接章节与图片进度
                    showDetail: !isFailed,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _AnimatedTaskProgressBar(
                          progress: progress,
                          isIndeterminate: isFailed,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: statusMeta.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${task.completedCount}/${task.totalCount}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  tooltip: isDownloading
                      ? strings.downloadsActionPause
                      : strings.downloadsActionResume,
                  style: IconButton.styleFrom(
                    backgroundColor: statusMeta.background,
                    foregroundColor: statusMeta.foreground,
                  ),
                  onPressed: isDownloading
                      ? () => onPauseTask(task.storageKey)
                      : () => onResumeTask(task.storageKey),
                  icon: Icon(
                    isDownloading
                        ? Icons.pause_rounded
                        : isFailed
                        ? Icons.refresh_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: strings.comicDetailDelete,
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () => onDeleteTask(task.storageKey),
                  icon: const Icon(Icons.delete_outline_rounded),
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

/// 状态行：状态圆点与标签，后接当前章节和图片进度（无章节时显示总话数）。
class _TaskStatusLine extends StatelessWidget {
  const _TaskStatusLine({
    required this.task,
    required this.meta,
    required this.showDetail,
  });

  final MangaDownloadTask task;
  final _TaskStatusMeta meta;
  final bool showDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = l10n(context);
    final detailParts = <String>[];
    if (showDetail) {
      final chapterText = task.currentChapterTitle?.trim();
      if (chapterText != null && chapterText.isNotEmpty) {
        detailParts.add(chapterText);
      } else {
        detailParts.add(strings.downloadsChapterCount('${task.totalCount}'));
      }
      if (task.currentImageTotal > 0) {
        detailParts.add(
          strings.downloadsCurrentProgress(
            '${task.currentImageIndex}',
            '${task.currentImageTotal}',
          ),
        );
      }
    }

    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '● ${meta.label}',
            style: TextStyle(
              color: meta.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final part in detailParts) TextSpan(text: ' · $part'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }
}

class _AnimatedTaskProgressBar extends StatelessWidget {
  const _AnimatedTaskProgressBar({
    required this.progress,
    required this.isIndeterminate,
    required this.backgroundColor,
    required this.color,
  });

  final double progress;
  final bool isIndeterminate;
  final Color backgroundColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: isIndeterminate ? null : animatedProgress,
            backgroundColor: backgroundColor,
            color: color,
          ),
        );
      },
    );
  }
}

class _DownloadTaskCover extends StatelessWidget {
  const _DownloadTaskCover({required this.task});

  static const double _width = 48;
  static const double _height = 66;

  final MangaDownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(10);

    Widget image;
    if (task.coverUrl.trim().isNotEmpty) {
      image = HazukiCachedImage(
        url: task.coverUrl,
        sourceKey: task.sourceKey,
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        loading: _buildFallback(theme),
        error: _buildFallback(theme),
      );
    } else {
      image = _buildFallback(theme);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: _width, height: _height, child: image),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.download_rounded,
          size: 22,
          color: theme.colorScheme.onSurfaceVariant,
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
