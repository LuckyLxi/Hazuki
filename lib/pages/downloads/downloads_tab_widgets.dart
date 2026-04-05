import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/manga_download_service.dart';
import '../../widgets/widgets.dart';
import 'downloads_cover_widgets.dart';

class DownloadsOngoingTab extends StatefulWidget {
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
  State<DownloadsOngoingTab> createState() => _DownloadsOngoingTabState();
}

class _DownloadsOngoingTabState extends State<DownloadsOngoingTab> {
  static const Duration dismissDuration = Duration(milliseconds: 320);

  List<_AnimatedTaskEntry> _visibleTasks = const <_AnimatedTaskEntry>[];

  @override
  void initState() {
    super.initState();
    _visibleTasks = widget.tasks
        .map((task) => _AnimatedTaskEntry(task: task))
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant DownloadsOngoingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibleTasks();
  }

  void _syncVisibleTasks() {
    final nextById = <String, MangaDownloadTask>{
      for (final task in widget.tasks) task.comicId: task,
    };
    final retainedIds = <String>{};
    final nextVisible = <_AnimatedTaskEntry>[];

    for (final entry in _visibleTasks) {
      final nextTask = nextById[entry.task.comicId];
      if (nextTask != null) {
        nextVisible.add(_AnimatedTaskEntry(task: nextTask));
        retainedIds.add(entry.task.comicId);
        continue;
      }
      nextVisible.add(entry.copyWith(exiting: true));
      if (!entry.exiting) {
        _scheduleRemoval(entry.task.comicId);
      }
    }

    for (final task in widget.tasks) {
      if (retainedIds.add(task.comicId)) {
        nextVisible.add(_AnimatedTaskEntry(task: task));
      }
    }

    if (!_sameEntries(_visibleTasks, nextVisible)) {
      setState(() {
        _visibleTasks = nextVisible;
      });
    }
  }

  bool _sameEntries(
    List<_AnimatedTaskEntry> current,
    List<_AnimatedTaskEntry> next,
  ) {
    if (current.length != next.length) {
      return false;
    }
    for (int i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.task != b.task || a.exiting != b.exiting) {
        return false;
      }
    }
    return true;
  }

  void _scheduleRemoval(String comicId) {
    Future<void>.delayed(dismissDuration, () {
      if (!mounted) {
        return;
      }
      if (widget.tasks.any((task) => task.comicId == comicId)) {
        return;
      }
      setState(() {
        _visibleTasks = _visibleTasks
            .where((entry) => entry.task.comicId != comicId)
            .toList(growable: false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_visibleTasks.isEmpty) {
      return Center(child: Text(l10n(context).downloadsEmptyOngoing));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _visibleTasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = _visibleTasks[index];
        return _AnimatedOngoingTaskCard(
          key: ValueKey<String>('ongoing_${entry.task.comicId}'),
          entry: entry,
          onPauseTask: widget.onPauseTask,
          onResumeTask: widget.onResumeTask,
          onDeleteTask: widget.onDeleteTask,
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
    required this.scanning,
    required this.selectedCount,
    required this.selectedComicIds,
    required this.onToggleSelection,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
    required this.onScanDownloaded,
    required this.onOpenComic,
    required this.onDeleteComic,
  });

  final List<DownloadedMangaComic> comics;
  final bool selectionMode;
  final bool scanning;
  final int selectedCount;
  final Set<String> selectedComicIds;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final content = comics.isEmpty
        ? Center(child: Text(l10n(context).downloadsEmptyDownloaded))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 176),
            itemCount: comics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final comic = comics[index];
              final selected = selectedComicIds.contains(comic.comicId);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.secondaryContainer.withValues(alpha: 0.96)
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.34)
                        : colorScheme.outlineVariant.withValues(alpha: 0.36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
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
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (comic.subTitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    comic.subTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  l10n(context).downloadsChapterCount(
                                    '${comic.chapters.length}',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _DownloadedComicTrailingAction(
                            selectionMode: selectionMode,
                            selected: selected,
                            onDelete: () => onDeleteComic(comic),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          right: 16,
          bottom: 16 + bottomInset,
          child: _DownloadsActionDock(
            selectionMode: selectionMode,
            scanning: scanning,
            selectedCount: selectedCount,
            onToggleSelectionMode: onToggleSelectionMode,
            onDeleteSelected: onDeleteSelected,
            onScanDownloaded: onScanDownloaded,
          ),
        ),
      ],
    );
  }
}

class _AnimatedOngoingTaskCard extends StatelessWidget {
  const _AnimatedOngoingTaskCard({
    super.key,
    required this.entry,
    required this.onPauseTask,
    required this.onResumeTask,
    required this.onDeleteTask,
  });

  final _AnimatedTaskEntry entry;
  final ValueChanged<String> onPauseTask;
  final ValueChanged<String> onResumeTask;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: entry.exiting ? 0 : 1),
      duration: _DownloadsOngoingTabState.dismissDuration,
      curve: entry.exiting ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            alignment: Alignment.topCenter,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: _OngoingTaskCard(
        task: entry.task,
        onPauseTask: onPauseTask,
        onResumeTask: onResumeTask,
        onDeleteTask: onDeleteTask,
      ),
    );
  }
}

class _OngoingTaskCard extends StatelessWidget {
  const _OngoingTaskCard({
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
                        ? () => onPauseTask(task.comicId)
                        : () => onResumeTask(task.comicId),
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
                    onPressed: () => onDeleteTask(task.comicId),
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

class _DownloadedComicTrailingAction extends StatelessWidget {
  const _DownloadedComicTrailingAction({
    required this.selectionMode,
    required this.selected,
    required this.onDelete,
  });

  final bool selectionMode;
  final bool selected;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.16, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: selectionMode
            ? AnimatedContainer(
                key: ValueKey<bool>(selected),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.16)
                      : colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: selected ? 2 : 1.4,
                  ),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.circle_outlined,
                  size: selected ? 18 : 20,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              )
            : IconButton(
                key: const ValueKey<String>('delete_action'),
                tooltip: l10n(context).comicDetailDelete,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
      ),
    );
  }
}

class _DownloadsActionDock extends StatelessWidget {
  const _DownloadsActionDock({
    required this.selectionMode,
    required this.scanning,
    required this.selectedCount,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
    required this.onScanDownloaded,
  });

  final bool selectionMode;
  final bool scanning;
  final int selectedCount;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: selectionMode
                  ? _DownloadsActionButton(
                      key: const ValueKey<String>('downloads_delete_action'),
                      tooltip: l10n(context).comicDetailDelete,
                      icon: Icons.delete_outline_rounded,
                      accentColor: colorScheme.errorContainer,
                      iconColor: colorScheme.onErrorContainer,
                      onPressed: selectedCount > 0 ? onDeleteSelected : null,
                    )
                  : _DownloadsActionButton(
                      key: const ValueKey<String>('downloads_scan_action'),
                      tooltip: l10n(context).downloadsScanTooltip,
                      icon: Icons.manage_search_rounded,
                      accentColor: colorScheme.primaryContainer,
                      iconColor: colorScheme.onPrimaryContainer,
                      onPressed: scanning ? null : onScanDownloaded,
                      busy: scanning,
                    ),
            ),
            Container(
              width: 34,
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: colorScheme.outlineVariant,
            ),
            _DownloadsActionButton(
              tooltip: selectionMode
                  ? l10n(context).commonClose
                  : l10n(context).downloadsActionSelect,
              icon: selectionMode
                  ? Icons.close_rounded
                  : Icons.checklist_rounded,
              accentColor: selectionMode
                  ? colorScheme.secondaryContainer
                  : colorScheme.tertiaryContainer,
              iconColor: selectionMode
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onTertiaryContainer,
              onPressed: onToggleSelectionMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsActionButton extends StatelessWidget {
  const _DownloadsActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.accentColor,
    required this.iconColor,
    required this.onPressed,
    this.busy = false,
  });

  final String tooltip;
  final IconData icon;
  final Color accentColor;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: accentColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: busy
                  ? SizedBox(
                      key: const ValueKey<String>('downloads_action_busy'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(icon, key: ValueKey<IconData>(icon), color: iconColor),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: tooltip, child: button);
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

class _AnimatedTaskEntry {
  const _AnimatedTaskEntry({required this.task, this.exiting = false});

  final MangaDownloadTask task;
  final bool exiting;

  _AnimatedTaskEntry copyWith({MangaDownloadTask? task, bool? exiting}) {
    return _AnimatedTaskEntry(
      task: task ?? this.task,
      exiting: exiting ?? this.exiting,
    );
  }
}
