part of 'reader_page.dart';

extension _ReaderPageStateChapterActions on _ReaderPageState {
  Future<void> _handlePlatformVolumeButtonPressed(String? direction) {
    return _navigationController.handlePlatformVolumeButtonPressed(direction);
  }

  void _openReaderSettingsDrawer() {
    _logReaderEvent('Reader settings drawer opened', source: 'reader_settings');
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _openChaptersPanel() async {
    if (_chapterPanelLoading) {
      return;
    }
    final hadCachedChapterDetails = _chapterDetailsCache != null;
    _updateReaderState(() {
      _chapterPanelLoading = true;
    });
    _logReaderEvent(
      'Reader chapters panel requested',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'hadCachedChapterDetails': hadCachedChapterDetails,
      }),
    );
    try {
      final details =
          _chapterDetailsCache ??
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      if (!mounted) {
        return;
      }
      _logReaderEvent(
        'Reader chapters panel opened',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
        }),
      );
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
          final themedData = widget.comicTheme ?? Theme.of(routeContext);
          return Theme(
            data: themedData,
            child: ChaptersPanelSheet(
              details: details,
              onDownloadConfirm: (_) {
                Navigator.of(routeContext).pop();
              },
              onChapterTap: (epId, chapterTitle, index) {
                unawaited(
                  _handleChapterSelectedFromPanel(
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
      );
    } catch (error) {
      _logReaderEvent(
        'Reader chapters panel failed',
        level: 'error',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'hadCachedChapterDetails': hadCachedChapterDetails,
          'error': '$error',
        }),
      );
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).readerChapterLoadFailed('$error'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        _updateReaderState(() {
          _chapterPanelLoading = false;
        });
      }
    }
  }

  Future<void> _handleChapterSelectedFromPanel(
    BuildContext routeContext,
    String epId,
    String chapterTitle,
    int index,
  ) async {
    Navigator.of(routeContext).pop();
    if (epId == widget.epId) {
      _logReaderEvent(
        'Reader chapter selection ignored',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'targetEpId': epId,
          'targetChapterTitle': chapterTitle,
          'targetChapterIndex': index,
          'reason': 'already_current_chapter',
        }),
      );
      return;
    }
    _logReaderEvent(
      'Reader chapter selected',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'targetEpId': epId,
        'targetChapterTitle': chapterTitle,
        'targetChapterIndex': index,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          title: widget.title,
          chapterTitle: chapterTitle,
          comicId: widget.comicId,
          epId: epId,
          chapterIndex: index,
          images: const [],
          comicTheme: widget.comicTheme,
        ),
      ),
    );
  }

  Future<void> _jumpToAdjacentChapter(int offset) async {
    final navigator = Navigator.of(context);
    final strings = l10n(context);
    try {
      final details =
          _chapterDetailsCache ??
          await HazukiSourceService.instance.loadComicDetails(widget.comicId);
      _chapterDetailsCache ??= details;
      final chapterEntries = details.chapters.entries.toList(growable: false);
      if (chapterEntries.isEmpty) {
        return;
      }

      var currentChapterIndex = chapterEntries.indexWhere(
        (entry) => entry.key == widget.epId,
      );
      if (currentChapterIndex < 0) {
        currentChapterIndex = widget.chapterIndex.clamp(
          0,
          chapterEntries.length - 1,
        );
      }
      final targetIndex = currentChapterIndex + offset;

      if (targetIndex < 0) {
        if (mounted) {
          unawaited(showHazukiPrompt(context, strings.readerNoPreviousChapter));
        }
        return;
      }
      if (targetIndex >= chapterEntries.length) {
        if (mounted) {
          unawaited(
            showHazukiPrompt(context, strings.readerAlreadyLastChapter),
          );
        }
        return;
      }

      final targetChapter = chapterEntries[targetIndex];
      _logReaderEvent(
        'Reader adjacent chapter navigation requested',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'offset': offset,
          'fromChapterIndex': currentChapterIndex,
          'targetChapterIndex': targetIndex,
          'targetEpId': targetChapter.key,
          'targetChapterTitle': targetChapter.value,
        }),
      );

      if (!mounted) {
        return;
      }
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReaderPage(
            title: widget.title,
            chapterTitle: targetChapter.value,
            comicId: widget.comicId,
            epId: targetChapter.key,
            chapterIndex: targetIndex,
            images: const [],
            comicTheme: widget.comicTheme,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
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
