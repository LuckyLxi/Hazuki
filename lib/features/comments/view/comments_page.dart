import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'comments_widgets.dart';

class _CommentsTabClampingScrollPhysics extends ClampingScrollPhysics {
  const _CommentsTabClampingScrollPhysics({super.parent});

  @override
  _CommentsTabClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CommentsTabClampingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _SuppressShowOnScreen extends SingleChildRenderObjectWidget {
  const _SuppressShowOnScreen({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSuppressShowOnScreen();
  }
}

class _RenderSuppressShowOnScreen extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // The composer is already pinned on screen, so suppress framework-driven
    // focus reveal scrolling and let the detail-page fullscreen logic decide
    // whether any outer scroll is needed.
  }
}

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.comicId,
    this.subId,
    this.isTabView = false,
    this.isActiveInTabView = true,
    this.onRequestTabFullscreen,
    this.debugOuterScrollStateBuilder,
  });

  final String comicId;
  final String? subId;
  final bool isTabView;
  final bool isActiveInTabView;
  final Future<void> Function()? onRequestTabFullscreen;
  final Map<String, Object?> Function()? debugOuterScrollStateBuilder;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const _commentsLoadTimeout = Duration(seconds: 20);
  static const _pageSize = 16;

  late final CommentsPageController _controller;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Set<String> _animatedCommentKeys = <String>{};

  List<ComicCommentData> _comments = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sendingComment = false;
  bool _hideFilterLoadMoreQueued = false;
  int _currentPage = 1;
  int? _maxPage;
  ComicCommentData? _replyToComment;
  bool? _tabScrollAtTop;
  int _fullscreenRequestEpoch = 0;
  double _keyboardHeight = 0;
  double? _lastInnerScrollPixels;
  double? _lastInnerScrollMin;
  double? _lastInnerScrollMax;
  double? _lastInnerViewportDimension;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = CommentsPageController();
    WidgetsBinding.instance.addObserver(this);
    _commentFocusNode.addListener(_handleCommentFocusChanged);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _commentFocusNode
      ..removeListener(_handleCommentFocusChanged)
      ..dispose();
    _commentController.dispose();
    super.dispose();
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
    setState(() {});
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
        if (content != null) ...content,
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
        if (outerState != null) ...outerState,
        if (extra != null) ...extra,
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

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).commentsTitle),
      ),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _buildCommentsBodyList(extraBottomPadding: 80),
          Positioned(
            left: 16,
            right: 16,
            bottom: safeBottom + 6,
            child: _buildBottomComposer(),
          ),
        ],
      ),
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
    if (!widget.isTabView) {
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
    if (_tabScrollAtTop == false) {
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
    return fetchedCount >= _pageSize;
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

    if (!_controller.isLogged) {
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).commentsLoginRequiredToSend,
          isError: true,
        ),
      );
      return;
    }

    if (!_controller.supportCommentSend) {
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
    final filter = CommentFilterService.instance;
    if (filter.mode == CommentFilterMode.collapse &&
        filter.isFiltered(comment.content)) {
      final key =
          comment.id ??
          '${comment.userName}|${comment.time}|${comment.content}';
      return _FilteredCommentTile(
        key: ValueKey('filtered_$key'),
        expandedBuilder: (context, onCollapse) => _buildCommentTileContent(
          comment,
          index,
          animateIntro: false,
          filteredCollapseButton: _buildFilteredCommentCollapseButton(
            onCollapse,
          ),
        ),
      );
    }
    return _buildCommentTileContent(comment, index);
  }

  Widget _buildCommentTileContent(
    ComicCommentData comment,
    int index, {
    bool animateIntro = true,
    Widget? filteredCollapseButton,
  }) {
    final theme = Theme.of(context);
    final hasReply = (comment.replyCount ?? 0) > 0;
    final bodyStyle = theme.textTheme.bodyMedium;
    final metaStyle = theme.textTheme.bodySmall;
    final displayName = comment.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : comment.userName;
    final animationKey =
        comment.id ?? '${comment.userName}|${comment.time}|${comment.content}';
    final shouldAnimate = _animatedCommentKeys.add(animationKey);

    final item = InkWell(
      onTap: comment.id == null ? null : () => _setReplyTarget(comment),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: HazukiCachedCircleAvatar(
                url: comment.avatar,
                fallbackIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (comment.id != null)
                        IconButton(
                          tooltip: l10n(context).commentsReplyTooltip,
                          onPressed: () => _setReplyTarget(comment),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.reply_outlined, size: 20),
                        ),
                      ?filteredCollapseButton,
                    ],
                  ),
                  if (comment.time.isNotEmpty || hasReply) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (comment.time.isNotEmpty)
                          Text(comment.time, style: metaStyle),
                        if (hasReply)
                          Text(
                            l10n(
                              context,
                            ).commentsReplyCount('${comment.replyCount}'),
                            style: metaStyle,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  CommentsSelectableContent(
                    content: comment.content,
                    style: bodyStyle,
                    expansionKey: animationKey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!animateIntro || !shouldAnimate) {
      return item;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 10)) * 60),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * value,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: item,
    );
  }

  Widget _buildFilteredCommentCollapseButton(VoidCallback onCollapse) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: l10n(context).comicDetailCollapse,
      onPressed: onCollapse,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.keyboard_arrow_up,
        size: 22,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildReplyBanner() {
    final replyTo = _replyToComment;
    if (replyTo == null) {
      return const SizedBox.shrink();
    }

    final name = replyTo.userName.isEmpty
        ? l10n(context).commentsAnonymousUser
        : replyTo.userName;
    final preview = commentPreviewText(replyTo.content);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n(context).commentsReplyToUser(name),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n(context).commentsCancelReplyTooltip,
            onPressed: _clearReplyTarget,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomComposer({double bottomInset = 0}) {
    final hint = _replyToComment == null
        ? l10n(context).commentsComposerHint
        : l10n(context).commentsReplyComposerHint(
            _replyToComment!.userName.isEmpty
                ? l10n(context).commentsAnonymousUser
                : _replyToComment!.userName,
          );
    final isFocused = _commentFocusNode.hasFocus;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReplyBanner(),
            LayoutBuilder(
              builder: (context, constraints) {
                final expandedWidth = constraints.maxWidth;
                final collapsedWidth = math.min(
                  expandedWidth,
                  math.max(272.0, expandedWidth * 0.82),
                );
                final composerWidth = isFocused
                    ? expandedWidth
                    : collapsedWidth;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: composerWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withAlpha(176),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withAlpha(150),
                          ),
                        ),
                        child: _SuppressShowOnScreen(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            onTap: _handleCommentInputTap,
                            onTapOutside: (_) => _commentFocusNode.unfocus(),
                            scrollPadding: EdgeInsets.zero,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => unawaited(_submitComment()),
                            decoration: InputDecoration(
                              hintText: hint,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                left: 16,
                                top: 10,
                                bottom: 10,
                                right: 4,
                              ),
                              isDense: true,
                              suffixIcon: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: FilledButton(
                                  onPressed: _sendingComment
                                      ? null
                                      : _submitComment,
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 0,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    _sendingComment
                                        ? l10n(context).commentsSending
                                        : l10n(context).commentsSend,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiddenCountBanner(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        l10n(context).commentFilterHiddenBanner('$count'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _maybeLoadMoreForHiddenFilter(int visibleCount, int hiddenCount) {
    if (hiddenCount <= 0 ||
        visibleCount >= _pageSize ||
        _initialLoading ||
        _loadingMore ||
        !_hasMore ||
        _hideFilterLoadMoreQueued) {
      return;
    }
    _hideFilterLoadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hideFilterLoadMoreQueued = false;
      if (!mounted || _initialLoading || _loadingMore || !_hasMore) {
        return;
      }
      final filter = CommentFilterService.instance;
      if (filter.mode != CommentFilterMode.hide) {
        return;
      }
      final currentVisibleCount = _comments
          .where((c) => !filter.isFiltered(c.content))
          .length;
      if (currentVisibleCount < _pageSize) {
        unawaited(_loadMore());
      }
    });
  }

  Widget _buildCommentsBodyList({double extraBottomPadding = 0}) {
    final loadMoreFooter = _loadingMore
        ? const HazukiLoadMoreFooter()
        : const SizedBox(height: 4);
    final listBottomPadding = EdgeInsets.only(bottom: 10 + extraBottomPadding);
    final filter = CommentFilterService.instance;
    final visibleComments = filter.mode == CommentFilterMode.hide
        ? _comments.where((c) => !filter.isFiltered(c.content)).toList()
        : _comments;
    final hiddenCount = _comments.length - visibleComments.length;
    if (filter.mode == CommentFilterMode.hide) {
      _maybeLoadMoreForHiddenFilter(visibleComments.length, hiddenCount);
    }

    if (widget.isTabView) {
      final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
        context,
      );
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScrollNotification(notification);
          return false;
        },
        child: CustomScrollView(
          key: const PageStorageKey<String>('comic-detail-comments-tab'),
          physics: const _CommentsTabClampingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(handle: overlapHandle),
            if (hiddenCount > 0)
              SliverToBoxAdapter(child: _buildHiddenCountBanner(hiddenCount)),
            if (_comments.isNotEmpty)
              SliverPadding(
                padding: listBottomPadding,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == visibleComments.length) {
                      return loadMoreFooter;
                    }
                    final isLastComment = index == visibleComments.length - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCommentTile(visibleComments[index], index),
                        if (!isLastComment) const Divider(height: 1),
                      ],
                    );
                  }, childCount: visibleComments.length + 1),
                ),
              )
            else ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        ...<Widget?>[currentChild].whereType<Widget>(),
                      ],
                    );
                  },
                  child: _buildCommentsContent(),
                ),
              ),
              SliverToBoxAdapter(child: loadMoreFooter),
            ],
          ],
        ),
      );
    }

    final content = _buildCommentsContent();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return false;
      },
      child: _comments.isNotEmpty
          ? CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (hiddenCount > 0)
                  SliverToBoxAdapter(
                    child: _buildHiddenCountBanner(hiddenCount),
                  ),
                SliverPadding(
                  padding: listBottomPadding,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == visibleComments.length) {
                        return loadMoreFooter;
                      }
                      final isLastComment = index == visibleComments.length - 1;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCommentTile(visibleComments[index], index),
                          if (!isLastComment) const Divider(height: 1),
                        ],
                      );
                    }, childCount: visibleComments.length + 1),
                  ),
                ),
              ],
            )
          : ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: listBottomPadding,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        ...<Widget?>[currentChild].whereType<Widget>(),
                      ],
                    );
                  },
                  child: content,
                ),
                loadMoreFooter,
              ],
            ),
    );
  }

  Widget _buildCommentsContent() {
    if (_initialLoading) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.only(top: 100),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HazukiSandyLoadingIndicator(size: 144),
            const SizedBox(height: 10),
            Text(l10n(context).commonLoading),
          ],
        ),
      );
    }

    if (_errorMessage != null && _comments.isEmpty) {
      return Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            ),
            FilledButton(
              onPressed: _loadInitial,
              child: Text(l10n(context).commonRetry),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.only(top: 80),
        alignment: Alignment.topCenter,
        child: Text(l10n(context).commentsEmpty),
      );
    }

    return ListView.separated(
      key: const ValueKey('list'),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          _buildCommentTile(_comments[index], index),
    );
  }
}

class _FilteredCommentTile extends StatefulWidget {
  const _FilteredCommentTile({super.key, required this.expandedBuilder});

  final Widget Function(BuildContext context, VoidCallback onCollapse)
  expandedBuilder;

  @override
  State<_FilteredCommentTile> createState() => _FilteredCommentTileState();
}

class _FilteredCommentTileState extends State<_FilteredCommentTile> {
  static const _animationDuration = Duration(milliseconds: 260);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AnimatedSize(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: _animationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          );
        },
        child: _expanded
            ? KeyedSubtree(
                key: const ValueKey<String>('filtered-comment-expanded'),
                child: widget.expandedBuilder(
                  context,
                  () => setState(() => _expanded = false),
                ),
              )
            : _FilteredCommentCollapsedTile(
                key: const ValueKey<String>('filtered-comment-collapsed'),
                label: strings.commentFilteredCollapsedLabel,
                expandLabel: strings.commentFilteredExpandLabel,
                onTap: () => setState(() => _expanded = true),
              ),
      ),
    );
  }
}

class _FilteredCommentCollapsedTile extends StatelessWidget {
  const _FilteredCommentCollapsedTile({
    super.key,
    required this.label,
    required this.expandLabel,
    required this.onTap,
  });

  final String label;
  final String expandLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        expandLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }
}
