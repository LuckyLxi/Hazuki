import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'downloads_action_dock.dart';
import 'downloads_cover_widgets.dart';

class DownloadsCompletedTab extends StatefulWidget {
  const DownloadsCompletedTab({
    super.key,
    required this.comics,
    required this.selectionMode,
    required this.scanning,
    required this.selectedCount,
    required this.selectedComicIds,
    required this.comicsWithIntegrityIssues,
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
  final Set<String> comicsWithIntegrityIssues;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onDeleteSelected;
  final VoidCallback onScanDownloaded;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  static const Duration dismissDuration = Duration(milliseconds: 320);

  @override
  State<DownloadsCompletedTab> createState() => _DownloadsCompletedTabState();
}

class _DownloadsCompletedTabState extends State<DownloadsCompletedTab> {
  List<_AnimatedDownloadedComicEntry> _visibleComics =
      const <_AnimatedDownloadedComicEntry>[];

  @override
  void initState() {
    super.initState();
    _visibleComics = widget.comics
        .map((comic) => _AnimatedDownloadedComicEntry(comic: comic))
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant DownloadsCompletedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibleComics();
  }

  void _syncVisibleComics() {
    final nextById = <String, DownloadedMangaComic>{
      for (final comic in widget.comics) comic.storageKey: comic,
    };
    final currentById = <String, _AnimatedDownloadedComicEntry>{
      for (final entry in _visibleComics) entry.comic.storageKey: entry,
    };
    final exitingEntries =
        <({int index, _AnimatedDownloadedComicEntry entry})>[];
    final nextVisible = <_AnimatedDownloadedComicEntry>[];

    for (int i = 0; i < _visibleComics.length; i++) {
      final entry = _visibleComics[i];
      final nextComic = nextById[entry.comic.storageKey];
      if (nextComic == null) {
        final exitingEntry = entry.copyWith(exiting: true, entering: false);
        exitingEntries.add((index: i, entry: exitingEntry));
        if (!entry.exiting) {
          _scheduleRemoval(entry.comic.storageKey);
        }
        continue;
      }
    }

    for (final comic in widget.comics) {
      final currentEntry = currentById[comic.storageKey];
      if (currentEntry == null) {
        nextVisible.add(
          _AnimatedDownloadedComicEntry(comic: comic, entering: true),
        );
        _scheduleEnterComplete(comic.storageKey);
        continue;
      }
      nextVisible.add(
        _AnimatedDownloadedComicEntry(
          comic: comic,
          entering: currentEntry.entering,
        ),
      );
    }

    for (final exiting in exitingEntries) {
      final index = exiting.index.clamp(0, nextVisible.length);
      nextVisible.insert(index, exiting.entry);
    }

    if (!_sameEntries(_visibleComics, nextVisible)) {
      setState(() {
        _visibleComics = nextVisible;
      });
    }
  }

  bool _sameEntries(
    List<_AnimatedDownloadedComicEntry> current,
    List<_AnimatedDownloadedComicEntry> next,
  ) {
    if (current.length != next.length) {
      return false;
    }
    for (int i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.comic != b.comic ||
          a.exiting != b.exiting ||
          a.entering != b.entering) {
        return false;
      }
    }
    return true;
  }

  void _scheduleEnterComplete(String storageKey) {
    Future<void>.delayed(DownloadsCompletedTab.dismissDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visibleComics = _visibleComics
            .map((entry) {
              if (entry.comic.storageKey != storageKey || entry.exiting) {
                return entry;
              }
              return entry.copyWith(entering: false);
            })
            .toList(growable: false);
      });
    });
  }

  void _scheduleRemoval(String storageKey) {
    Future<void>.delayed(DownloadsCompletedTab.dismissDuration, () {
      if (!mounted) {
        return;
      }
      if (widget.comics.any((comic) => comic.storageKey == storageKey)) {
        return;
      }
      setState(() {
        _visibleComics = _visibleComics
            .where((entry) => entry.comic.storageKey != storageKey)
            .toList(growable: false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _visibleComics.isEmpty
        ? Center(child: Text(l10n(context).downloadsEmptyDownloaded))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 176),
            itemCount: _visibleComics.length,
            itemBuilder: (context, index) {
              final entry = _visibleComics[index];
              return _AnimatedDownloadedComicCard(
                key: ValueKey<String>('downloaded_${entry.comic.storageKey}'),
                entry: entry,
                bottomSpacing: index == _visibleComics.length - 1 ? 0 : 12,
                selectionMode: widget.selectionMode,
                selected: widget.selectedComicIds.contains(
                  entry.comic.storageKey,
                ),
                hasIntegrityIssue: widget.comicsWithIntegrityIssues.contains(
                  entry.comic.storageKey,
                ),
                onToggleSelection: widget.onToggleSelection,
                onOpenComic: widget.onOpenComic,
                onDeleteComic: widget.onDeleteComic,
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
          child: DownloadsActionDock(
            selectionMode: widget.selectionMode,
            scanning: widget.scanning,
            selectedCount: widget.selectedCount,
            onToggleSelectionMode: widget.onToggleSelectionMode,
            onDeleteSelected: widget.onDeleteSelected,
            onScanDownloaded: widget.onScanDownloaded,
          ),
        ),
      ],
    );
  }
}

class _AnimatedDownloadedComicCard extends StatelessWidget {
  const _AnimatedDownloadedComicCard({
    super.key,
    required this.entry,
    required this.bottomSpacing,
    required this.selectionMode,
    required this.selected,
    required this.hasIntegrityIssue,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onDeleteComic,
  });

  final _AnimatedDownloadedComicEntry entry;
  final double bottomSpacing;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: entry.entering ? 0 : null,
        end: entry.exiting ? 0 : 1,
      ),
      duration: DownloadsCompletedTab.dismissDuration,
      curve: entry.exiting ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              alignment: Alignment.topCenter,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: value,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: _DownloadedComicCard(
        bottomSpacing: bottomSpacing,
        child: _DownloadedComicCardContent(
          comic: entry.comic,
          selectionMode: selectionMode,
          selected: selected,
          hasIntegrityIssue: hasIntegrityIssue,
          onToggleSelection: onToggleSelection,
          onOpenComic: onOpenComic,
          onDeleteComic: onDeleteComic,
        ),
      ),
    );
  }
}

class _DownloadedComicCard extends StatelessWidget {
  const _DownloadedComicCard({
    required this.bottomSpacing,
    required this.child,
  });

  final double bottomSpacing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: child,
    );
  }
}

class _DownloadedComicCardContent extends StatelessWidget {
  const _DownloadedComicCardContent({
    required this.comic,
    required this.selectionMode,
    required this.selected,
    required this.hasIntegrityIssue,
    required this.onToggleSelection,
    required this.onOpenComic,
    required this.onDeleteComic,
  });

  final DownloadedMangaComic comic;
  final bool selectionMode;
  final bool selected;
  final bool hasIntegrityIssue;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DownloadedMangaComic> onOpenComic;
  final ValueChanged<DownloadedMangaComic> onDeleteComic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
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
              onToggleSelection(comic.storageKey);
            } else {
              onOpenComic(comic);
            }
          },
          onLongPress: () => onToggleSelection(comic.storageKey),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    DownloadedComicCover(
                      comic: comic,
                      heroTag: 'downloaded_cover_${comic.storageKey}',
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
                            l10n(
                              context,
                            ).downloadsChapterCount('${comic.chapters.length}'),
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
              if (hasIntegrityIssue)
                _IntegrityWarningBanner(
                  message: l10n(context).downloadsIntegrityWarning,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDownloadedComicEntry {
  const _AnimatedDownloadedComicEntry({
    required this.comic,
    this.entering = false,
    this.exiting = false,
  });

  final DownloadedMangaComic comic;
  final bool entering;
  final bool exiting;

  _AnimatedDownloadedComicEntry copyWith({
    DownloadedMangaComic? comic,
    bool? entering,
    bool? exiting,
  }) {
    return _AnimatedDownloadedComicEntry(
      comic: comic ?? this.comic,
      entering: entering ?? this.entering,
      exiting: exiting ?? this.exiting,
    );
  }
}

class _IntegrityWarningBanner extends StatelessWidget {
  const _IntegrityWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: const Color(0xFFB71C1C),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
