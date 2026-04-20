part of '../comments_page.dart';

extension _CommentsActionsExtension on _CommentsPageState {
  void _handleCommentInputTap() {
    _scheduleFullscreenSyncAttempts();
  }

  void _scheduleFullscreenSyncAttempts() {
    if (!widget.isTabView) {
      return;
    }
    final requestEpoch = ++_fullscreenRequestEpoch;

    void runIfStillNeeded() {
      if (!mounted ||
          !_commentFocusNode.hasFocus ||
          requestEpoch != _fullscreenRequestEpoch) {
        return;
      }
      unawaited(_requestTabFullscreenIfNeeded());
    }

    runIfStillNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runIfStillNeeded();
    });
    for (final delay in const [
      Duration(milliseconds: 120),
      Duration(milliseconds: 260),
      Duration(milliseconds: 420),
    ]) {
      Future<void>.delayed(delay, runIfStillNeeded);
    }
  }

  Future<void> _requestTabFullscreenIfNeeded() async {
    if (!widget.isTabView) {
      return;
    }
    final callback = widget.onRequestTabFullscreen;
    if (callback == null) {
      return;
    }
    await callback();
  }

  void _onScrollNotification(ScrollNotification notification) {
    _logTabTopState(notification.metrics);
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent > 0 &&
          metrics.pixels >= metrics.maxScrollExtent - 220) {
        unawaited(_loadMore());
      }
    }
  }

  Future<ComicCommentsPageResult> _loadCommentsPage(int page) {
    return HazukiSourceService.instance
        .loadCommentsPage(
          comicId: widget.comicId,
          subId: widget.subId,
          page: page,
          pageSize: _CommentsPageState._pageSize,
        )
        .timeout(_CommentsPageState._commentsLoadTimeout);
  }

  List<ComicCommentData> _mergeComments(
    List<ComicCommentData> existing,
    List<ComicCommentData> incoming,
  ) {
    final merged = <String, ComicCommentData>{};
    for (final comment in existing) {
      final key = '${comment.userName}|${comment.time}|${comment.content}';
      merged[key] = comment;
    }
    for (final comment in incoming) {
      final key = '${comment.userName}|${comment.time}|${comment.content}';
      merged[key] = comment;
    }
    return merged.values.toList();
  }

  bool _computeHasMore({
    required int page,
    required int fetchedCount,
    int? maxPage,
  }) {
    if (maxPage != null) {
      return page < maxPage;
    }
    return fetchedCount >= _CommentsPageState._pageSize;
  }

  Future<void> _loadInitial() async {
    final startedAt = DateTime.now();
    _logCommentsEvent('Comments load started', content: {'page': 1});
    try {
      final pageResult = await _loadCommentsPage(1);
      if (!mounted) {
        return;
      }
      _updateCommentsState(() {
        _comments = pageResult.comments;
        _errorMessage = null;
        _currentPage = 1;
        _maxPage = pageResult.maxPage;
        _hasMore = _computeHasMore(
          page: 1,
          fetchedCount: pageResult.comments.length,
          maxPage: pageResult.maxPage,
        );
      });
      _logCommentsEvent(
        'Comments load succeeded',
        content: {
          'page': 1,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'fetchedCount': pageResult.comments.length,
          'maxPage': pageResult.maxPage,
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _updateCommentsState(() {
        _errorMessage = l10n(context).commentsLoadFailed('$e');
      });
      _logCommentsEvent(
        'Comments load failed',
        level: 'error',
        content: {
          'page': 1,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'error': e.toString(),
        },
      );
    } finally {
      if (mounted) {
        _updateCommentsState(() {
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _initialLoading || _loadingMore || !_hasMore) {
      return;
    }

    final nextPage = _currentPage + 1;
    final startedAt = DateTime.now();
    _logCommentsEvent(
      'Comments load more started',
      content: {'page': nextPage},
    );

    if (_maxPage != null && _currentPage >= _maxPage!) {
      _updateCommentsState(() {
        _hasMore = false;
      });
      return;
    }

    _updateCommentsState(() {
      _loadingMore = true;
    });

    try {
      final pageResult = await _loadCommentsPage(nextPage);
      if (!mounted) {
        return;
      }

      final merged = _mergeComments(_comments, pageResult.comments);
      final hasMore = _computeHasMore(
        page: nextPage,
        fetchedCount: pageResult.comments.length,
        maxPage: pageResult.maxPage ?? _maxPage,
      );
      final appendedCount = merged.length - _comments.length;

      _updateCommentsState(() {
        _comments = merged;
        _currentPage = nextPage;
        _maxPage = pageResult.maxPage ?? _maxPage;
        _hasMore = hasMore && appendedCount > 0;
        _loadingMore = false;
      });
      _logCommentsEvent(
        'Comments load more succeeded',
        content: {
          'page': nextPage,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'fetchedCount': pageResult.comments.length,
          'appendedCount': appendedCount,
          'maxPage': pageResult.maxPage ?? _maxPage,
        },
      );
    } catch (_) {
      if (mounted) {
        _updateCommentsState(() {
          _loadingMore = false;
        });
      }
      _logCommentsEvent(
        'Comments load more failed',
        level: 'error',
        content: {
          'page': nextPage,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
    }
  }

  void _setReplyTarget(ComicCommentData comment) {
    if (comment.id == null) {
      return;
    }
    _updateCommentsState(() {
      _replyToComment = comment;
    });
  }

  void _clearReplyTarget() {
    if (_replyToComment == null) {
      return;
    }
    _updateCommentsState(() {
      _replyToComment = null;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) {
      return;
    }

    if (!HazukiSourceService.instance.isLogged) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsLoginRequiredToSend,
          isError: true,
        ),
      );
      return;
    }

    if (!HazukiSourceService.instance.supportCommentSend) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsSourceNotSupported,
          isError: true,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    _updateCommentsState(() {
      _sendingComment = true;
    });

    try {
      await HazukiSourceService.instance.sendComment(
        comicId: widget.comicId,
        subId: widget.subId,
        content: text,
        replyTo: _replyToComment?.id,
      );
      if (!mounted) {
        return;
      }
      _commentController.clear();
      _updateCommentsState(() {
        _replyToComment = null;
      });
      unawaited(showHazukiPrompt(context, l10n(context).commentsSendSuccess));
      await _loadInitial();
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsSendFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        _updateCommentsState(() {
          _sendingComment = false;
        });
      }
    }
  }
}
