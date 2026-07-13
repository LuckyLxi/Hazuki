// Controller methods guard with the injected mounted callback before they reuse
// the owning reader context after async source calls.
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/support/reader_controller_support.dart';
import 'package:hazuki/features/reader/support/reader_page_context.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/view/reader_comments_sheet.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/shared/downloads/download_conflict_dialog.dart';
import 'package:hazuki/widgets/widgets.dart';

typedef ReaderReplacementPageBuilder =
    Widget Function(ReaderPageContext pageContext);

class ReaderActionsController {
  ReaderActionsController({
    required ReaderContextGetter context,
    required ReaderIsMounted isMounted,
    required ReaderStateUpdate updateState,
    required ReaderLogEvent logEvent,
    required ReaderLogPayloadBuilder logPayload,
    required ReaderSessionController sessionController,
    required ReaderPageContext pageContext,
    required ReaderReplacementPageBuilder buildReplacementPage,
    required MangaDownloadService downloader,
  }) : _context = context,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _sessionController = sessionController,
       _pageContext = pageContext,
       _buildReplacementPage = buildReplacementPage,
       _downloader = downloader;

  final ReaderContextGetter _context;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final ReaderSessionController _sessionController;
  final ReaderPageContext _pageContext;
  final ReaderReplacementPageBuilder _buildReplacementPage;
  final MangaDownloadService _downloader;

  ComicDetailsData? _chapterDetailsCache;
  bool _chapterPanelLoading = false;

  bool get chapterPanelLoading => _chapterPanelLoading;

  Future<ComicDetailsData> loadReaderComicDetails() async {
    final details =
        _chapterDetailsCache ??
        (_pageContext.offlineMode
            ? _buildOfflineComicDetails()
            : await _sessionController.loadComicDetails(
                _pageContext.comicId,
                sourceKey: _pageContext.sourceKey,
              ));
    _chapterDetailsCache ??= details;
    return details;
  }

  ComicDetailsData _buildOfflineComicDetails() {
    final chapters = [..._pageContext.offlineChapters]
      ..sort((a, b) => a.index.compareTo(b.index));
    return ComicDetailsData(
      id: _pageContext.comicId,
      sourceKey: _pageContext.sourceKey,
      title: _pageContext.title,
      subTitle: '',
      cover: _pageContext.coverUrl,
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: {for (final chapter in chapters) chapter.epId: chapter.title},
      tags: const {},
      recommend: const [],
      isFavorite: false,
      subId: '',
    );
  }

  Future<void> openFavoriteDialog() async {
    _logEvent('Reader favorite dialog requested', source: 'reader_ui');
    final onFavoriteRequested = _pageContext.onFavoriteRequested;
    if (onFavoriteRequested == null) {
      return;
    }
    try {
      await onFavoriteRequested(_context());
    } catch (error) {
      if (!_isMounted()) {
        return;
      }
      final context = _context();
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).comicDetailFavoriteSettingsUpdateFailed('$error'),
          isError: true,
        ),
      );
    }
  }

  Future<void> openCommentsSheet() async {
    _logEvent('Reader comments sheet requested', source: 'reader_ui');
    if (_pageContext.offlineMode) {
      return;
    }
    try {
      final details = await loadReaderComicDetails();
      if (!_isMounted()) {
        return;
      }
      final context = _context();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: false,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.46),
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 360),
          reverseDuration: Duration(milliseconds: 260),
        ),
        builder: (routeContext) {
          final themedData = _pageContext.comicTheme ?? Theme.of(routeContext);
          return Theme(
            data: themedData,
            child: ReaderCommentsSheet(
              comicId: details.id,
              subId: details.subId.isEmpty ? null : details.subId,
              chapterId: _pageContext.epId,
              sourceKey: details.sourceKey.isNotEmpty
                  ? details.sourceKey
                  : _pageContext.sourceKey,
              commentsWidgetBuilder: _pageContext.commentsWidgetBuilder,
            ),
          );
        },
      );
    } catch (error) {
      if (!_isMounted()) {
        return;
      }
      final context = _context();
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsLoadFailed('$error'),
          isError: true,
        ),
      );
    }
  }

  Future<void> openChaptersPanel() async {
    if (_chapterPanelLoading) {
      return;
    }
    final hadCachedChapterDetails = _chapterDetailsCache != null;
    _updateState(() {
      _chapterPanelLoading = true;
    });
    _logEvent(
      'Reader chapters panel requested',
      source: 'reader_navigation',
      content: _logPayload({
        'hadCachedChapterDetails': hadCachedChapterDetails,
      }),
    );
    try {
      final details = await loadReaderComicDetails();
      if (!_isMounted()) {
        return;
      }
      _logEvent(
        'Reader chapters panel opened',
        source: 'reader_navigation',
        content: _logPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
        }),
      );
      final context = _context();
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: true,
          useSafeArea: false,
          sheetAnimationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 380),
            reverseDuration: Duration(milliseconds: 280),
          ),
          builder: (routeContext) {
            final themedData =
                _pageContext.comicTheme ?? Theme.of(routeContext);
            return Theme(
              data: themedData,
              child: ChaptersPanelSheet(
                details: details,
                onDownloadConfirm: (selectedEpIds) {
                  Navigator.of(routeContext).pop();
                  unawaited(
                    _enqueueChapterDownloads(
                      context,
                      details,
                      selectedEpIds: selectedEpIds,
                    ),
                  );
                },
                onChapterTap: (epId, chapterTitle, index) {
                  unawaited(
                    handleChapterSelectedFromPanel(
                      routeContext,
                      epId,
                      chapterTitle,
                      index,
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    } catch (error) {
      _logEvent(
        'Reader chapters panel failed',
        level: 'error',
        source: 'reader_navigation',
        content: _logPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
          'error': '$error',
        }),
      );
      if (!_isMounted()) {
        return;
      }
      final context = _context();
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).readerChapterLoadFailed('$error'),
          isError: true,
        ),
      );
    } finally {
      if (_isMounted()) {
        _updateState(() {
          _chapterPanelLoading = false;
        });
      }
    }
  }

  Future<void> _enqueueChapterDownloads(
    BuildContext context,
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

    var queuedTargets = targets;
    try {
      _logEvent(
        'Reader chapter downloads requested',
        source: 'reader_download',
        content: _logPayload({
          'selectedChapterCount': selectedEpIds.length,
          'targetChapterCount': targets.length,
        }),
      );
      final taskConflict = await _downloader.checkDownloadTaskConflict(
        details: details,
        chapters: targets,
      );
      if (!_isMounted() || !context.mounted) {
        return;
      }
      if (taskConflict.hasConflict) {
        final queuedEpIds = taskConflict.existingChapters
            .map((chapter) => chapter.epId)
            .toSet();
        queuedTargets = targets
            .where((chapter) => !queuedEpIds.contains(chapter.epId))
            .toList(growable: false);
      }
      if (queuedTargets.isEmpty) {
        unawaited(
          showHazukiPrompt(context, l10n(context).downloadsAlreadyInQueue),
        );
        return;
      }

      final downloadConflictTargets = queuedTargets;
      final conflict = await _downloader.checkDownloadConflict(
        details: details,
        chapters: downloadConflictTargets,
      );
      if (!_isMounted() || !context.mounted) {
        return;
      }
      var redownloadExisting = false;
      if (conflict.hasConflict) {
        final hasUndownloadedChapters =
            conflict.existingChapters.length < queuedTargets.length;
        final dialogTheme = _pageContext.comicTheme ?? Theme.of(context);
        if (hasUndownloadedChapters) {
          final action = await showSkipDownloadedChaptersDialog(
            context,
            conflict: conflict,
            dialogTheme: dialogTheme,
            key: const Key('reader-skip-downloaded-dialog'),
          );
          if (action == null || !_isMounted() || !context.mounted) {
            return;
          }
          if (action == DownloadedChapterConflictAction.skip) {
            final existingEpIds = conflict.existingChapters
                .map((chapter) => chapter.epId)
                .toSet();
            queuedTargets = queuedTargets
                .where((chapter) => !existingEpIds.contains(chapter.epId))
                .toList(growable: false);
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 260));
            if (!_isMounted() || !context.mounted) {
              return;
            }
          }
        }
        if (!hasUndownloadedChapters ||
            queuedTargets.length == downloadConflictTargets.length) {
          redownloadExisting = await showDownloadConflictDialog(
            context,
            conflict: conflict,
            dialogTheme: dialogTheme,
            key: const Key('reader-download-conflict-dialog'),
          );
          if (!redownloadExisting || !_isMounted() || !context.mounted) {
            return;
          }
        }
      }

      final result = await _downloader.enqueueDownload(
        details: details,
        coverUrl: details.cover.trim().isNotEmpty
            ? details.cover
            : _pageContext.coverUrl,
        description: details.description,
        chapters: queuedTargets,
        redownloadExisting: redownloadExisting,
      );
      if (!_isMounted() || !context.mounted) {
        return;
      }
      if (result == MangaDownloadEnqueueResult.alreadyQueued) {
        unawaited(
          showHazukiPrompt(context, l10n(context).downloadsAlreadyInQueue),
        );
        return;
      }
      if (result == MangaDownloadEnqueueResult.nothingToQueue) {
        return;
      }
    } catch (error) {
      _logEvent(
        'Reader chapter downloads failed',
        level: 'error',
        source: 'reader_download',
        content: _logPayload({'error': '$error'}),
      );
      if (!_isMounted() || !context.mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).downloadsQueueFailed('$error'),
          isError: true,
        ),
      );
      return;
    }

    _logEvent(
      'Reader chapter downloads queued',
      source: 'reader_download',
      content: _logPayload({'queuedChapterCount': queuedTargets.length}),
    );
    if (!_isMounted() || !context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        l10n(context).downloadsQueued('${queuedTargets.length}'),
      ),
    );
  }

  Future<void> handleChapterSelectedFromPanel(
    BuildContext routeContext,
    String epId,
    String chapterTitle,
    int index,
  ) async {
    Navigator.of(routeContext).pop();
    if (epId == _pageContext.epId) {
      _logEvent(
        'Reader chapter selection ignored',
        source: 'reader_navigation',
        content: _logPayload({
          'targetEpId': epId,
          'targetChapterTitle': chapterTitle,
          'targetChapterIndex': index,
          'reason': 'already_current_chapter',
        }),
      );
      return;
    }
    _logEvent(
      'Reader chapter selected',
      source: 'reader_navigation',
      content: _logPayload({
        'targetEpId': epId,
        'targetChapterTitle': chapterTitle,
        'targetChapterIndex': index,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!_isMounted()) {
      return;
    }
    await Navigator.of(_context()).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _buildReplacementPage(
          _pageContext.copyForChapter(
            epId: epId,
            chapterTitle: chapterTitle,
            chapterIndex: index,
          ),
        ),
      ),
    );
  }

  Future<void> jumpToAdjacentChapter(int offset) async {
    final context = _context();
    final navigator = Navigator.of(context);
    final strings = l10n(context);
    try {
      final details = await loadReaderComicDetails();
      final chapterEntries = details.chapters.entries.toList(growable: false);
      if (chapterEntries.isEmpty) {
        return;
      }

      var currentChapterIndex = chapterEntries.indexWhere(
        (entry) => entry.key == _pageContext.epId,
      );
      if (currentChapterIndex < 0) {
        currentChapterIndex = _pageContext.chapterIndex.clamp(
          0,
          chapterEntries.length - 1,
        );
      }
      final targetIndex = currentChapterIndex + offset;

      if (targetIndex < 0) {
        if (_isMounted()) {
          unawaited(showHazukiPrompt(context, strings.readerNoPreviousChapter));
        }
        return;
      }
      if (targetIndex >= chapterEntries.length) {
        if (_isMounted()) {
          unawaited(
            showHazukiPrompt(context, strings.readerAlreadyLastChapter),
          );
        }
        return;
      }

      final targetChapter = chapterEntries[targetIndex];
      _logEvent(
        'Reader adjacent chapter navigation requested',
        source: 'reader_navigation',
        content: _logPayload({
          'offset': offset,
          'fromChapterIndex': currentChapterIndex,
          'targetChapterIndex': targetIndex,
          'targetEpId': targetChapter.key,
          'targetChapterTitle': targetChapter.value,
        }),
      );

      if (!_isMounted()) {
        return;
      }
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _buildReplacementPage(
            _pageContext.copyForChapter(
              epId: targetChapter.key,
              chapterTitle: targetChapter.value,
              chapterIndex: targetIndex,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!_isMounted()) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.readerChapterLoadFailed('$error'),
          isError: true,
        ),
      );
    }
  }
}
