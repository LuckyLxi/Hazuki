import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/shared/search_box_outline.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'comments_widgets.dart';

part 'comments_body_list.dart';
part 'comments_comment_tile.dart';
part 'comments_composer.dart';
part 'comments_scroll_support.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.sourceService,
    required this.filterService,
    required this.comicId,
    this.subId,
    this.chapterId,
    this.sourceKey = '',
    this.isTabView = false,
    this.isActiveInTabView = true,
    this.showAppBar = true,
    this.scrollController,
    this.onRequestTabFullscreen,
    this.debugOuterScrollStateBuilder,
    this.interactionState,
  });

  final SourceCommentsGateway sourceService;
  final CommentFilterService filterService;
  final String comicId;
  final String? subId;
  final String? chapterId;
  final String sourceKey;
  final bool isTabView;
  final bool isActiveInTabView;
  final bool showAppBar;
  final ScrollController? scrollController;
  final Future<void> Function()? onRequestTabFullscreen;
  final Map<String, Object?> Function()? debugOuterScrollStateBuilder;
  final CommentsInteractionState? interactionState;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const _commentsLoadTimeout = Duration(seconds: 20);
  static const _pageSize = 16;

  late final CommentsPageController _controller;
  late final ScrollController _scrollController;
  late final bool _ownsScrollController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Set<String> _animatedCommentKeys = <String>{};

  bool? _tabScrollAtTop;
  int _fullscreenRequestEpoch = 0;
  final List<Timer> _fullscreenSyncTimers = [];
  double _keyboardHeight = 0;
  double? _lastInnerScrollPixels;
  double? _lastInnerScrollMin;
  double? _lastInnerScrollMax;
  double? _lastInnerViewportDimension;

  CommentsInteractionState get _interaction => _controller.state;
  List<ComicCommentData> get _comments => _interaction.comments;
  set _comments(List<ComicCommentData> value) => _interaction.comments = value;
  String? get _errorMessage => _interaction.errorMessage;
  set _errorMessage(String? value) => _interaction.errorMessage = value;
  bool get _initialLoading => _interaction.initialLoading;
  set _initialLoading(bool value) => _interaction.initialLoading = value;
  bool get _loadingMore => _interaction.loadingMore;
  set _loadingMore(bool value) => _interaction.loadingMore = value;
  int get _loadEpoch => _interaction.loadEpoch;
  set _loadEpoch(int value) => _interaction.loadEpoch = value;
  bool get _hasMore => _interaction.hasMore;
  set _hasMore(bool value) => _interaction.hasMore = value;
  bool get _sendingComment => _interaction.sendingComment;
  set _sendingComment(bool value) => _interaction.sendingComment = value;
  bool get _hideFilterLoadMoreQueued => _interaction.hideFilterLoadMoreQueued;
  set _hideFilterLoadMoreQueued(bool value) =>
      _interaction.hideFilterLoadMoreQueued = value;
  bool get _supportCommentLike => _interaction.supportCommentLike;
  set _supportCommentLike(bool value) =>
      _interaction.supportCommentLike = value;
  bool get _supportCommentReplies => _interaction.supportCommentReplies;
  set _supportCommentReplies(bool value) =>
      _interaction.supportCommentReplies = value;
  int get _currentPage => _interaction.currentPage;
  set _currentPage(int value) => _interaction.currentPage = value;
  int? get _maxPage => _interaction.maxPage;
  set _maxPage(int? value) => _interaction.maxPage = value;
  ComicCommentData? get _replyToComment => _interaction.replyToComment;
  set _replyToComment(ComicCommentData? value) =>
      _interaction.replyToComment = value;
  Set<String> get _likingCommentIds => _interaction.likingCommentIds;
  Set<String> get _expandedReplyIds => _interaction.expandedReplyIds;
  Set<String> get _loadingReplyIds => _interaction.loadingReplyIds;
  Map<String, List<ComicCommentData>> get _replyComments =>
      _interaction.replyComments;
  Map<String, int> get _replyPages => _interaction.replyPages;
  Map<String, int?> get _replyMaxPages => _interaction.replyMaxPages;
  Map<String, bool> get _replyHasMore => _interaction.replyHasMore;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
    _controller = CommentsPageController(
      sourceService: widget.sourceService,
      filterService: widget.filterService,
      state: widget.interactionState,
    );
    WidgetsBinding.instance.addObserver(this);
    _commentFocusNode.addListener(_handleCommentFocusChanged);
    _controller.addFilterListener(_onFilterChanged);
    _refreshCommentCapabilities();
    if (!_interaction.initialLoadSucceeded) {
      unawaited(_loadInitial());
    }
  }

  void _refreshCommentCapabilities() {
    _supportCommentLike = _controller.supportCommentLike(widget.sourceKey);
    _supportCommentReplies = _controller.supportCommentReplies(
      widget.sourceKey,
    );
  }

  @override
  void dispose() {
    for (final t in _fullscreenSyncTimers) {
      t.cancel();
    }
    _fullscreenSyncTimers.clear();
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    _controller.removeFilterListener(_onFilterChanged);
    _commentFocusNode
      ..removeListener(_handleCommentFocusChanged)
      ..dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) {
      setState(() {});
      _maybeLoadMoreForHiddenFilter();
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted) {
      return;
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final rawBottom = view.viewInsets.bottom;
    final newKeyboardHeight = rawBottom / view.devicePixelRatio;
    if (newKeyboardHeight != _keyboardHeight) {
      setState(() {
        _keyboardHeight = newKeyboardHeight;
      });
      _logCommentsStateSnapshot(
        'Comments metrics changed',
        extra: {
          'rawBottomInset': rawBottom.round(),
          'newKeyboardHeight': newKeyboardHeight.round(),
        },
      );
    }
  }

  void _handleCommentFocusChanged() {
    if (!mounted) {
      return;
    }
    _logCommentsStateSnapshot(
      'Comment input focus changed',
      extra: {'hasFocus': _commentFocusNode.hasFocus},
    );
    setState(() {
      if (!_commentFocusNode.hasFocus) {
        _replyToComment = null;
      }
    });
  }

  void _updateCommentsState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  void _logCommentsEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    _controller.log(
      title,
      level: level,
      content: {
        'comicId': widget.comicId,
        'subId': widget.subId,
        'viewMode': widget.isTabView ? 'detail_tab' : 'page',
        'currentPage': _currentPage,
        'commentCount': _comments.length,
        'hasMore': _hasMore,
        ...?content,
      },
      source: widget.isTabView ? 'comic_detail_comments' : 'comments',
    );
  }

  void _logTabTopState(ScrollMetrics metrics) {
    if (!widget.isTabView || metrics.axis != Axis.vertical) {
      return;
    }
    _rememberInnerScrollMetrics(metrics);
    final atTop = metrics.pixels <= metrics.minScrollExtent + 0.5;
    if (_tabScrollAtTop == atTop) {
      return;
    }
    _tabScrollAtTop = atTop;
    _logCommentsEvent(
      atTop ? 'Comments tab reached top' : 'Comments tab left top',
      content: {
        'pixels': metrics.pixels.round(),
        'minScrollExtent': metrics.minScrollExtent.round(),
        'maxScrollExtent': metrics.maxScrollExtent.round(),
      },
    );
  }

  void _rememberInnerScrollMetrics(ScrollMetrics metrics) {
    _lastInnerScrollPixels = metrics.pixels;
    _lastInnerScrollMin = metrics.minScrollExtent;
    _lastInnerScrollMax = metrics.maxScrollExtent;
    _lastInnerViewportDimension = metrics.viewportDimension;
  }

  void _logCommentsStateSnapshot(String title, {Map<String, Object?>? extra}) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final outerState = widget.debugOuterScrollStateBuilder?.call();
    _logCommentsEvent(
      title,
      content: {
        'hasFocus': _commentFocusNode.hasFocus,
        'tabScrollAtTop': _tabScrollAtTop,
        'keyboardHeight': _keyboardHeight.round(),
        'liveViewInsetBottom': mediaQuery?.viewInsets.bottom.round(),
        'safeBottom': mediaQuery?.padding.bottom.round(),
        'innerPixels': _lastInnerScrollPixels?.round(),
        'innerMinScrollExtent': _lastInnerScrollMin?.round(),
        'innerMaxScrollExtent': _lastInnerScrollMax?.round(),
        'innerViewportDimension': _lastInnerViewportDimension?.round(),
        ...?outerState,
        ...?extra,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isTabView && !widget.isActiveInTabView) {
      return const SizedBox.expand();
    }

    if (widget.isTabView) {
      final isFocused = _commentFocusNode.hasFocus;
      final liveBottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final bottomInset = math.max(liveBottomInset, _keyboardHeight);
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      final pillHoriz = isFocused ? 10.0 : 16.0;
      final pillMarginBottom = isFocused ? 2.0 : 4.0;
      final pillApproxHeight = _replyToComment == null ? 72.0 : 126.0;
      final listExtraBottom =
          pillApproxHeight + pillMarginBottom + safeBottom + bottomInset;
      final composerPositionDuration = bottomInset > 0
          ? Duration.zero
          : const Duration(milliseconds: 220);
      return Stack(
        children: [
          _buildCommentsBodyList(extraBottomPadding: listExtraBottom),
          AnimatedPositioned(
            duration: composerPositionDuration,
            curve: Curves.easeOutCubic,
            left: pillHoriz,
            right: pillHoriz,
            bottom: safeBottom + pillMarginBottom + bottomInset,
            child: _buildBottomComposer(),
          ),
        ],
      );
    }

    final isFocused = _commentFocusNode.hasFocus;
    final liveBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomInset = !widget.showAppBar
        ? math.max(liveBottomInset, _keyboardHeight)
        : 0.0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final pillHoriz = !widget.showAppBar && isFocused ? 10.0 : 16.0;
    final pillMarginBottom = !widget.showAppBar && isFocused ? 2.0 : 6.0;
    final pillApproxHeight = _replyToComment == null ? 72.0 : 126.0;
    final listExtraBottom = !widget.showAppBar
        ? pillApproxHeight + pillMarginBottom + safeBottom + bottomInset
        : 80.0;
    final composerPositionDuration = bottomInset > 0
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final body = Stack(
      children: [
        _buildCommentsBodyList(extraBottomPadding: listExtraBottom),
        AnimatedPositioned(
          duration: composerPositionDuration,
          curve: Curves.easeOutCubic,
          left: pillHoriz,
          right: pillHoriz,
          bottom: safeBottom + pillMarginBottom + bottomInset,
          child: _buildBottomComposer(),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return body;
    }

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).commentsTitle),
      ),
      resizeToAvoidBottomInset: true,
      body: body,
    );
  }

  void _handleCommentInputTap() {
    _logCommentsStateSnapshot(
      'Comment input tapped',
      extra: {'hadFocusBeforeTap': _commentFocusNode.hasFocus},
    );
    _scheduleFullscreenSyncAttempts();
  }

  void _scheduleFullscreenSyncAttempts() {
    if (widget.onRequestTabFullscreen == null) {
      return;
    }
    final requestEpoch = ++_fullscreenRequestEpoch;

    void runIfStillNeeded() {
      if (!mounted) {
        return;
      }
      if (!_commentFocusNode.hasFocus ||
          requestEpoch != _fullscreenRequestEpoch) {
        _logCommentsStateSnapshot(
          'Comments fullscreen sync skipped before request',
          extra: {
            'requestEpoch': requestEpoch,
            'currentEpoch': _fullscreenRequestEpoch,
          },
        );
        return;
      }
      _logCommentsStateSnapshot(
        'Comments fullscreen sync requesting',
        extra: {'requestEpoch': requestEpoch},
      );
      unawaited(_requestTabFullscreenIfNeeded());
    }

    for (final t in _fullscreenSyncTimers) {
      t.cancel();
    }
    _fullscreenSyncTimers
      ..clear()
      ..addAll([
        Timer(const Duration(milliseconds: 120), runIfStillNeeded),
        Timer(const Duration(milliseconds: 260), runIfStillNeeded),
        Timer(const Duration(milliseconds: 420), runIfStillNeeded),
      ]);
    runIfStillNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runIfStillNeeded();
    });
  }

  Future<void> _requestTabFullscreenIfNeeded() async {
    if (widget.isTabView && _tabScrollAtTop == false) {
      _logCommentsStateSnapshot(
        'Comments fullscreen request skipped',
        extra: {'reason': 'inner_scroll_not_at_top'},
      );
      return;
    }
    final callback = widget.onRequestTabFullscreen;
    if (callback == null) {
      _logCommentsStateSnapshot(
        'Comments fullscreen request skipped',
        extra: {'reason': 'missing_callback'},
      );
      return;
    }
    _logCommentsStateSnapshot('Comments fullscreen request started');
    await callback();
    _logCommentsStateSnapshot('Comments fullscreen request finished');
  }

  void _onScrollNotification(ScrollNotification notification) {
    _rememberInnerScrollMetrics(notification.metrics);
    _logTabTopState(notification.metrics);
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _logCommentsStateSnapshot(
        notification is ScrollStartNotification
            ? 'Comments inner scroll started'
            : 'Comments inner scroll ended',
      );
    }
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent > 0 &&
          metrics.pixels >= metrics.maxScrollExtent - 220) {
        unawaited(_loadMore());
      }
    }
  }

  Future<ComicCommentsPageResult> _loadCommentsPage(int page) {
    return _controller.loadCommentsPage(
      comicId: widget.comicId,
      subId: widget.subId,
      chapterId: widget.chapterId,
      sourceKey: widget.sourceKey,
      page: page,
      pageSize: _pageSize,
      timeout: _commentsLoadTimeout,
    );
  }

  List<ComicCommentData> _mergeComments(
    List<ComicCommentData> existing,
    List<ComicCommentData> incoming,
  ) {
    final merged = <String, ComicCommentData>{};
    for (final comment in existing) {
      final key =
          comment.id ??
          '${comment.userName}|${comment.time}|${comment.content}';
      merged[key] = comment;
    }
    for (final comment in incoming) {
      final key =
          comment.id ??
          '${comment.userName}|${comment.time}|${comment.content}';
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
    return fetchedCount >= _pageSize;
  }

  Future<void> _loadInitial() async {
    final epoch = ++_loadEpoch;
    _updateCommentsState(() {
      _initialLoading = true;
      _loadingMore = false;
      _animatedCommentKeys.clear();
    });
    final startedAt = DateTime.now();
    _logCommentsEvent('Comments load started', content: {'page': 1});
    try {
      final pageResult = await _loadCommentsPage(1);
      if (!mounted || _loadEpoch != epoch) {
        return;
      }
      _updateCommentsState(() {
        _comments = pageResult.comments;
        _errorMessage = null;
        _interaction.initialLoadSucceeded = true;
        _refreshCommentCapabilities();
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
      if (!mounted || _loadEpoch != epoch) {
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
      if (mounted && _loadEpoch == epoch) {
        _updateCommentsState(() {
          _initialLoading = false;
        });
        _maybeLoadMoreForHiddenFilter();
      }
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _initialLoading || _loadingMore || !_hasMore) {
      return;
    }

    final epoch = _loadEpoch;
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
      if (!mounted || _loadEpoch != epoch) {
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
      _maybeLoadMoreForHiddenFilter();
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
    _scheduleFullscreenSyncAttempts();
    _commentFocusNode.requestFocus();
  }

  void _clearReplyTarget() {
    if (_replyToComment == null) {
      return;
    }
    _updateCommentsState(() {
      _replyToComment = null;
    });
  }

  ComicCommentData _withToggledLike(ComicCommentData comment, bool nextLiked) {
    final wasLiked = comment.isLiked ?? false;
    final currentScore = comment.score ?? 0;
    final nextScore = nextLiked == wasLiked
        ? currentScore
        : currentScore + (nextLiked ? 1 : -1);
    return comment.copyWith(isLiked: nextLiked, score: math.max(0, nextScore));
  }

  void _updateCommentById(
    String commentId,
    ComicCommentData Function(ComicCommentData comment) update,
  ) {
    _comments = _comments
        .map((comment) => comment.id == commentId ? update(comment) : comment)
        .toList();
    for (final entry in _replyComments.entries) {
      _replyComments[entry.key] = entry.value
          .map((comment) => comment.id == commentId ? update(comment) : comment)
          .toList();
    }
  }

  Future<void> _toggleCommentLike(ComicCommentData comment) async {
    final commentId = comment.id;
    if (commentId == null || _likingCommentIds.contains(commentId)) {
      return;
    }

    final nextLiked = !(comment.isLiked ?? false);
    _updateCommentsState(() {
      _likingCommentIds.add(commentId);
      _updateCommentById(
        commentId,
        (current) => _withToggledLike(current, nextLiked),
      );
    });

    try {
      await _controller.likeComment(
        comicId: widget.comicId,
        subId: widget.subId,
        sourceKey: widget.sourceKey,
        commentId: commentId,
        isLike: nextLiked,
      );
      if (mounted) {
        unawaited(
          showHazukiPrompt(
            context,
            nextLiked
                ? l10n(context).commentsLiked
                : l10n(context).commentsUnliked,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _updateCommentsState(() {
          _updateCommentById(commentId, (_) => comment);
        });
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).commentsLikeFailed('$e'),
            isError: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        _updateCommentsState(() {
          _likingCommentIds.remove(commentId);
        });
      }
    }
  }

  Future<void> _toggleReplies(ComicCommentData comment) async {
    final commentId = comment.id;
    if (commentId == null) {
      return;
    }
    if (_expandedReplyIds.contains(commentId)) {
      _updateCommentsState(() {
        _expandedReplyIds.remove(commentId);
      });
      return;
    }

    _updateCommentsState(() {
      _expandedReplyIds.add(commentId);
    });
    if (_replyComments[commentId]?.isNotEmpty == true) {
      return;
    }
    await _loadReplies(commentId, page: 1);
  }

  Future<void> _loadMoreReplies(String commentId) async {
    final nextPage = (_replyPages[commentId] ?? 0) + 1;
    await _loadReplies(commentId, page: nextPage);
  }

  Future<void> _loadReplies(String commentId, {required int page}) async {
    if (_loadingReplyIds.contains(commentId)) {
      return;
    }
    _updateCommentsState(() {
      _loadingReplyIds.add(commentId);
    });
    try {
      final pageResult = await _controller.loadCommentsPage(
        comicId: widget.comicId,
        subId: widget.subId,
        chapterId: widget.chapterId,
        sourceKey: widget.sourceKey,
        page: page,
        pageSize: _pageSize,
        timeout: _commentsLoadTimeout,
        replyTo: commentId,
      );
      if (!mounted) {
        return;
      }
      _updateCommentsState(() {
        final existing = page == 1
            ? const <ComicCommentData>[]
            : (_replyComments[commentId] ?? const <ComicCommentData>[]);
        final merged = _mergeComments(existing, pageResult.comments);
        _replyComments[commentId] = merged;
        _replyPages[commentId] = page;
        _replyMaxPages[commentId] = pageResult.maxPage;
        _replyHasMore[commentId] = _computeHasMore(
          page: page,
          fetchedCount: pageResult.comments.length,
          maxPage: pageResult.maxPage,
        );
      });
    } finally {
      if (mounted) {
        _updateCommentsState(() {
          _loadingReplyIds.remove(commentId);
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) {
      return;
    }

    if (!_controller.isLogged(widget.sourceKey)) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsLoginRequiredToSend,
          isError: true,
        ),
      );
      return;
    }

    if (!_controller.supportCommentSend(widget.sourceKey)) {
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
      await _controller.sendComment(
        comicId: widget.comicId,
        subId: widget.subId,
        chapterId: widget.chapterId,
        sourceKey: widget.sourceKey,
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

  Widget _buildCommentTile(ComicCommentData comment, int index) {
    return _CommentsCommentTile(
      comment: comment,
      index: index,
      collapsedByFilter: _controller.isCollapsedComment(comment.content),
      animatedCommentKeys: _animatedCommentKeys,
      supportLike: _supportCommentLike,
      supportReply: _controller.supportCommentSend(widget.sourceKey),
      supportReplies: _supportCommentReplies,
      isLiking: comment.id != null && _likingCommentIds.contains(comment.id),
      replies: comment.id == null
          ? const []
          : (_replyComments[comment.id] ?? const []),
      repliesExpanded:
          comment.id != null && _expandedReplyIds.contains(comment.id),
      repliesLoading:
          comment.id != null && _loadingReplyIds.contains(comment.id),
      repliesHasMore:
          comment.id != null && (_replyHasMore[comment.id] ?? false),
      onReply: _setReplyTarget,
      onLike: (comment) => unawaited(_toggleCommentLike(comment)),
      onToggleReplies: (comment) => unawaited(_toggleReplies(comment)),
      onLoadMoreReplies: (commentId) => unawaited(_loadMoreReplies(commentId)),
    );
  }

  Widget _buildBottomComposer({double bottomInset = 0}) {
    return _CommentsBottomComposer(
      replyToComment: _replyToComment,
      commentController: _commentController,
      commentFocusNode: _commentFocusNode,
      sendingComment: _sendingComment,
      bottomInset: bottomInset,
      onInputTap: _handleCommentInputTap,
      onSubmit: () => unawaited(_submitComment()),
      onClearReply: _clearReplyTarget,
    );
  }

  void _maybeLoadMoreForHiddenFilter() {
    if (!_controller.filterModeIsHide) return;
    if (_initialLoading ||
        _loadingMore ||
        !_hasMore ||
        _hideFilterLoadMoreQueued) {
      return;
    }
    final visibleCount = _controller.visibleComments(_comments).length;
    if (visibleCount >= _pageSize || visibleCount == _comments.length) return;

    _hideFilterLoadMoreQueued = true;
    unawaited(_doHiddenFilterLoadMore());
  }

  Future<void> _doHiddenFilterLoadMore() async {
    try {
      while (mounted && _hasMore && !_initialLoading) {
        final previousPage = _currentPage;
        await _loadMore();
        if (!mounted) return;
        if (_currentPage == previousPage) return;
        if (!_controller.filterModeIsHide) return;
        final visibleCount = _controller.visibleComments(_comments).length;
        if (visibleCount >= _pageSize) return;
      }
    } finally {
      _hideFilterLoadMoreQueued = false;
    }
  }

  Widget _buildCommentsBodyList({double extraBottomPadding = 0}) {
    final hideFilteredComments = _controller.filterModeIsHide;
    final visibleComments = hideFilteredComments
        ? _controller.visibleComments(_comments)
        : _comments;
    final hiddenCount = hideFilteredComments
        ? _comments.length - visibleComments.length
        : 0;

    return _CommentsBodyList(
      comments: _comments,
      visibleComments: visibleComments,
      hiddenCount: hiddenCount,
      initialLoading: _initialLoading,
      loadingMore: _loadingMore,
      errorMessage: _errorMessage,
      isTabView: widget.isTabView,
      scrollController: _scrollController,
      extraBottomPadding: extraBottomPadding,
      onRetry: () => unawaited(_loadInitial()),
      onScrollNotification: _onScrollNotification,
      commentBuilder: _buildCommentTile,
    );
  }
}
