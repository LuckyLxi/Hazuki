import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../l10n/l10n.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';

part 'comments/comments_actions.dart';
part 'comments/comments_content_support.dart';
part 'comments/comments_widgets.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage({
    super.key,
    required this.comicId,
    this.subId,
    this.isTabView = false,
    this.isActiveInTabView = true,
    this.onRequestTabFullscreen,
  });

  final String comicId;
  final String? subId;
  final bool isTabView;
  final bool isActiveInTabView;
  final Future<void> Function()? onRequestTabFullscreen;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const _commentsLoadTimeout = Duration(seconds: 20);
  static const _pageSize = 16;
  static final RegExp _commentInlineImagePattern = RegExp(
    r'<img\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _commentBreakTagPattern = RegExp(
    r'<br\s*/?>',
    caseSensitive: false,
  );
  static final RegExp _commentBlockClosingTagPattern = RegExp(
    r'</(?:p|div|li)\s*>',
    caseSensitive: false,
  );
  static final RegExp _commentHtmlTagPattern = RegExp(r'<[^>]+>');
  static final RegExp _commentHtmlEntityPattern = RegExp(
    r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);',
  );

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
  int _currentPage = 1;
  int? _maxPage;
  ComicCommentData? _replyToComment;
  bool? _tabScrollAtTop;
  int _fullscreenRequestEpoch = 0;
  // 真实键盘高度（从 PlatformDispatcher 直接读取，绕过 NestedScrollView 对 viewInsets 的覆盖）
  double _keyboardHeight = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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
    // 直接从 PlatformDispatcher 读取键盘高度，不受 NestedScrollView 重写 viewInsets 的影响
    final rawBottom = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    // viewInsets.bottom 是物理像素，需要除以 devicePixelRatio 转换为逻辑像素
    final pixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final newKeyboardHeight = rawBottom / pixelRatio;
    if (newKeyboardHeight != _keyboardHeight) {
      setState(() {
        _keyboardHeight = newKeyboardHeight;
      });
    }
    if (_commentFocusNode.hasFocus) {
      _scheduleFullscreenSyncAttempts();
    }
  }

  void _handleCommentFocusChanged() {
    if (!mounted) {
      return;
    }
    if (_commentFocusNode.hasFocus) {
      _scheduleFullscreenSyncAttempts();
    }
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
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.isTabView && !widget.isActiveInTabView) {
      return const SizedBox.expand();
    }

    if (widget.isTabView) {
      final isFocused = _commentFocusNode.hasFocus;
      // 使用从 didChangeMetrics 中缓存的真实键盘高度，避免 NestedScrollView 覆盖 viewInsets 导致值为 0
      final bottomInset = _keyboardHeight;
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      final pillHoriz = isFocused ? 10.0 : 16.0;
      final pillMarginBottom = isFocused ? 2.0 : 4.0;
      final pillApproxHeight = _replyToComment == null ? 72.0 : 126.0;
      final listExtraBottom =
          pillApproxHeight + pillMarginBottom + safeBottom + bottomInset;
      return Stack(
        children: [
          _buildCommentsBodyList(extraBottomPadding: listExtraBottom),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
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
}
