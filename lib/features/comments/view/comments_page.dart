import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/comments/comments_loading_view.dart';
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
    with AutomaticKeepAliveClientMixin {
  late final CommentsPageController _controller;
  late final StreamSubscription<CommentsEffect> _effectSubscription;
  late final ScrollController _scrollController;
  late final bool _ownsScrollController;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Set<String> _animatedCommentKeys = <String>{};

  bool? _tabScrollAtTop;
  int _fullscreenRequestEpoch = 0;
  final List<Timer> _fullscreenSyncTimers = [];
  double? _lastInnerScrollPixels;
  double? _lastInnerScrollMin;
  double? _lastInnerScrollMax;
  double? _lastInnerViewportDimension;

  CommentsInteractionState get _interaction => _controller.state;
  List<ComicCommentData> get _comments => _interaction.comments;
  String? get _errorMessage => _interaction.loadError == null
      ? null
      : l10n(context).commentsLoadFailed('${_interaction.loadError}');
  bool get _initialLoading => _interaction.initialLoading;
  bool get _loadingMore => _interaction.loadingMore;
  bool get _hasMore => _interaction.hasMore;
  bool get _sendingComment => _interaction.sendingComment;
  bool get _supportCommentLike => _interaction.supportCommentLike;
  bool get _supportCommentReplies => _interaction.supportCommentReplies;
  int get _currentPage => _interaction.currentPage;
  ComicCommentData? get _replyToComment => _interaction.replyToComment;
  Set<String> get _likingCommentIds => _interaction.likingCommentIds;
  Set<String> get _expandedReplyIds => _interaction.expandedReplyIds;
  Set<String> get _loadingReplyIds => _interaction.loadingReplyIds;
  Map<String, List<ComicCommentData>> get _replyComments =>
      _interaction.replyComments;
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
      comicId: widget.comicId,
      subId: widget.subId,
      chapterId: widget.chapterId,
      sourceKey: widget.sourceKey,
      logSource: widget.isTabView ? 'comic_detail_comments' : 'comments',
      logContext: {'viewMode': widget.isTabView ? 'detail_tab' : 'page'},
    );
    _commentFocusNode.addListener(_handleCommentFocusChanged);
    _controller.addListener(_onControllerChanged);
    _effectSubscription = _controller.effects.listen(_onControllerEffect);
    _controller.initialize();
  }

  @override
  void dispose() {
    for (final t in _fullscreenSyncTimers) {
      t.cancel();
    }
    _fullscreenSyncTimers.clear();
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    unawaited(_effectSubscription.cancel());
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _commentFocusNode
      ..removeListener(_handleCommentFocusChanged)
      ..dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerEffect(CommentsEffect effect) {
    if (!mounted) return;
    if (effect.type == CommentsEffectType.initialLoadStarted) {
      _animatedCommentKeys.clear();
      return;
    }
    if (effect.type == CommentsEffectType.sendSucceeded) {
      _commentController.clear();
    }
    final strings = l10n(context);
    final (message, isError) = switch (effect.type) {
      CommentsEffectType.liked => (strings.commentsLiked, false),
      CommentsEffectType.unliked => (strings.commentsUnliked, false),
      CommentsEffectType.likeFailed => (
        strings.commentsLikeFailed('${effect.error}'),
        true,
      ),
      CommentsEffectType.loginRequired => (
        strings.commentsLoginRequiredToSend,
        true,
      ),
      CommentsEffectType.sendUnsupported => (
        strings.commentsSourceNotSupported,
        true,
      ),
      CommentsEffectType.sendSucceeded => (strings.commentsSendSuccess, false),
      CommentsEffectType.sendFailed => (
        strings.commentsSendFailed('${effect.error}'),
        true,
      ),
      CommentsEffectType.initialLoadStarted => throw StateError(
        'Handled above',
      ),
    };
    unawaited(showHazukiPrompt(context, message, isError: isError));
  }

  void _handleCommentFocusChanged() {
    if (!mounted) {
      return;
    }
    _logCommentsStateSnapshot(
      'Comment input focus changed',
      extra: {'hasFocus': _commentFocusNode.hasFocus},
    );
    if (!_commentFocusNode.hasFocus) _controller.clearReplyTarget();
    setState(() {});
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
        'keyboardHeight': mediaQuery?.viewInsets.bottom.round(),
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
      final pillMarginBottom = isFocused ? 2.0 : 4.0;
      final pillApproxHeight = _replyToComment == null ? 72.0 : 126.0;
      return Stack(
        children: [
          _buildCommentsBodyList(
            extraBottomPadding: pillApproxHeight + pillMarginBottom,
            reserveKeyboardInset: true,
          ),
          _KeyboardAwareCommentsComposer(
            isFocused: isFocused,
            useKeyboardInset: true,
            bottomMargin: pillMarginBottom,
            child: _buildBottomComposer(),
          ),
        ],
      );
    }

    final isFocused = _commentFocusNode.hasFocus;
    final pillMarginBottom = !widget.showAppBar && isFocused ? 2.0 : 6.0;
    final pillApproxHeight = _replyToComment == null ? 72.0 : 126.0;
    final listExtraBottom = !widget.showAppBar
        ? pillApproxHeight + pillMarginBottom
        : 80.0;
    final body = Stack(
      children: [
        _KeyboardAwareCommentsBody(
          useKeyboardInset: false,
          child: _buildCommentsBodyList(extraBottomPadding: listExtraBottom),
        ),
        _KeyboardAwareCommentsComposer(
          isFocused: isFocused,
          useKeyboardInset: !widget.showAppBar,
          bottomMargin: pillMarginBottom,
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

  Future<void> _loadInitial() => _controller.loadInitial();

  Future<void> _loadMore() => _controller.loadMore();

  void _setReplyTarget(ComicCommentData comment) {
    if (comment.id == null) return;
    _controller.setReplyTarget(comment);
    _scheduleFullscreenSyncAttempts();
    _commentFocusNode.requestFocus();
  }

  void _clearReplyTarget() => _controller.clearReplyTarget();

  Future<void> _submitComment() async {
    final text = _commentController.text;
    if (_controller.canSubmitComment(text)) {
      FocusScope.of(context).unfocus();
    }
    await _controller.submitComment(text);
  }

  Widget _buildCommentTile(ComicCommentData comment, int index) {
    return _CommentsCommentTile(
      comment: comment,
      index: index,
      collapsedByFilter: _controller.isCollapsedComment(comment.content),
      animatedCommentKeys: _animatedCommentKeys,
      supportLike: _supportCommentLike,
      supportReply: _controller.supportCommentSend,
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
      onLike: (comment) => unawaited(_controller.toggleCommentLike(comment)),
      onToggleReplies: (comment) =>
          unawaited(_controller.toggleReplies(comment)),
      onLoadMoreReplies: (commentId) =>
          unawaited(_controller.loadMoreReplies(commentId)),
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

  Widget _buildCommentsBodyList({
    double extraBottomPadding = 0,
    bool reserveKeyboardInset = false,
  }) {
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
      reserveKeyboardInset: reserveKeyboardInset,
      onRetry: () => unawaited(_loadInitial()),
      onScrollNotification: _onScrollNotification,
      commentBuilder: _buildCommentTile,
    );
  }
}
