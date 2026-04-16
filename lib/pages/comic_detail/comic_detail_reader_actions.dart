part of '../comic_detail_page.dart';

extension _ComicDetailReaderActionsExtension on _ComicDetailPageState {
  void _showChaptersPanel(ComicDetailsData details) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (details.chapters.isEmpty) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapterInfo,
          isError: true,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        reverseDuration: const Duration(milliseconds: 220),
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (routeContext) {
        final themedData = _buildDetailTheme(Theme.of(routeContext));
        return Theme(
          data: themedData,
          child: ChaptersPanelSheet(
            details: details,
            onDownloadConfirm: (selectedEpIds) {
              Navigator.of(routeContext).pop();
              unawaited(
                _enqueueChapterDownloads(details, selectedEpIds: selectedEpIds),
              );
            },
            onChapterTap: (epId, chapterTitle, index) {
              Navigator.of(routeContext).pop();
              unawaited(
                _openReader(
                  details,
                  epId: epId,
                  chapterTitle: chapterTitle,
                  chapterIndex: index,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _enqueueChapterDownloads(
    ComicDetailsData details, {
    required Set<String> selectedEpIds,
  }) async {
    if (selectedEpIds.isEmpty) {
      return;
    }
    final targets = <MangaChapterDownloadTarget>[];
    for (var i = 0; i < details.chapters.length; i++) {
      final entry = details.chapters.entries.elementAt(i);
      if (selectedEpIds.contains(entry.key)) {
        targets.add(
          MangaChapterDownloadTarget(
            epId: entry.key,
            title: resolveHazukiChapterTitle(context, entry.value),
            index: i,
          ),
        );
      }
    }
    if (targets.isEmpty) {
      return;
    }
    await MangaDownloadService.instance.enqueueDownload(
      details: details,
      coverUrl: details.cover.trim().isNotEmpty
          ? details.cover
          : widget.comic.cover,
      description: details.description,
      chapters: targets,
    );
    if (!mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        l10n(context).downloadsQueued('${targets.length}'),
      ),
    );
  }

  Future<void> _openReader(
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chapters = details.chapters;
    if (chapters.isEmpty) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailNoChapters,
          isError: true,
        ),
      );
      return;
    }

    MapEntry<String, String>? initialEntry;
    int finalIndex = 0;

    final hasMemory =
        _lastReadProgress != null &&
        chapters.containsKey(_lastReadProgress!['epId']) &&
        chapters.length > 1;

    if (epId != null && chapters.containsKey(epId)) {
      initialEntry = MapEntry(epId, chapters[epId]!);
      finalIndex = chapterIndex ?? chapters.keys.toList().indexOf(epId);
    } else if (hasMemory) {
      final memEpId = _lastReadProgress!['epId'] as String;
      initialEntry = MapEntry(memEpId, chapters[memEpId]!);
      finalIndex = _lastReadProgress!['index'] as int;
    } else {
      initialEntry = chapters.entries.first;
      finalIndex = 0;
    }

    final initialChapterTitle = resolveHazukiChapterTitle(
      context,
      (chapterTitle != null && chapterTitle.isNotEmpty)
          ? chapterTitle
          : initialEntry.value,
    );

    await Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderPage(
              title: details.title,
              chapterTitle: initialChapterTitle,
              comicId: details.id,
              epId: initialEntry!.key,
              chapterIndex: finalIndex,
              images: const [],
              comicTheme: _buildDetailTheme(Theme.of(context)),
            ),
          ),
        )
        .then((_) {
          FocusManager.instance.primaryFocus?.unfocus();
          if (mounted) {
            unawaited(_loadReadingProgress());
          }
        });
  }
}
