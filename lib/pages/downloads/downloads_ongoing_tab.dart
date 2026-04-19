import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/manga_download_service.dart';
import 'downloads_task_card.dart';

class DownloadsOngoingTab extends StatefulWidget {
  const DownloadsOngoingTab({
    super.key,
    required this.tasks,
    required this.onPauseTask,
    required this.onResumeTask,
    required this.onDeleteTask,
  });

  static const Duration dismissDuration = Duration(milliseconds: 320);

  final List<MangaDownloadTask> tasks;
  final ValueChanged<String> onPauseTask;
  final ValueChanged<String> onResumeTask;
  final ValueChanged<String> onDeleteTask;

  @override
  State<DownloadsOngoingTab> createState() => _DownloadsOngoingTabState();
}

class _DownloadsOngoingTabState extends State<DownloadsOngoingTab> {
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
    Future<void>.delayed(DownloadsOngoingTab.dismissDuration, () {
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
      duration: DownloadsOngoingTab.dismissDuration,
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
      child: DownloadsOngoingTaskCard(
        task: entry.task,
        onPauseTask: onPauseTask,
        onResumeTask: onResumeTask,
        onDeleteTask: onDeleteTask,
      ),
    );
  }
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
