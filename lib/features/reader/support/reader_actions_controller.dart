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
  }) : _context = context,
       _isMounted = isMounted,
       _updateState = updateState,
       _logEvent = logEvent,
       _logPayload = logPayload,
       _sessionController = sessionController,
       _pageContext = pageContext,
       _buildReplacementPage = buildReplacementPage;

  final ReaderContextGetter _context;
  final ReaderIsMounted _isMounted;
  final ReaderStateUpdate _updateState;
  final ReaderLogEvent _logEvent;
  final ReaderLogPayloadBuilder _logPayload;
  final ReaderSessionController _sessionController;
  final ReaderPageContext _pageContext;
  final ReaderReplacementPageBuilder _buildReplacementPage;

  ComicDetailsData? _chapterDetailsCache;
  bool _chapterPanelLoading = false;

  bool get chapterPanelLoading => _chapterPanelLoading;

  Future<ComicDetailsData> loadReaderComicDetails() async {
    final details =
        _chapterDetailsCache ??
        await _sessionController.loadComicDetails(
          _pageContext.comicId,
          sourceKey: _pageContext.sourceKey,
        );
    _chapterDetailsCache ??= details;
    return details;
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
                onDownloadConfirm: (_) {
                  Navigator.of(routeContext).pop();
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
