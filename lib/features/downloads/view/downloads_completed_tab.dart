import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/manga_download_service.dart';
import 'downloads_action_dock.dart';
import 'downloads_cover_widgets.dart';

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
          child: DownloadsActionDock(
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
