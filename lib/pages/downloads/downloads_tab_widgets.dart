import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/manga_download_service.dart';
import 'downloads_cover_widgets.dart';

class DownloadsOngoingTab extends StatelessWidget {
  const DownloadsOngoingTab({
    super.key,
    required this.tasks,
    required this.onPauseTask,
    required this.onResumeTask,
    required this.onDeleteTask,
  });

  final List<MangaDownloadTask> tasks;
  final ValueChanged<String> onPauseTask;
  final ValueChanged<String> onResumeTask;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(child: Text(l10n(context).downloadsEmptyOngoing));
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final progress = task.progressValue;
        final statusText = switch (task.status) {
          MangaDownloadTaskStatus.queued => l10n(context).downloadsStatusQueued,
          MangaDownloadTaskStatus.downloading => l10n(
            context,
          ).downloadsStatusDownloading,
          MangaDownloadTaskStatus.paused => l10n(context).downloadsStatusPaused,
          MangaDownloadTaskStatus.failed => l10n(
            context,
          ).downloadsStatusFailed(task.errorMessage ?? ''),
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.currentChapterTitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(task.currentChapterTitle!),
                ],
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.status == MangaDownloadTaskStatus.failed
                      ? null
                      : progress.clamp(0.0, 1.0),
                ),
                const SizedBox(height: 8),
                Text(
                  '$statusText  ${task.completedCount}/${task.totalCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (task.currentImageTotal > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n(context).downloadsCurrentProgress(
                      '${task.currentImageIndex}',
                      '${task.currentImageTotal}',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed:
                          task.status == MangaDownloadTaskStatus.downloading
                          ? () => onPauseTask(task.comicId)
                          : () => onResumeTask(task.comicId),
                      icon: Icon(
                        task.status == MangaDownloadTaskStatus.downloading
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      label: Text(
                        task.status == MangaDownloadTaskStatus.downloading
                            ? l10n(context).downloadsActionPause
                            : l10n(context).downloadsActionResume,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onDeleteTask(task.comicId),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n(context).comicDetailDelete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DownloadsCompletedTab extends StatelessWidget {
  const DownloadsCompletedTab({
    super.key,
    required this.comics,
    required this.selectionMode,
    required this.selectedComicIds,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onDeleteComic,
  });

  final List<DownloadedMangaComic> comics;
  final bool selectionMode;
  final Set<String> selectedComicIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    if (comics.isEmpty) {
      return Center(child: Text(l10n(context).downloadsEmptyDownloaded));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: comics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comic = comics[index];
        final selected = selectedComicIds.contains(comic.comicId);
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (selectionMode) {
                onToggleSelection(comic.comicId);
              } else {
                onOpenComic(comic);
              }
            },
            onLongPress: () => onToggleSelection(comic.comicId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  DownloadedComicCover(
                    comic: comic,
                    heroTag: 'downloaded_cover_${comic.comicId}',
                  ),
                  const SizedBox(width: 12),
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
                          const SizedBox(height: 4),
                          Text(
                            comic.subTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          l10n(
                            context,
                          ).downloadsChapterCount('${comic.chapters.length}'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!selectionMode)
                    IconButton(
                      tooltip: l10n(context).comicDetailDelete,
                      onPressed: () => onDeleteComic(comic),
                      icon: const Icon(Icons.delete_outline),
                    )
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selected
                          ? Icon(
                              Icons.check_circle,
                              key: const ValueKey('selected'),
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(
                              Icons.circle_outlined,
                              key: ValueKey('unselected'),
                            ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
